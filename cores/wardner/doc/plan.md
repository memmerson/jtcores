# Wardner (Toaplan TP-009 / Taito B25, 1987) — jtcores bring-up plan

Status: **planning only. No HDL written.** Signed off 2026-09-06 — see §10.

Evidence discipline used throughout:

- **[V]** = verified in this session by reading a primary source or running a command.
- **[I]** = inference from those sources. Not tested. Treat as a hypothesis to be
  falsified in simulation.

Primary sources read in full, MAME 0.289 (`mame0289` tag), vendored alongside this
file in `cores/wardner/doc/`:
`wardner.cpp`, `twincobr.cpp`, `twincobr.h`, `twincobr_m.cpp`, `twincobr_v.cpp`,
`toaplan_scu.{h,cpp}`, `toaplan_dsp.{h,cpp}`.

MAME was **not** run in this session — this is a remote Linux container with no MAME,
no ROMs and no Quartus. Everything MAME-derived below is source reading, not
execution.

---

## 0. Corrections to the prior session's findings

Almost all of it held up. Four corrections, one of which is material.

| Prior finding | Verdict | Correction |
|---|---|---|
| Z80 main 6 MHz, Z80 audio 3.5 MHz, DSP 14 MHz, YM3812 3.5 MHz, HD6845S, 320x240, 54.878 Hz | **[V] Correct** | — |
| No jtcore uses a Toaplan driver | **[V] Correct** | Grepped all 92 cores. Zero hits for `toaplan`, `wardner`, `twincobr`, `tms320` outside KiCad symbol tables. |
| DSP is required, not stubbable | **[V] Correct** | `toaplan_dsp.cpp` confirms it reads *and writes* main CPU RAM, sprite RAM and palette RAM, and drives the Z80 HALT line. |
| `modules/jttms` is a red herring | **[V] Correct** | It is an empty submodule pointing at `jotego/jttms` (TMS video). Also empty here: `jtdsp16`, `jtopl`, `jt12` and others — submodules are not checked out in this container. |
| va7deo README's "Not Implemented" is stale | **[V] Correct** | `demonswld/files.qip` contains `rtl/TMS320C1X/TMS320C1X.qip`, and `demonwld.sv:789` instantiates `TMS320C1X dsp` with a BRAM program ROM and a dual-port shared RAM. It ships. |
| **"1 KB `ROM_REGION16_BE`"** | **[C] Minor** | The region is `0x1000` bytes; the dump is `0xc00` bytes = `0x600` 16-bit words. The DSP's internal mask ROM is 1536 words. |
| **"Z80 main @ 6 MHz"** | **[C] Incomplete, and it matters** | The board has **two crystals**. Main Z80 is `24 MHz / 4`. *Everything else* — DSP, audio Z80, YM3812, CRTC and the 7 MHz pixel clock — derives from a **14 MHz** crystal. See §5.1; this is the single biggest clocking decision in the core. |
| **"licence depends on whether the files are v2-or-later"** | **[C] Materially wrong framing** | It is worse than that. See §2.1. |

---

## 1. Hardware, as established from source **[V]**

### 1.1 Clocks and raster

```
XTAL 24 MHz ──/4──► Z80 main        6.000 MHz
XTAL 14 MHz ──────► TMS320C10      14.000 MHz  (CLKIN; internal machine cycle = CLKIN/4)
            ──/4──► Z80 audio       3.500 MHz
            ──/4──► YM3812          3.500 MHz
            ──/4──► HD6845S CRTC    3.500 MHz  (char_width = 2, so 2 px per CRTC char)
            ──/2──► pixel clock     7.000 MHz
```

`m_screen->set_raw(14_MHz_XTAL/2, 446, 0, 320, 286, 0, 240)`
→ 7 000 000 / (446 × 286) = **54.878 Hz**, 320×240 visible, horizontal orientation.

Twin Cobra is the same raster from a 28 MHz crystal (`28/4 = 7 MHz`, same 446×286).
The two boards are timing-identical on the video side. **[V]**

### 1.2 Main Z80 memory map

```
0000-6FFF  ROM (fixed, 28 KB)
7000-7FFF  Work RAM, 4 KB          ← DSP-accessible (segment 0x7000)
8000-8FFF  Sprite RAM, 4 KB        ← DSP-accessible (segment 0x8000)   write always; read only when bank==0
A000-AFFF  Palette RAM, 4 KB       ← DSP-accessible (segment 0xA000)   write always; read only when bank==0
C000-C7FF  Sound shared RAM, 2 KB  write always; read only when bank==0
8000-FFFF  ROM bank window (32 KB) when port 70 != 0
```

The `0x8000-0xFFFF` region is a **memory view**: writes to sprite/palette/sound RAM
always land, but *reads* return either those RAMs (bank select = 0) or the banked ROM.
Bank register is `port 0x70`, `data & 7`, times `0x8000` into a `0x40000` region.
Banks 1 and 6 are unpopulated (`ROMREGION_ERASEFF`). **[V]**

### 1.3 Main Z80 I/O map

| Port | Direction | Function |
|---|---|---|
| `00` / `02` | W | 6845 address / data |
| `10-13` | W | text layer scroll Y lo/hi, X lo/hi |
| `14-15` | W | text VRAM address latch lo/hi |
| `20-25` | W | bg layer scroll + address latch |
| `30-35` | W | fg layer scroll + address latch |
| `40-43` | W | spare 4th layer scroll (**unused on this PCB**) |
| `50` / `52` | R | DSW A / DSW B |
| `54` / `56` | R | P1 / P2 |
| `58` | R | system: service, tilt, test, coins, starts, **bit 7 = VBLANK** |
| `5A` | W | LS259 "coinlatch", nibble `D3..D1` = bit index, `D0` = value |
| `5C` | W | LS259 "mainlatch", same encoding |
| `60-65` | R/W | text / bg / fg VRAM data through the address latch, lo/hi byte |
| `70` | W | ROM bank select |

LS259 bit assignments **[V]**:

```
coinlatch (port 5A)              mainlatch (port 5C)
 0 : DSP INT / run               2 : IRQ enable (VBLANK IRQ to main Z80)
 4 : coin counter 1              3 : flip screen
 5 : coin counter 2              4 : bg VRAM bank (0x1000 word offset)
 6 : coin lockout 1              5 : fg tile ROM bank (wired, unused on Wardner)
 7 : coin lockout 2              6 : display enable (blank to black when 0)
```

Note the asymmetry with Twin Cobra: on Twin Cobra the DSP-run bit is
`mainlatch` bit 6 and display-enable is bit 7; on Wardner the DSP-run bit moved to
`coinlatch` bit 0 and display-enable to `mainlatch` bit 6. **[V]**

### 1.4 Audio Z80

```
program: 0000-7FFF ROM (32 KB)
         8000-807F RAM (128 B)
         C000-C7FF shared with main Z80
         C800-CFFF private RAM (2 KB)
io:      00-01     YM3812
```
IRQ comes from the YM3812 IRQ pin. No sound latch, no NMI handshake — the two Z80s
communicate purely through the 2 KB shared RAM. **[V]** That is unusually simple and
removes a whole class of latency-tuning problems.

### 1.5 Video

Three 8×8 tilemaps plus one sprite layer. None of the VRAM is memory-mapped; it is
all reached through an address-latch + data-port pair, 16-bit words assembled from
byte writes. **[V]**

| Layer | Map | Tile bits | Colour bits | bpp | Tiles | Palette range |
|---|---|---|---|---|---|---|
| text | 64×32 | `code & 0x07FF` | `code >> 11` (5 bits, 32 sets) | 3 | 2048 | 1536-1791 |
| fg | 64×64 | `code & 0x0FFF` | `code >> 12` (4 bits, 16 sets) | 4 | 4096 | 1280-1535 |
| bg | 64×64, banked ×2 | `code & 0x0FFF` | `code >> 12` | 4 | 4096 | 1024-1279 |
| sprites (SCU) | 512 entries | `word0 & 0x07FF` | `word1 & 0x3F` (64 sets) | 4 | 2048 16×16 | 0-1023 |

Draw order, back to front: bg (opaque) → fg (pen 0 transparent) → text (pen 0
transparent) → sprites, where each sprite carries a 2-bit priority that selects which
of those three layers it is allowed to cover:

```
priority 0 : not drawn at all
priority 1 : above bg only
priority 2 : above bg and fg
priority 3 : above everything
```
**[V]** — `toaplan_scu.cpp` skips priority 0 outright, and `twincobr_state::pri_cb`
builds the mask from `GFX_PMASK_{1,2,4}` against the layer priority codes 1/2/4.

SCU sprite word format **[V]**:
```
word0  ---- -xxx xxxx xxxx  tile index
word1  ---- xx-- ---- ----  priority
       ---- --x- ---- ----  flip Y
       ---- ---x ---- ----  flip X
       ---- ---- --xx xxxx  colour set
word2  xxxx xxxx x--- ----  X position (>>7)
word3  xxxx xxxx x--- ----  Y position (>>7); the value 0x100 means "skip"
```

Fixed offsets **[V]**: tilemaps `scrolldx = -55` normal / `-134` flipped,
`scrolldy = -30` / `-243`. Sprites `x - 32` normal, `x - 14` when flipX, `y - 16`.

Palette: 4 KB of byte-writable RAM = 2048 entries, format `xBGR555`, 1792 in use.
The Z80 can write it but the DSP can too (segment `0xA000`). **[V]**

**The 6845 does nothing.** In `wardner_state::wardner()` the CRTC is configured with
`set_screen`, `set_show_border_area(false)` and `set_char_width(2)` — and *nothing
else*. No `set_update_row`, no output callbacks, no `de`/`vsync` handlers. Screen
timing comes from `screen.set_raw()`, not from the CRTC's programmed registers. **[V]**
→ **[I]** We can therefore ignore CRTC register writes entirely and hardcode the
446×286 raster in `jtframe_vtimer`, which is what every other jtcore does. jtframe
ships no 6845 model and does not need one here.

### 1.6 ROM regions (parent set `wardner`) **[V]**

| MAME region | Size | Contents |
|---|---|---|
| `maincpu` | `0x40000` (sparse) | fixed 32 KB @0, banks at 0x10000/0x20000/0x38000 |
| `audiocpu` | `0x8000` | audio Z80 |
| `dsp:dsp` | `0xc00` used of `0x1000` | TMS320C10 program, 16-bit big-endian |
| `chars` | `0xc000` | 3 planes × 16 KB |
| `fg_tiles` | `0x20000` | 4 planes × 32 KB |
| `bg_tiles` | `0x20000` | 4 planes × 32 KB |
| `scu` | `0x40000` | 4 planes × 64 KB, sprites |
| `proms` | `0x260` | 5 PROMs, **unused by MAME** |

Sets: `wardner` (World), `wardnerj` (Japan), `pyros` (US), plus two bootlegs.
All share every graphics ROM except `chars`, and all share the audio ROM.

---

## 2. The DSP route — decide this first

### 2.1 Licensing: the blocker is worse than "v2 vs v2-or-later" **[V]**

I traced the implementation to its origin.

- `va7deo/demonswld/rtl/TMS320C1X/` contains `TMS320C1X.sv` and `TMS320C1X_pkg.sv`.
  **Neither file carries any copyright notice, licence header or SPDX tag.**
- The upstream is **`srg320/TMS320C1X`**. I fetched it. `TMS320C1X_pkg.sv` there is
  **byte-identical** to va7deo's copy (`diff` clean). `TMS320C1X.sv` differs only by
  va7deo's port changes: `PC`/`ROM_Q` exported, internal ROM/RAM instantiations
  commented out and replaced with `dual_port_ram`, `RDY` removed, and a
  `parameter rom_file = "bsmt2000.mif"` dropped — that default filename tells you
  srg320 wrote it for the BSMT2000 sound chip, which embeds a TMS320C15.
- **`srg320/TMS320C1X` has no `LICENSE`, no `COPYING`, and no `README`.** All four
  probes returned 404. There is no licence grant of any kind.

So: va7deo's repository-level GPL-2.0 `LICENSE` file cannot convey rights to code
va7deo does not own. The question is not "is it v2-or-later, and can that go into a
GPL-3.0 project?" — it is "**has anyone granted a licence to this code at all?**"
Absent a grant, it is all-rights-reserved by default.

**[I]** Consequence: copying these files into jtcores is not a decision you or I can
make. It needs srg320 to state a licence (ideally GPL-3.0-or-later or a
GPL-2.0-**or-later** that jtcores can upgrade), and it needs jotego's assent to
carry third-party RTL. Asking costs one GitHub issue and is worth doing early
regardless of which route you take, because a "yes" collapses this task from weeks to
days.

### 2.2 The three routes

| | **A. Reuse srg320's core** | **B. Write a fresh TMS320C10** | **C. Wait for jotego** |
|---|---|---|---|
| Effort | ~2 days integration | **~3-5 weeks** | 0, but indefinite |
| Licence risk | **Blocking today** | None | None |
| Correctness risk | Low — it runs Demon's World in a shipped core | Medium-high — a CPU is where subtle bugs hide | — |
| Verifiable? | Yes, against MAME | Yes, against MAME | — |
| Availability | Needs srg320 to answer | Always | **Nothing exists.** `git log --all --grep` over jtcores and jtframe returns zero hits for tms320/toaplan. **[V]** |

**Recommendation: B, write a fresh one — and open the licence question with srg320 in
parallel.** Reasoning:

1. Route C is not a route. There is no jotego TMS320 work in progress. **[V]**
2. Route A is blocked on a third party who may never reply, and jtcores' uniform
   `GPL-3.0-or-later` headers (654 of them **[V]**) suggest jotego cares about
   provenance. Making the whole core contingent on that answer is bad project risk.
3. The TMS320C10 is genuinely small. It is a Harvard-architecture 16-bit DSP with:
   two auxiliary registers, a 4-level hardware stack, a 32-bit accumulator, one
   16×16 multiplier feeding a 32-bit P register, a barrel shifter on the ALU input,
   a 1-bit status word of consequence (`OV`/`OVM`/`ARP`/`DP`/`INTM`), 144 words of
   internal data RAM, one `INT` line and one polled `BIO` input. Roughly **60
   opcodes**. That is smaller than a Z80 by a wide margin.
4. And critically — you are not writing it blind. You have **three** independent
   references: MAME's `tms320c1x.cpp` (38 KB, the behavioural spec), srg320's RTL
   (readable as documentation even if not copyable), and TI's published TMS32010 user
   guide. Plus a real conformance oracle (§6).

**[I]** If srg320 grants a licence before you reach phase 3, switch to A and save
three weeks. Nothing else in the plan changes — the DSP is behind a clean interface.

### 2.3 How accurate must the DSP be? **[I] — this is the key design insight**

Read `toaplan_dsp.cpp` closely and the answer is: **functional accuracy is enough.
Cycle accuracy buys you nothing.** Here is why, in hardware terms.

The DSP and the main Z80 **never run at the same time during a DSP transaction.**
`dsp_int_w(1)` does three things atomically: releases the DSP from HALT, asserts the
DSP's `INT`, and **asserts the main Z80's HALT line**. The Z80 stops. The DSP then
walks the Z80's address space as sole master. When it is finished it releases the
Z80's HALT itself.

That has three consequences:

1. **There is no bus arbitration to model.** Two masters, mutually exclusive by
   construction. In FPGA terms the DSP can simply be muxed onto the Z80's side of
   each RAM while the Z80 is halted — no second BRAM port needed, no contention
   logic, no wait states.
2. **DSP execution time does not shift game logic.** The Z80's frame is paced by the
   VBLANK IRQ, not by a cycle budget. A DSP that finishes its routine in half the
   real time just hands the Z80 back more idle cycles inside the same frame. The only
   failure mode is a DSP so slow it does not finish within a frame, and we will be
   running it at or above the real 14 MHz.
3. **The handshake is a strict serial protocol**, so it can be verified by comparing
   *transaction sequences* rather than waveforms — much easier to test (§6.2).

What *must* be exact: every opcode's arithmetic result, the overflow/saturation
behaviour (`OVM`), `SUBC`, the barrel shift on ALU input, `ARP`/`DP` addressing
side effects, the 4-level stack, and the `INT`/`BIO` semantics. Those are
correctness, not timing.

**[I] Caveat to test, not assume:** after the DSP releases the Z80's HALT, the DSP
keeps running until the Z80 clears the `coinlatch` bit 0. There is a short window of
genuine concurrency. My reading is that the DSP is spinning on `BIO` in that window
and touches nothing, but I have not proven it. Mitigation: give the shared RAMs true
dual ports anyway (jtframe's `jtframe_dual_ram` costs nothing extra in M10K), so a
stray access is harmless rather than corrupting. Cheap insurance.

### 2.4 The DSP↔host protocol, as pseudocode **[V]**

Numbered reduction of `toaplan_dsp.cpp` + `wardner_state::dsp_host_*_cb`, control
flow and side effects only:

```
DSP-side I/O ports (the DSP's OUT/IN instructions):
  1. OUT port 0, value V  → latch an address into the host window:
        seg  := V & 0xE000 ;  if seg == 0x6000 then seg := 0x7000
        addr := (V & 0x07FF) << 1        (word-aligned byte offset)
  2. IN  port 1           → read 16 bits from host space at seg+addr,
                            little-endian (low byte first). Legal segs: 7000, 8000, A000.
  3. OUT port 1, value D  → write 16 bits to host space at seg+addr, little-endian.
                            SIDE EFFECT: if seg == 0x7000 and addr < 3 and D == 0,
                            arm the "release host" flag.
  4. OUT port 3, value B  → if bit 15 of B is set, deassert BIO.
                            if B == 0:
                                 if "release host" flag is armed:
                                       deassert the main Z80's HALT line
                                       clear the flag
                                 assert BIO.
  5. IN  BIO              → polled by the DSP's BIOZ branch instruction.

Host-side control (main Z80 OUT to port 0x5A with D3..D1 == 000):
  6. D0 = 1 → release DSP from HALT, assert DSP INT, assert main Z80 HALT.
  7. D0 = 0 → deassert DSP INT, assert DSP HALT.

Resulting whole-transaction sequence:
  8.  Z80 writes command words into work RAM at 0x7000..
  9.  Z80 sets coinlatch bit 0 → step 6 → Z80 freezes, DSP wakes on INT.
  10. DSP reads/writes 0x7000 (work RAM), 0x8000 (sprite RAM), 0xA000 (palette RAM)
      via steps 1-3, computing shots, angles, collisions, sprite placement.
  11. DSP writes 0 to 0x7000+{0 or 2} → arms the release flag (step 3).
  12. DSP writes 0 to port 3 → Z80's HALT released (step 4). Z80 resumes mid-frame.
  13. DSP loops on BIO.
  14. Z80 clears coinlatch bit 0 → step 7 → DSP halts. Idle until step 9 again.
```

Twin Cobra runs the **identical protocol**; only step 1's address decode differs
(`seg = (V & 0xE000) << 3`, `addr = (V & 0x1FFF) << 1`, segments `0x30000/0x40000/0x50000`,
16-bit accesses because the host is a 68000). **[V]** So a `jtwardner_dsp_ctrl` module
written now needs one parameterised address decoder to serve both boards later.

---

## 3. Wardner vs Twin Cobra: precise shared/different map **[V]**

| Block | Shared? | Detail |
|---|---|---|
| TMS320C10 CPU | **Identical** | Same part, same 14 MHz-class clock (TC uses 28/2). MCUs interchangeable per MAME. |
| DSP↔host handshake FSM | **Identical** | `toaplan_dsp.cpp` is one device serving both. |
| DSP address decoder | **Different** | Wardner: 3-bit seg, 11-bit addr, byte-pair access. TC: 3-bit seg <<3, 13-bit addr, word access. |
| `toaplan_scu` sprites | **Identical logic** | Only `set_xoffsets`: Wardner (32, 14), TC (31, 15). |
| Tilemaps, scroll, VRAM-via-port | **Identical** | Same `twincobr_v.cpp` code, same sizes, same scroll offsets, same priorities. |
| Palette | **Identical** | xBGR555, 1792 colours, same layer bases. |
| Raster | **Identical** | 7 MHz pixel, 446×286, 320×240, 54.878 Hz. |
| CRTC | **Identical** | HD6845S @3.5 MHz, char_width 2, functionally inert. |
| YM3812 + audio Z80 | **Identical** | 3.5 MHz each, shared-RAM comms. |
| **Main CPU** | **Different** | Wardner: Z80 @6 MHz, banked, byte-wide, ports. TC: 68000 @10 MHz, memory-mapped. |
| LS259 bit assignment | **Different** | DSP-run and display-enable bits swap latches (§1.3). |
| Sprite RAM buffering | Same idea | Wardner buffers 8-bit on VBLANK rising, TC 16-bit. Both double-buffer. |

**[I]** Practical read: about **80 % of the RTL is board-common**. If the modules are
named `jttoaplan1_*` rather than `jtwardner_*` from day one, Twin Cobra / Flying Shark
/ Sky Shark become "swap the main CPU and the address decoder", not a second core.
That is the strongest argument for framing this as **Toaplan Twin Cobra hardware**,
with Wardner as the first supported set — and it costs nothing extra now.

---

## 4. jtcores conventions for a new core **[V]**

### 4.1 Which existing core to model on

I looked at `harier` (newest, Sept 2026), `moo`, `taitox`, and the cores that use
`jtopl2`: `bubl`, `castle`, `kunio`, `pktgal`, `pang`, `cop`.

**Model on `bubl` (Bubble Bobble).** Not `karnov` — Karnov is a 68000 core and its
shape does not match. Not `toki` — Toki is 68000 + Seibu sound. `bubl` is the right
model because it is structurally the same problem:

- three CPUs (main Z80 + sub Z80 + sound Z80) → we have main Z80 + audio Z80 + DSP;
- a **coprocessor whose program ROM lives in BRAM**, loaded from the ROM download by
  an offset trick in `mem.yaml` — exactly what the DSP needs;
- banked main ROM in SDRAM;
- an OPL-family FM chip through `jtopl`.

Take the **sound** shape from `pktgal`/`kunio` instead, since Wardner's chip is a
YM3812 = `jtopl2`, and `bubl`'s is a YM3526 = `jtopl`. Verified instantiation, from
`cores/pktgal/hdl/jtpktgal_sound.v:155`:
`jtopl2(.rst, .clk, .cen, .din, .addr, .cs_n, .wr_n, .dout, .irq_n, .snd, .sample)`.

### 4.2 Required layout

```
cores/wardner/
  README.md                 core description, credits
  cfg/
    macros.def              core name, video geometry, rate, SDRAM bank starts, per-target overrides
    mem.yaml                clocks (cen signals), audio mixer, SDRAM banks/buses, BRAM blocks
    mame2mra.toml           sourcefile, ROM region order/transforms, DIPs, buttons, header
    files.yaml              which HDL files and which shared modules to pull in
    reg.yaml                simulation input mapping (points at a .cab file)
    msg                     the OSD splash text
  doc/                      vendored MAME sources  ← already populated
  hdl/
    jtwardner_game.v        top level, wiring, SDRAM buses
    jtwardner_main.v        main Z80, banking, LS259s, port decode
    jtwardner_sound.v       audio Z80 + jtopl2
    jtwardner_dsp.v         TMS320C10 wrapper + handshake FSM + host-window decode
    jtwardner_video.v       vtimer + layer arbitration
    jtwardner_scroll.v      the three tilemaps
    jtwardner_obj.v         SCU sprite engine
    jtwardner_colmix.v      palette lookup + priority mux
  ver/
    game/                   sim.sh, trace scripts
    <setname>/*.cab         recorded input scripts for regression
```

`cfg/mem.yaml` is the important one — `jtframe mem` generates the game module's port
list from it, so it defines the interface before you write any HDL. Confirmed
features we need **[V]**: `clocks:` with `freq:` entries that are PLL-aware,
`sdram.banks[].buses[]` with per-bus `addr_width`/`data_width`/`offset`, and `bram:`
entries supporting `dual_port:` (independent addr/din/dout/we) and
`rom: { offset: ... }` to load a BRAM from the downloaded ROM file.

---

## 5. The design

### 5.1 Clocking — the one real decision

Two crystals, and 6 MHz and 14 MHz have no useful common multiple near jtframe's
48 MHz.

**Option 1 — default `jtframe_pll6000`, 48/96 MHz.** 6 MHz main Z80 is an exact `/8`.
Everything on the 14 MHz side becomes a fractional clock enable via
`jtframe_frac_cen` (14 = 48 × 7/24, 3.5 = 48 × 7/96, pixel 7 = 48 × 7/48).
Fractional cens are standard practice in jtcores and average out exactly; they add
period jitter of one 48 MHz tick, which is invisible to everything here.

**Option 2 — `jtframe_pll7000`.** This exists **[V]** and gives 56 / 28 / 112 / 7 MHz.
56 MHz is exactly 4 × 14 MHz, so DSP (`/4`), audio Z80 (`/16`), YM3812 (`/16`),
CRTC (`/16`) and pixel clock (`/8`) are all **exact integer divides**. The 6 MHz main
Z80 becomes the fractional one (6 = 56 × 3/28). But `pll7000` is built for the
**MiSTer target only** — the `mist`, `sidi`, `sidi128` and `pocket` trees have no
`pll7000`, and `cps3` (its only current user) carries `JTFRAME_SKIP` for all of them. **[V]**

**Recommendation: Option 1.** Take the default PLL and put the fractional cen on the
14 MHz domain. It keeps every target buildable, it is what most jtcores do, and the
exactness Option 2 buys is not audible or visible — the YM3812's output is resampled
anyway and 54.878 Hz is set by `JTFRAME_RATE`, not by the cen jitter.

**[I]** BRAM is the real target constraint, not the PLL. Rough budget: main RAM 4 K +
sprite RAM 4 K + palette 4 K + sound shared 2 K + sound private 2 K + text VRAM 4 K +
fg VRAM 8 K + bg VRAM 16 K + DSP program 4 K + DSP data RAM 0.5 K ≈ **49 KB**, before
jtframe's line buffers and OSD. Comfortable on MiSTer's Cyclone V (553 KB M10K).
Likely **not** buildable on MiST/SiDi's EP3C25 (66 KB) — expect to add
`[mist|sidi] JTFRAME_SKIP`, exactly as `bubl` and `harier` do. **[V]** that those
cores do it; **[I]** that we will need to.

### 5.2 SDRAM layout

Total ROM ≈ 851 KB — trivial. Split across banks by access pattern, not by size:

| Bank | Buses | Width | Notes |
|---|---|---|---|
| 0 | `main` | 8 | 256 KB region, sparse; fixed 28 KB + 8 banks × 32 KB |
| 1 | `snd` | 8 | 32 KB audio Z80 |
| 2 | `char`, `scr1`, `scr2` | 32 | three tilemap ROMs, one 32-bit fetch = one tile row |
| 3 | `obj` | 32 | 256 KB sprite ROM |

**[I]** Widths chosen so a single SDRAM read yields a whole 8-pixel row: for the 4bpp
layers the four planes are contiguous 32 KB apart, so a 32-bit read with the planes
interleaved at MRA build time gives 8 pixels per access. The text layer is 3bpp and
gets padded to 4. This is the standard jtcores tile-fetch idiom.

### 5.3 The DSP integration, concretely

```
             ┌──────────────────┐
   coinlatch │  jtwardner_dsp   │
   bit 0 ───►│                  │
             │  handshake FSM   │──── halt_z80 ──────────────► main Z80 WAIT/BUSRQ
             │        │         │
             │  ┌─────▼──────┐  │
             │  │ TMS320C10  │  │◄── program ROM  (BRAM 2048×16, from ROM download)
             │  │   core     │  │◄── data RAM     (BRAM  256×16, internal)
             │  └─────┬──────┘  │
             │        │ ports 0/1/3
             │  ┌─────▼──────┐  │
             │  │ host window│  │
             │  │  decoder   │  │──── 16-bit access to work / sprite / palette RAM
             │  └────────────┘  │     (muxed onto the Z80 side while Z80 is halted)
             └──────────────────┘
```

**Halting the Z80.** MAME asserts `INPUT_LINE_HALT`. In real hardware the DSP asserts
the Z80's `BUSRQ` and waits for `BUSAK`, or holds `WAIT`. **[I]** With T80 in jtcores
the cleanest model is to gate the Z80's clock enable — hold `cen` low and the CPU
freezes exactly where it is, which is behaviourally what we need and avoids relying on
T80's `BUSRQ` timing. This is a decision to validate in sim, not to assume.

**Program ROM loading.** Follow `bubl`'s pattern exactly **[V]**: a `bram:` entry with
`rom: { offset: "((`DSP_START-`JTFRAME_BAn_START)>>1)|24'h800000" }`. The `>>1` is
because the BRAM is 16 bits wide and the download is byte-addressed.

**Endianness.** MAME's region is `ROM_REGION16_BE` — the file is big-endian words —
but the DSP's *view of host memory* is little-endian (low byte at even address). **[V]**
Two different orderings in the same subsystem; getting this wrong is the single most
likely early bug. Test it explicitly (§6.1).

### 5.4 Video pipeline

Standard jtcores shape, no surprises:

```
jtframe_vtimer  (446×286, 320×240 visible, hardcoded — no 6845 model)
      │
      ├─ jtwardner_scroll  ─ bg  (64×64, banked, 4bpp, opaque)
      │                    ─ fg  (64×64, 4bpp, pen 0 transparent)
      │                    ─ text(64×32, 3bpp, pen 0 transparent)
      │
      ├─ jtwardner_obj     ─ 512 sprites, 16×16 4bpp, 2-bit priority,
      │                      double-buffered on VBLANK rising edge
      │
      └─ jtwardner_colmix  ─ priority resolution → palette RAM → xBGR555 → RGB
```

Priority resolution **[I]**: rather than MAME's bitmask approach, generate a 2-bit
"layer depth" per pixel (bg=1, fg=2, text=3) and compare against the sprite's
priority code — a sprite wins where `spr_pri >= layer_depth` and its pixel is
non-transparent, with priority 0 sprites suppressed entirely. That reproduces the
mask table in `pri_cb` with a comparator instead of a lookup. Needs proving against
MAME frames, especially the shop scenes that `twincobr_v.cpp`'s own header comment
flags as anomalous.

### 5.5 MRA / ROM assembly — one known limitation **[V]**

`jtframe`'s `mame2mra` supports `sequence`, `width`, `reverse`, `rom_len`, `mirror`,
`splits` (halves) and `patches`. It has **no nibble-interleave transform.**

That matters because the bootleg set `wardnerb` stores the DSP program in eight
82S131/82S137 PROMs combined with `ROM_NIBBLE | ROM_SHIFT_NIBBLE_HI/LO | ROM_SKIP(1)`.
The MRA cannot reconstruct those words.

→ **Target the parent `wardner` set**, which has a single flat `0xc00`-byte DSP dump.
It is flagged `BAD_DUMP` in MAME only because the true Wardner MCU (71900) is
undumped and MAME substitutes the Flying Shark / Twin Cobra MCU (71001) — which the
MAME comment states, and the family's documented interchangeability supports, is the
same program. **[V]** that MAME does this; **[I]** that it is faithful.

If bootleg support is later wanted, the fix is a small upstream contribution to
`mame2mra`'s region transforms — worth flagging to jotego but not a phase-1 problem.

---

## 6. Verification strategy

Evidence over inspection, in three tiers. Each tier is a hard gate.

### 6.1 Tier 1 — DSP conformance against MAME, before any video exists

This is the highest-value test in the whole project and it needs **no ROM dump of
Wardner's graphics** — only the DSP program, which is 3 KB.

1. Run MAME with `-debug -debugscript`, tracing the TMS320C10 only: PC, ACC, AR0/AR1,
   T, P, ST, and every port 0/1/3 transaction, one line per instruction. (Your note
   that headless MAME never exits is expected — kill it and use the partial trace.)
2. Feed the same program ROM into an iverilog testbench wrapping the new DSP, with
   the host window backed by a plain array preloaded from MAME's memory dump at the
   same instant.
3. Diff the two traces. First divergence = first wrong opcode, with the exact
   instruction word in hand.

**[I]** This converts "write a CPU core" from an open-ended risk into a bounded
debugging loop with an oracle. It is also why I am comfortable recommending route B.

Secondary oracle: `unidasm` the DSP ROM to get a full listing of the 1536 words, so
you know which of the ~60 opcodes the program actually uses — likely far fewer, which
lets you prioritise.

### 6.2 Tier 2 — transaction-level equivalence

Because the protocol is strictly serial (§2.4), the *sequence* of
`(seg, addr, read/write, data)` tuples per DSP invocation is a complete behavioural
signature. Log it from both MAME and the sim and diff. This catches address-decode
and endianness bugs immediately, and it is far more diagnostic than a screenshot.

### 6.3 Tier 3 — frame comparison

`cores/karnov/ver/game/` has `mksnap.mame`, `mksnap.sh`, `cpsnap.sh` and `trace.mame`
**[V]** — the established jtcores harness for dumping MAME frames and comparing them
against simulation output. Reuse it verbatim. Record `.cab` input scripts under
`ver/wardner/` for: boot + POST, attract loop, coin-up + level 1, and the shop scene
(the priority edge case).

### 6.4 Lint discipline

`jtsim -verilator -lint` on every change (your ~7 s figure). Long simulations only
after lint is clean.

---

## 7. Phased order of work — risk first

| Phase | Work | Gate | Needs ROM? |
|---|---|---|---|
| **0** | Ask srg320 for a licence on `TMS320C1X`. Ask jotego whether a Toaplan/TMS320 core is wanted and whether third-party RTL is acceptable. Set up the space-free git worktree for sim. | Both questions asked | No |
| **1** | **TMS320C10 core.** Opcode-complete, testbench-driven, verified by trace diff against MAME (§6.1). Nothing else. | Trace diff clean over a full DSP invocation | **DSP ROM only (3 KB)** |
| **2** | **DSP wrapper + handshake FSM + host-window decode.** Standalone testbench with a fake host RAM. Verified by transaction diff (§6.2). | Transaction diff clean | DSP ROM only |
| **3** | **Core skeleton.** `cfg/*`, `jtwardner_game.v`, main Z80 + banking + LS259s + port decode + work RAM. Boot to the point where the Z80 first pokes the DSP. | Z80 reaches the DSP handshake, main ROM checksum passes | **Yes — full set** |
| **4** | **Sound.** Audio Z80 + `jtopl2` + shared RAM. | Music and SFX play | Yes |
| **5** | **Video.** vtimer, three tilemaps, palette, colmix. Sprites last. | Frame-compares against MAME | Yes |
| **6** | **Sprites + priority.** The SCU, double buffering, the priority comparator. | Shop scene matches | Yes |
| **7** | **Polish.** Flip screen, DIPs, MRA for all four playable sets, cheat/NVRAM, `msg`. | `jtcore wardner -mister` builds clean on gunmetal | Yes |
| **8** | *(optional)* Rename modules `jttoaplan1_*` and add Twin Cobra / Flying Shark. | — | Their ROMs |

Phases 1-2 are ~60 % of the total effort and need **only the 3 KB DSP ROM**, not a
Wardner set. That is a deliberate ordering choice: it front-loads the risk and defers
the dependency.

> **Point of dependency, stated plainly:** you said you do not have a Wardner ROM
> dump. **Phases 0-2 do not need one** beyond the DSP program. **Phase 3 onward
> cannot start without the full `wardner` set** — there is no way to bring up a main
> CPU without its ROM. Please have that sorted before phase 3, or phase 1 will
> complete and the project will stall.

---

## 8. Honest scale estimate, and whether to do it

### Scale

| Component | New or reused | Estimate |
|---|---|---|
| TMS320C10 core | **New** (route B) | 3-5 weeks |
| DSP wrapper + handshake | **New** | 3-4 days |
| Main Z80 subsystem | T80 reused, glue new | 4-5 days |
| Sound subsystem | `jtopl2` + T80 reused, glue new | 2-3 days |
| Tilemaps | New, conventional | 1 week |
| SCU sprites + priority | New | 4-5 days |
| Palette / colmix | New, small | 2 days |
| MRA, DIPs, config, polish | New | 3-4 days |
| Verification harness | Adapted from `karnov` | 3-4 days |
| **Total, route B** | | **~10-13 weeks** part-time |
| **Total, route A** (licence granted) | | **~6-8 weeks** |

Calibration: you have no Verilog experience. **[I]** For a first FPGA project this is
a hard one — the DSP alone is a bigger task than most complete first cores, and the
board has three processors. A reasonable expectation is that the *stated* estimate is
the experienced-developer figure and a first-timer should roughly double it, with the
learning concentrated in phases 1 and 5.

That is not an argument against doing it. It is an argument for taking phase 1
seriously as a self-contained project with its own oracle, and for not starting phase
3 until phase 2's transaction diff is clean.

### Is it worth doing at all?

**Yes, and the DSP is the reason.** The case:

- **Nothing else fills this gap.** No MiSTer core, no openFPGA core, no jtcore covers
  Wardner or Twin Cobra. `va7deo`'s Toaplan V1 core deliberately covers only the
  DSP-less titles. **[V]**
- **One DSP unlocks a family.** Wardner, Twin Cobra, Flying Shark, Sky Shark and
  Demon's World all use the TMS320C10, and MAME documents the Wardner / Flying Shark /
  Sky Shark MCUs as interchangeable. **[V]** With §3's 80 % commonality, the marginal
  cost of the second and third games is small.
- **It is reusable beyond Toaplan.** The TMS320C1x turns up in the BSMT2000 (whence
  srg320's original), in Taito's and Konami's later boards, and elsewhere. A
  GPL-3.0-or-later TMS320C10 with a MAME-verified trace suite is a genuinely useful
  contribution to jtcores as a `jt32010` module, a sibling of `jtdsp16` (name follows `jt6295`/`jt7759`).

### The alternative: contribute the DSP to va7deo instead

Worth naming honestly. `va7deo/demonswld` already has a working TMS320C1X, so it does
**not** need one; contributing there would mean contributing a *Wardner core* to a
different framework, not a DSP. And their framework is a different (non-jtframe) one,
GPL-2.0, with hand-rolled SDRAM and no MRA-generation tooling.

**[I]** Recommendation: build it in jtcores. Write the DSP as
a standalone `jt32010` repository from the start, in the `jtdsp16` pattern — a standalone, separately-testable, GPL-3.0-or-later
module with its own testbench — so that even if the Wardner core stalls, the DSP is a
finished, useful artifact. That structure also makes it trivially droppable if
srg320's licence comes through and you decide to swap implementations.

---

## 9. Open questions for you

1. **Route A or B?** My recommendation is B (write fresh) with the licence question
   asked in parallel. Say the word if you would rather block on srg320's answer.
2. **PLL:** default 48 MHz + fractional 14 MHz cens (portable), or `pll7000`
   (exact clocks, MiSTer-only)? I recommend the former.
3. **Scope:** name it `wardner` now, or `toaplan1`/`twincobr` with Wardner first? I
   recommend module names that are board-generic from day one, whatever the core is
   called — it costs nothing now and saves a fork later.
4. **ROM dump:** needed before phase 3. Parent `wardner` set.
5. Do you want me to open the licence issue on `srg320/TMS320C1X` and the core
   proposal with jotego, or will you?

---

## 10. Decisions taken (2026-09-06)

| Question | Decision | Consequence |
|---|---|---|
| DSP route | **B — write a fresh TMS320C10.** Licence request to srg320 sent in parallel. | Phase 1 is a from-scratch CPU. If a licence lands before phase 3, route A remains an option. |
| PLL | **Default `jtframe_pll6000`**, fractional cens on the 14 MHz domain. | All targets remain buildable. `pll7000` not used. |
| Naming | **Board-generic module names** from day one. | Core folder stays `wardner`; HDL modules are `jttoaplan1_*` (subject to jotego's preference). The DSP is a standalone `jt32010` repo. |

Two drafts accompany this decision, both awaiting the author's review before posting:

- `msg-srg320-licence.md` — licence request for `srg320/TMS320C1X`
- `msg-jotego-proposal.md` — core proposal for `jotego/jtcores`

### CI note for phase 3 **[V]**

`lint-all.sh` iterates every directory under `cores/` and `lint-one.sh` skips only
when `cfg/macros.def` is absent or `cfg/skip` exists. The compile matrices in
`q13.yaml`, `q20.yaml`, `pocket.yaml` and `debug-builds.yaml` use the same test.
So the docs-only `cores/wardner/` is invisible to CI today, but **the commit that
adds `cfg/macros.def` puts `wardner` into the linter and every compile matrix.**
Add `cfg/skip` in that same commit and remove it in the PR that makes the core lint
clean. (Note: `memmerson/jtcores` currently has GitHub Actions disabled — zero
workflow runs — so none of this fires on the fork until Actions is enabled.)
