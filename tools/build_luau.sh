#!/usr/bin/env bash
# Builds the Luau CLI toolchain (luau, luau-analyze, luau-compile) from source.
#
# Why: the sandbox has no network access to the Luau release assets, and no
# cmake, so the three CLIs are compiled directly with g++ from the release
# tarball. Output goes to tools/bin/ which is git-ignored.
#
# Requirements: g++ (>= 10), make, tar, curl, python3.
# Runtime: about 3 minutes with -j on 8 cores.
set -euo pipefail

VERSION="${1:-0.744}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$(mktemp -d)"
OBJ="$BUILD/obj"
OUT="$ROOT/tools/bin"

mkdir -p "$OBJ" "$OUT"
cd "$BUILD"

echo "==> fetching Luau $VERSION"
curl -sSL "https://codeload.github.com/Roblox/luau/tar.gz/refs/tags/$VERSION" -o luau.tar.gz
tar xzf luau.tar.gz
SRC="$BUILD/luau-$VERSION"
cd "$SRC"

INC="-I. -IVM/src -Iextern/isocline/include -IAst/include -ICommon/include -ICompiler/include -IConfig/include -IVM/include -IBytecode/include -IBytecode/src -IRequire/include -ICLI/include -IAnalysis/include -IInliner/include -IInliner/src -ICodeGen/include"
CXXFLAGS="-O2 -std=c++17 -w -DNDEBUG -pthread"

echo "==> collecting sources"
python3 - "$SRC" "$BUILD/sources.txt" <<'PY'
import os, re, sys
root, out = sys.argv[1], sys.argv[2]
cmake = open(os.path.join(root, "Sources.cmake")).read()
files = [m for m in re.findall(r'"([^"]+\.(?:cpp|c))"', cmake)]
files = [f for f in files if not f.endswith("UnwindBuilderWin.cpp")]
files += ["extern/isocline/src/isocline.c"]
seen, ordered = set(), []
for f in files:
    if f not in seen and os.path.isfile(os.path.join(root, f)):
        seen.add(f)
        ordered.append(f)
open(out, "w").write("\n".join(ordered))
print(len(ordered), "sources")
PY

echo "==> compiling"
cut -d$'\n' -f1 "$BUILD/sources.txt" > /dev/null 2>/dev/null || true
mapfile -t SOURCES < "$BUILD/sources.txt"
printf '%s\n' "${SOURCES[@]}" | xargs -P "$(nproc)" -I{} \
  bash -c 'o='"$OBJ"'/"$(echo "{}" | tr "/" "_" | sed "s/\.cpp$//;s/\.c$//")".o; \
           if [ "${1##*.}" = "c" ]; then gcc '"$CXXFLAGS"' -I'"$SRC"' -c "$1" -o "$o"; \
           else g++ '"$CXXFLAGS"' '"$INC"' -I'"$SRC"' -c "$1" -o "$o"; fi' _ {}

echo "==> linking"
link() {
  local name="$1"; shift
  local objs=()
  for o in "$OBJ"/*.o; do
    local base
    base="$(basename "$o")"
    case "$base" in
      CLI_src_Analyze*) [ "$name" = "luau" ] && continue ;;
      CLI_src_Compile*) [ "$name" != "luau-compile" ] && continue ;;
      CLI_src_Repl*) [ "$name" = "luau-analyze" ] && continue ;;
    esac
    objs+=("$o")
  done
  g++ "${objs[@]}" -o "$OUT/$name" -lm -pthread
  echo "    $OUT/$name"
}
link luau
link luau-analyze
link luau-compile

echo "==> done"
"$OUT/luau" --help > /dev/null && echo "luau OK"
