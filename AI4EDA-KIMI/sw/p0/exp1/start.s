# 最小启动代码：设置栈指针，调用 main，通过 HTIF 退出
  .section .text
  .globl _start
_start:
  la   sp, _stack_top     # 栈顶（link.ld 里定义，0x80004000）
  call main               # 调用 C 的 main
  # main 返回值(a0)作为退出码，走 HTIF tohost 协议
  slli a0, a0, 1
  ori  a0, a0, 1
  la   t1, tohost
  sw   a0, 0(t1)
1: j 1b

  .pushsection .tohost, "aw", @progbits
  .align 3
tohost:   .dword 0
fromhost: .dword 0
  .popsection
