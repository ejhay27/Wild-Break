#!/usr/bin/env bash
# Builds the Luau CLI toolchain (luau, luau-analyze, luau-compile) from source.
#
# Why: the sandbox has no network access to the Luau release assets, and no
# cmake, so the three CLIs are compiled directly with g++ from the release
# tarball.
#
# Output: tools/bin/ (git-ignored) and ~/.local/bin/ (where tools/run_tests.py
# looks by default, via the LUAU_BIN environment variable).
#
# Requirements: g++ (>= 10), gcc, make, tar, curl, python3.
# Runtime: about 4 minutes with -j on 8 cores.
#
# How sources are discovered: rather than hard-coding a file list (which rots
# every time Luau reorganises), the CMake project is parsed and the dependency
# graph is resolved. `target_sources()` blocks give each target's files and
# `target_link_libraries()` gives the edges; each binary is then linked from
# the transitive closure of its own target.
#
# Both the old quoted ("Ast/src/Lexer.cpp") and the current unquoted
# (    Ast/src/Lexer.cpp) source spellings are accepted.
set -euo pipefail

VERSION="${1:-0.744}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$(mktemp -d)"
OBJ="$BUILD/obj"
OUT="$ROOT/tools/bin"
INSTALL="${INSTALL_DIR:-$HOME/.local/bin}"

mkdir -p "$OBJ" "$OUT"
cd "$BUILD"

echo "==> fetching Luau $VERSION"
curl -sSL "https://codeload.github.com/Roblox/luau/tar.gz/refs/tags/$VERSION" -o luau.tar.gz
tar xzf luau.tar.gz
SRC="$BUILD/luau-$VERSION"
cd "$SRC"

echo "==> resolving the CMake target graph"
python3 - "$SRC" "$OBJ" "$BUILD" <<'PY'
import os, re, sys

root, objdir, build = sys.argv[1], sys.argv[2], sys.argv[3]

sources_txt = open(os.path.join(root, "Sources.cmake")).read()
cmakelists = open(os.path.join(root, "CMakeLists.txt")).read()

SRC_RE = r'([A-Za-z][A-Za-z0-9_/]*\.(?:cpp|c))'

# --- target_sources(<target> [PRIVATE|PUBLIC|INTERFACE] <files...>) ---------
target_sources = {}
for m in re.finditer(r'target_sources\(\s*([A-Za-z0-9_.]+)[^)]*\)', sources_txt, re.S):
    target, block = m.group(1), m.group(0)
    files = re.findall(r'"%s"' % SRC_RE, block)
    files += re.findall(r'^\s{4,}%s\)?\s*$' % SRC_RE, block, re.M)
    target_sources.setdefault(target, [])
    for f in files:
        if os.path.isfile(os.path.join(root, f)) and f not in target_sources[target]:
            target_sources[target].append(f)

# --- target_link_libraries(<target> ... <deps...>) --------------------------
target_links = {}
for m in re.finditer(r'target_link_libraries\(\s*([A-Za-z0-9_.]+)[^)]*\)', cmakelists, re.S):
    target, block = m.group(1), m.group(0)
    deps = re.findall(r'\b(Luau\.[A-Za-z0-9_.]+|isocline|osthreads)\b', block)
    target_links.setdefault(target, [])
    for d in deps:
        if d not in target_links[target]:
            target_links[target].append(d)

EXTRA_SOURCES = {
    # isocline is a vendored C library added with its own add_library() call,
    # so it never appears in a target_sources() block.
    "isocline": ["extern/isocline/src/isocline.c"],
}

def closure(target, seen=None):
    if seen is None:
        seen = set()
    if target in seen:
        return seen
    seen.add(target)
    for dep in target_links.get(target, []):
        closure(dep, seen)
    return seen

TARGETS = {
    "luau": "Luau.Repl.CLI",
    "luau-analyze": "Luau.Analyze.CLI",
    "luau-compile": "Luau.Compile.CLI",
}

all_files, jobs = {}, []
for name, target in TARGETS.items():
    targets = closure(target)
    files = []
    for t in sorted(targets):
        for f in target_sources.get(t, []) + EXTRA_SOURCES.get(t, []):
            if f not in files:
                files.append(f)
    if len(files) < 50:
        sys.exit("%s resolved to only %d sources - parse failure" % (name, len(files)))
    all_files[name] = files
    print("  %-12s <- %-18s %3d files" % (name, target, len(files)))

def object_path(src):
    return os.path.join(objdir, src.replace("/", "_").rsplit(".", 1)[0] + ".o")

# Compile every distinct source exactly once.
every = []
for files in all_files.values():
    for f in files:
        if f not in every:
            every.append(f)

if len(every) < 50:
    sys.exit("only found %d distinct sources - Sources.cmake format changed" % len(every))

with open(os.path.join(build, "jobs.txt"), "w") as fh:
    for f in every:
        fh.write("%s\t%s\n" % (f, object_path(f)))

with open(os.path.join(build, "links.txt"), "w") as fh:
    for name, files in all_files.items():
        fh.write("%s\t%s\n" % (name, " ".join(object_path(f) for f in files)))

print("  %d distinct sources to compile" % len(every))
PY

# Compiles one source. Invoked by xargs with a single "src<TAB>obj" line.
cat > "$BUILD/compile_one.sh" <<'EOSH'
#!/usr/bin/env bash
set -euo pipefail
line="$1"
src="${line%%$'\t'*}"
obj="${line##*$'\t'}"
cd "$SRCROOT"
if [ "${src##*.}" = "c" ]; then
  exec gcc -O2 -w -DNDEBUG -pthread \
    -I. -Iextern/isocline/include -c "$src" -o "$obj"
fi
exec g++ -O2 -std=c++17 -w -DNDEBUG -pthread \
  -I. -IVM/src -Iextern/isocline/include -IAst/include -ICommon/include \
  -ICompiler/include -IConfig/include -IVM/include -IBytecode/include \
  -IBytecode/src -IRequire/include -ICLI/include -IAnalysis/include \
  -IInliner/include -IInliner/src -ICodeGen/include -c "$src" -o "$obj"
EOSH
chmod +x "$BUILD/compile_one.sh"

echo "==> compiling"
export SRCROOT="$SRC"
expected=$(wc -l < "$BUILD/jobs.txt")
xargs -a "$BUILD/jobs.txt" -d '\n' -P "$(nproc)" -I{} "$BUILD/compile_one.sh" {}

actual=$(find "$OBJ" -name '*.o' | wc -l)
echo "    $actual/$expected objects"
if [ "$actual" -lt "$expected" ]; then
  echo "error: expected $expected objects, found $actual" >&2
  exit 1
fi

echo "==> linking"
while IFS=$'\t' read -r name objs; do
  [ -z "$name" ] && continue
  # shellcheck disable=SC2086
  g++ $objs -o "$OUT/$name" -lm -pthread
  echo "    $OUT/$name"
done < "$BUILD/links.txt"

echo "==> installing to $INSTALL"
mkdir -p "$INSTALL"
for name in luau luau-analyze luau-compile; do
  cp "$OUT/$name" "$INSTALL/$name"
  chmod +x "$INSTALL/$name"
done

echo "==> verifying"
"$INSTALL/luau" --help > /dev/null && echo "    luau OK"
"$INSTALL/luau-analyze" --help > /dev/null && echo "    luau-analyze OK"
"$INSTALL/luau-compile" --help > /dev/null && echo "    luau-compile OK"
echo "==> done"
