#!/usr/bin/env python3
"""WILDBREAK headless test runner.

Roblox modules use `require(script.Parent...)` which the Luau CLI cannot resolve
(no `script` global). This runner mirrors src/ and tests/ into `.wbtest/`,
rewrites every `script.Parent...` require into a `.luaurc` alias require
(`@shared/...`), then executes the specs with the Luau CLI against a Roblox
stub (tests/harness).

Usage:
    python3 tools/run_tests.py            # run every tests/spec/*.luau
    python3 tools/run_tests.py config     # run specs whose name contains "config"
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, ".wbtest")
LUAU = os.environ.get("LUAU_BIN", os.path.expanduser("~/.local/bin/luau"))

ALIASES = {
    "shared": "./src/shared",
    "server": "./src/server",
    "client": "./src/client",
    "ui": "./src/ui",
    "wb": "./src",
    "tests": "./tests",
}

REQUIRE_RE = re.compile(r"require\(\s*script((?:\.[\w]+)*)\s*\)")


def resolve(chain: str, file_path: str) -> str:
    """Turn `script.Parent.Parent.Constants.Enums` into a path under ROOT."""
    parts = [p for p in chain.split(".") if p]
    cur = file_path
    for i, part in enumerate(parts):
        if part == "Parent":
            cur = os.path.dirname(cur)
        else:
            rest = os.path.join(*parts[i:])
            cur = os.path.join(cur, rest)
            break
    else:
        raise ValueError(f"require(script{chain}) has no target in {file_path}")
    for ext in (".luau", ".lua"):
        if os.path.isfile(cur + ext):
            return cur + ext
    if os.path.isdir(cur) and os.path.isfile(os.path.join(cur, "init.luau")):
        return os.path.join(cur, "init.luau")
    raise ValueError(f"cannot resolve require(script{chain}) from {file_path} -> {cur}")


def to_alias(abs_path: str) -> str:
    rel = os.path.relpath(abs_path, ROOT).replace(os.sep, "/")
    for name, target in ALIASES.items():
        prefix = target[2:] + "/"  # strip "./"
        if rel.startswith(prefix):
            rest = rel[len(prefix):]
            for ext in (".luau", ".lua"):
                if rest.endswith(ext):
                    rest = rest[: -len(ext)]
            if rest.endswith("/init"):
                rest = rest[: -len("/init")]
            return f"@{name}/{rest}"
    raise ValueError(f"no alias covers {rel}")


PRELUDE = (
    'local Vector3, Vector2, CFrame, Color3, UDim, UDim2, Rect, NumberRange = '
    'require("@tests/harness/RobloxStub").Inject()'
)


def rewrite_file(src_path: str, dst_path: str) -> None:
    with open(src_path, "r", encoding="utf-8") as fh:
        text = fh.read()

    def repl(match: re.Match) -> str:
        target = resolve(match.group(1), src_path)
        if not os.path.isfile(target):
            return match.group(0)
        return f'require("{to_alias(target)}")'

    text = REQUIRE_RE.sub(repl, text)
    lines = text.split("\n")
    insert_at = 1 if lines and lines[0].startswith("--!") else 0
    lines.insert(insert_at, PRELUDE)
    text = "\n".join(lines)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, "w", encoding="utf-8") as fh:
        fh.write(text)


def mirror() -> None:
    if os.path.isdir(WORK):
        shutil.rmtree(WORK)
    os.makedirs(WORK)
    for folder in ("src", "tests"):
        base = os.path.join(ROOT, folder)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in {".git", "__pycache__"}]
            for name in filenames:
                if not name.endswith((".luau", ".lua")):
                    continue
                src_path = os.path.join(dirpath, name)
                rel = os.path.relpath(src_path, ROOT)
                dst_path = os.path.join(WORK, rel)
                if folder == "src":
                    rewrite_file(src_path, dst_path)
                else:
                    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                    shutil.copy2(src_path, dst_path)
    with open(os.path.join(WORK, ".luaurc"), "w", encoding="utf-8") as fh:
        body = ", ".join(f'"{k}": "{v}"' for k, v in ALIASES.items())
        fh.write('{\n  "languageMode": "strict",\n  "aliases": {\n    ')
        fh.write(body.replace(", ", ",\n    "))
        fh.write("\n  }\n}\n")



# ---------------------------------------------------------------------------
# Static lint: registry methods take `self`, so they must be called with `:`.
# A dot-call silently shifts arguments and only fails at runtime, so it is
# caught statically here. Only receivers that are provably registry instances
# (created in-file with Registry.new, or required from a registry module) are
# checked, which keeps plain module functions such as TableUtil.Count valid.
# ---------------------------------------------------------------------------
REGISTRY_METHODS = ("GetOrError", "Get", "Has", "All", "List", "Ids", "Count", "Filter", "Validate", "Merge")
# Matches both `X.Get(...)` and `X.Get` used as a value: neither passes `self`.
# The trailing lookahead keeps longer names such as `X.ValidateAll` out of it.
DOT_CALL_RE = re.compile(r"(?<![:\w])([A-Za-z_][\w]*)\.(%s)(?![\w])" % "|".join(REGISTRY_METHODS))
NEW_RE = re.compile(r"local\s+([A-Za-z_]\w*)\s*=\s*Registry\.new\(")
REQUIRE_RE2 = re.compile(r"local\s+([A-Za-z_]\w*)\s*=\s*require\(([^)]*)\)")


def source_files() -> list[str]:
    out: list[str] = []
    for folder in ("src", "tests"):
        base = os.path.join(ROOT, folder)
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = [d for d in dirnames if d not in {".git", "__pycache__"}]
            for name in filenames:
                if name.endswith((".luau", ".lua")):
                    out.append(os.path.join(dirpath, name))
    return out


def registry_modules(files: list[str]) -> dict[str, str]:
    """module basename -> path, for modules that RETURN the registry instance.

    Modules that merely wrap a registry in their own API (such as
    MovementConfig) are excluded: their helpers are plain functions and must
    be called with a dot.
    """
    out: dict[str, str] = {}
    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
        names = NEW_RE.findall(text)
        if not names:
            continue
        tail = [line.strip() for line in text.strip().split("\n") if line.strip()]
        returned = tail[-1] if tail else ""
        for name in names:
            if returned == f"return {name}":
                out[os.path.splitext(os.path.basename(path))[0]] = path
                break
    return out


def lint_dot_calls() -> list[str]:
    problems: list[str] = []
    files = source_files()
    reg_modules = registry_modules(files)
    for path in files:
        with open(path, "r", encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        text = "\n".join(lines)
        receivers = set(NEW_RE.findall(text))
        for name, target in REQUIRE_RE2.findall(text):
            target = target.strip().strip('"').strip("'")
            base = target.rsplit("/", 1)[-1].rstrip('"')
            if base in reg_modules:
                receivers.add(name)
        if not receivers:
            continue
        for lineno, line in enumerate(lines, start=1):
            stripped = line.strip()
            if stripped.startswith("--"):
                continue
            for match in DOT_CALL_RE.finditer(line):
                receiver, method = match.group(1), match.group(2)
                if receiver not in receivers:
                    continue
                problems.append(
                    "%s:%d: %s.%s(...) must be %s:%s(...) (registry methods take self)"
                    % (os.path.relpath(path, ROOT), lineno, receiver, method, receiver, method)
                )
    return problems


SYMBOL_RE = re.compile(r"\b(Enums|Limits)\.([A-Za-z_]\w*)\.([A-Za-z_]\w*)")


def generate_symbol_audit() -> str:
    """Collect every Enums.X.Y / Limits.X.Y reference so a spec can prove they exist."""
    enums: dict[str, set[str]] = {}
    limits: dict[str, set[str]] = {}
    for path in source_files():
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
        without_blocks = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.DOTALL)
        body = "\n".join(
            line for line in without_blocks.split("\n") if not line.lstrip().startswith("--")
        )
        for namespace, table_name, key in SYMBOL_RE.findall(body):
            target = enums if namespace == "Enums" else limits
            target.setdefault(table_name, set()).add(key)
    out = ["-- generated by tools/run_tests.py - do not edit", "return {"]
    for label, data in (("enums", enums), ("limits", limits)):
        out.append(f"  {label} = {{")
        for table_name in sorted(data):
            keys = ", ".join(f'"{key}"' for key in sorted(data[table_name]))
            out.append(f'    {table_name} = {{ {keys} }},')
        out.append("  },")
    out.append("}")
    os.makedirs(os.path.join(WORK, "tests"), exist_ok=True)
    path = os.path.join(WORK, "tests", "_symbols.luau")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out) + "\n")
    return path


def specs(filter_text: str | None) -> list[str]:
    folder = os.path.join(ROOT, "tests", "spec")
    if not os.path.isdir(folder):
        return []
    out = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".luau"):
            continue
        if filter_text and filter_text not in name:
            continue
        out.append(os.path.join(WORK, "tests", "spec", name))
    return out


def main() -> int:
    if not os.path.isfile(LUAU):
        print(f"luau CLI not found at {LUAU}; set LUAU_BIN", file=sys.stderr)
        return 2
    problems = lint_dot_calls()
    if problems:
        print("registry dot-call lint:")
        for problem in problems:
            print("  " + problem)
        return 1
    mirror()
    generate_symbol_audit()
    files = specs(sys.argv[1] if len(sys.argv) > 1 else None)
    if not files:
        print("no specs matched", file=sys.stderr)
        return 1
    runner = os.path.join(WORK, "tests", "_runner.luau")
    lines = [
        "-- generated by tools/run_tests.py",
        "local ok = true",
    ]
    for path in files:
        rel = os.path.relpath(path, WORK).replace(os.sep, "/")
        if rel.endswith(".luau"):
            rel = rel[: -len(".luau")]
        lines.append(f'local pass, err = pcall(require, "@{rel}")')
        lines.append("if not pass then ok = false; print('[FAIL] ' .. '%s' .. ': ' .. tostring(err)) end" % rel)
    lines.append("if ok then print('\\nALL SPECS PASSED') else print('\\nSPECS FAILED') end")
    lines.append("return ok")
    with open(runner, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    proc = subprocess.run([LUAU, runner], cwd=WORK, capture_output=True, text=True)
    sys.stdout.write(proc.stdout)
    sys.stderr.write(proc.stderr)
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
