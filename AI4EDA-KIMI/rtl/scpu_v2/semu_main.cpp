#include "semu.h"

#include <cstdio>

int main() {
  Semu ref;
  std::string error;
  if (!ref.load("sum_io.hex", error)) {
    std::fprintf(stderr, "SEMU ERROR: %s\n", error.c_str());
    return 2;
  }

  ref.set_io(10, 0);
  for (int cycle = 0; cycle < 40; ++cycle) {
    ref.step();
  }

  std::printf("SEMU: pc=%u R0=%u R1=%u R2=%u R3=%u\n", ref.pc(), ref.reg(0),
              ref.reg(1), ref.reg(2), ref.reg(3));

  const bool pass = ref.pc() == 9 && ref.reg(0) == 10 && ref.reg(1) == 10 &&
                    ref.reg(2) == 55 && ref.reg(3) == 1;
  if (!pass) {
    std::fprintf(stderr, "SEMU FAIL: unexpected final state\n");
    return 1;
  }

  std::printf("SEMU PASS: 1+2+...+10=55 after 40 instructions\n");
  return 0;
}
