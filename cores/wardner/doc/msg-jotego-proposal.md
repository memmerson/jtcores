# Draft: core proposal to jotego

**Where:** open as an issue on https://github.com/jotego/jtcores
**Title:** Proposal: Toaplan TP-009 / Twin Cobra hardware core (Wardner first), plus a TMS320C10 module

---

Hi Jose,

I'd like to contribute a core for Toaplan's 1987 TMS320C10 boards and want to check
the shape of it with you before writing HDL, so that what arrives matches what you'd
accept.

## The hardware

Toaplan TP-009 (Wardner / Pyros / Wardner no Mori, Taito B25) is the Flying Shark and
Twin Cobra video and DSP hardware with a Z80 main CPU in place of the 68000:

- Z80 @ 6 MHz (24 MHz XTAL / 4), banked ROM
- Z80 @ 3.5 MHz + YM3812 @ 3.5 MHz for sound, communicating through 2 KB of shared RAM
- TMS320C10 @ 14 MHz as a coprocessor. It is not just protection: it computes enemy
  fire, collisions and sprite placement and writes them straight into the Z80's work
  RAM, sprite RAM and palette RAM. While it runs it holds the Z80's HALT line.
- Toaplan SCU sprites (512 × 16×16, 4 priority levels), three 8×8 tilemaps, HD6845S
- 7 MHz pixel clock, 446×286 raster, 320×240, 54.878 Hz

Twin Cobra / Flying Shark / Sky Shark share roughly 80% of this: the DSP, the
handshake, the SCU, the tilemaps, the palette, the raster and the sound section are
the same. Only the main CPU (68000 vs Z80) and the DSP's host-address decoder differ.
Demon's World uses the same DSP again. None of these has a jtcore, a MiSTer core, or
an openFPGA core today; va7deo's Toaplan V1 core deliberately covers only the DSP-less
titles.

## What I'm proposing

1. **A core named `wardner`** (open to a family name instead), built strictly to the
   jtframe conventions — `mem.yaml`, `macros.def`, `mame2mra.toml`, `files.yaml`,
   modelled on `bubl` for structure and on `pktgal`/`kunio` for the `jtopl2` sound
   section. Default PLL with fractional clock enables for the 14 MHz domain, so it
   builds for every target; it will likely need `JTFRAME_SKIP` on mist/sidi for
   BRAM reasons, as `bubl` and `harier` do. Modules named board-generically
   (`jttoaplan1_*` or whatever you prefer) so that Twin Cobra and Flying Shark become
   "swap the main CPU and the decoder" later rather than a second core.

2. **A TMS320C10 CPU as a standalone module**, in the same pattern as `jtdsp16`:
   its own repository, GPL-3.0-or-later, with a testbench that diffs instruction
   traces against MAME's `tms320c1x` debugger output. I'd suggest the name
   `jt32010` to match `jt6295` / `jt7759`, but that's yours to call. It's a small
   part — ~60 opcodes, two aux registers, a 4-level stack, a 16×16 multiplier — and
   it unlocks five Toaplan games plus the BSMT2000 sound chip.

Regarding accuracy: reading MAME's `toaplan_dsp.cpp`, the DSP and the host CPU are
mutually exclusive by construction (the DSP is released and the host halted in the
same write, and the DSP releases the host itself when done), so functional accuracy
is sufficient and there is no bus arbitration to model. I'd still give the shared
RAMs true dual ports for safety.

## Three things I'd like your view on

**a. Third-party RTL.** A TMS320C1X implementation exists (`srg320/TMS320C1X`, used by
va7deo's Demon's World core), but the upstream carries no licence at all, and
va7deo's repository-level GPL-2.0 can't speak for code it doesn't own. I've asked
srg320 whether they'd add a licence. If they do, would you accept that module in
jtcores under GPL-3.0-or-later with attribution, or would you prefer a from-scratch
implementation regardless? I'm planning for from-scratch either way, so this only
changes the timeline.

**b. A small `mame2mra` gap.** The bootleg set `wardnerb` stores the DSP program
across eight PROMs using `ROM_NIBBLE | ROM_SHIFT_NIBBLE_HI/LO | ROM_SKIP(1)`.
`mame2mra` has `sequence`, `width`, `reverse`, `splits` and `patches` but no
nibble-interleave transform, so the MRA can't reconstruct it. The parent set is fine
(single flat dump), so this isn't blocking — but would you take a small PR adding a
nibble transform to the region options?

**c. CI while in development.** Once `cfg/macros.def` exists the core enters
`lint-all.sh` and every compile matrix. I'd add `cfg/skip` until it lints clean and
remove it in the same PR that makes it build. Is that the convention you'd want, or
do you prefer `JTFRAME_SKIP` in `macros.def` from day one?

## Where it is

The due-diligence is written up with every claim marked verified-against-source or
inferred, alongside the MAME 0.289 sources it's based on:
https://github.com/memmerson/jtcores/pull/1 (draft, docs only, no HDL yet).

If the answer is "not interested", that's fine too — I'd rather know before writing
the DSP than after.

Thanks,
Marc
