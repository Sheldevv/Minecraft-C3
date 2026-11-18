#!/bin/sh
set -eu

TARGET="TerraBlock-mingw-x64"
OBJDIR="build/obj/mingw-x64"
RAYLIB="build/unpacked_c3l/raylib.c3l/libs/mingw-x64/libraylib.a"
OUTPUT="build/TerraBlock-mingw-x64.exe"

if [ ! -f "$RAYLIB" ]; then
    echo "Error: raylib MinGW library not found: $RAYLIB" >&2
    exit 1
fi

echo "==> Compiling C3 objects..."

rm -rf "$OBJDIR"
c3c build "$TARGET"

echo "==> Linking Windows executable..."

x86_64-w64-mingw32-gcc \
    -mconsole \
    -municode \
    $(find "$OBJDIR" -type f -name '*.obj') \
    "$RAYLIB" \
    -o "$OUTPUT" \
    -lopengl32 \
    -lgdi32 \
    -lwinmm \
    -lws2_32 \
    -ldbghelp \
    -lshlwapi \
    -lm \
    -Os

echo "==> Build successful!"
file "$OUTPUT"
