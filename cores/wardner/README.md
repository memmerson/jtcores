# Wardner

Toaplan TP-009 / Taito B25 hardware (1987). Sets: Wardner (World), Wardner no Mori
(Japan), Pyros (US).

**Status: planning only. No HDL yet.**

The board is the Flying Shark / Twin Cobra video and DSP hardware with a Z80 main CPU
in place of the 68000:

- Z80 @ 6 MHz (24 MHz XTAL / 4), banked ROM at 0x8000-0xFFFF
- Z80 @ 3.5 MHz for sound, YM3812 @ 3.5 MHz, communication via 2 KB shared RAM
- TMS320C10 DSP @ 14 MHz — required for gameplay, not just protection. It halts the
  main Z80 and drives enemy fire, collisions and sprite placement directly in the
  Z80's RAM.
- Toaplan SCU sprite controller, three 8x8 tilemaps, HD6845S CRTC
- 320x240, 54.878 Hz

See [`doc/plan.md`](doc/plan.md) for the bring-up plan, and `doc/*.cpp` for the MAME
0.289 sources this analysis is based on.
