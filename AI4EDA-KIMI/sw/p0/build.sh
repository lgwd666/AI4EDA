#!/bin/bash
# P0 实验编译脚本：编译 + 反汇编导出
# 用法: ./build.sh xxx.s 或 ./build.sh xxx.c
set -e
cd "$(dirname "$0")"
SRC="$1"
BASE="$(basename "$SRC")"; BASE="${BASE%.*}"
GCC=riscv-none-elf-gcc
OBJDUMP=riscv-none-elf-objdump

$GCC -march=rv32im -mabi=ilp32 -nostdlib -static -Wl,-T,link.ld "$SRC" -o "$BASE.elf"
$OBJDUMP -d "$BASE.elf" > "$BASE.dump"
echo "=== 生成: $BASE.elf / $BASE.dump ==="
cat "$BASE.dump"
