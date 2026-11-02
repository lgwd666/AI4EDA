/* 最小 linker script：P0/P1 阶段内存布局
 * 代码/数据: 0x80000000 起（spike 默认内存起始地址，也是 SoC 常用约定）
 * 栈:        0x80010000 起，16KB
 */
OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : { *(.text) }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss) }

  . = 0x80010000;
  .stack : {
    . = . + 0x4000;
    _stack_top = .;
  }
}
