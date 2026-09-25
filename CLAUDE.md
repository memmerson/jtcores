# CLAUDE.md — Working on JTCORES FPGA cores

Guidance for Claude (and other LLM agents) working in this repository. It
summarises the JTFRAME methodology set up by Jose Tejada (jotego) and the
conventions visible across `cores/`. When this file and the JTFRAME docs
disagree, **the docs in `modules/jtframe/doc` and the tool `--help`/man pages
win** — they track the code; this file is a map, not the source of truth.

## 1. Mental model

- `cores/<core>/` — one folder per *hardware platform* (PCB family), not per
  game. One core usually runs many MAME sets (parents, clones, sibling games on
  the same board).
- `modules/jtframe/` — the framework: target wrappers (MiST, MiSTer, SiDi,
  Pocket, …), SDRAM/BRAM controllers, CPU wrappers, video/audio helpers, and
  the Go tool `jtframe` that turns declarative config into RTL and projects.
- `modules/jt*` — sound chips, CPUs and custom ICs as git submodules
  (`jt51`=YM2151, `jt12`=YM2203/2608/2610, `jt49`=AY/YM2149, `jt6295`=OKI
  MSM6295, `jt5205`, `jt7759`, `jtkcpu`=Konami CPU, `jt680x`, `jt8051`,
  `jt900h`, `fx68k`=68000, …).
- A core is **not** a Quartus project. It is a small set of config files plus
  HDL; `jtcore` (synthesis) and `jtsim` (simulation) call `jtframe` to generate
  everything else. Never commit generated files (`game_sdram.v`,
  `mem_ports.inc`, `.qsf`, `.qip`, `game.f`, `*.mra`, `*.rom`, `*.bin`, …; see
  `.gitignore`).

### Environment

```bash
source setprj.sh           # sets JTROOT, JTFRAME, CORES, MODULES, PATH, MANPATH
jtframe                    # first run builds the Go tool
man jtsim | man jtcore | man jtframe-mem | man jtframe-mra | man jtutil-sdram
```

Also used: `JTBIN` (binary release repo), `ROM` (`$JTROOT/rom`, generated
`.rom` files), `MAME` (zipped ROM sets, for regressions), `JOTEGO` (private
scene/regression data — may not exist for you; don't depend on it silently).
The Pocket submodule (`modules/jtframe/target/pocket`) is private; ignore
init errors for it.

## 2. Anatomy of a core

```
cores/<core>/
  README.md          supported / unsupported games and why
  cfg/
    macros.def       JTFRAME_* and core macros, per-target sections [mister], [mist|sidi]
    files.yaml       HDL file list (may pull from other cores and modules)
    mem.yaml         SDRAM/BRAM buses, clock enables, audio mixing -> generated RTL
    mame2mra.toml    MAME -> MRA/.rom conversion: regions, dipsw, buttons, skips
    mmr.yaml         (optional) memory-mapped register generator
    msg              pause/credits screen text
    reg.yaml         setnames run by the regression flow
    cheat.yaml       (optional) cheats for simulation
  hdl/               jt<core>_*.v  — one module per file, filename == module name
    jt<core>_game.v  top level (GAMETOP); ports come from jtframe_game_ports.inc
  ver/
    game/            full-system sim folder (sim.sh wrapper around jtsim)
    <setname>/       per-set sim folder: *.cab input scripts, scenes
    <unit>/          unit tests: test.v + gather.f + .simunit
  doc/               reference material (MAME driver copies, notes)
  sch/               KiCAD schematics (JTKICAD symbols) when researched
  pal/               PAL/GAL equations
```

Read `modules/jtframe/doc/folders.md`, `jtframe.md`, `sdram.md`,
`jtframe-mem.md`, `jtframe-mra.md`, `macros.md` before non-trivial work.

## 3. Due diligence before writing any HDL

Do this every time, and write down what you found (in the PR/commit message or
the core README). Skipping it is how duplicated chips and wrong cores happen.

1. **Identify the hardware, not the game.** From MAME (`doc/mame.xml`, and the
   driver source `sourcefile=...`) collect: CPUs and clocks, sound chips,
   custom ICs, video resolution/refresh, ROM regions, DIP switches, inputs.
   `jtutil mamedb --dev <device>[,<device>]` filters `doc/mame.xml` by devices.
2. **Is it already supported?** Search every core's MRA config:
   ```bash
   grep -l '<driver>.cpp' cores/*/cfg/mame2mra.toml
   grep -rn '<setname>' cores/*/cfg/mame2mra.toml   # listed, skipped, or promoted?
   ```
   Also check `skip.*` entries and each core's README "not supported" notes —
   a game may be deliberately excluded with a stated reason (see
   `cores/harier/README.md`). Check upstream issues on `jotego/jtcores` for
   "new core" requests and work in progress.
3. **Find the closest existing hardware.** Many drivers share boards or chips.
   Look for:
   - same MAME driver file or a driver that `#include`s the same device headers;
   - same custom chips (Konami `k0xxxxx`, Capcom CPS-A/B, Sega 315-xxxx, Namco
     CUS-xx, Taito TC0xxx, Data East …): `grep -rli '<chip-number>' cores/*/hdl modules/*/hdl`;
   - same CPU/sound combination and similar video pipeline (tilemap count,
     sprite engine, palette format).
4. **Check existing reuse.** Cores already import each other's HDL via
   `files.yaml`, e.g. `harier <- outrun s16`, `s18 <- s16b s16 shanon`,
   `tmnt <- simson aliens riders`, `cps2 <- cps1 cps15`. Reproduce the map:
   ```bash
   for c in cores/*/; do c=$(basename $c); \
     grep -oE '^[a-z0-9_]+:' cores/$c/cfg/files.yaml | tr -d : | grep -vx "$c"; done
   ```
5. **Check JTFRAME before writing a generic block.** `modules/jtframe/hdl/`
   has: `cpu/` (68000, Z80, 6809, 6502, 6801/63701, 6805, 8751, i8742, SH-2,
   T48…), `video/` (vtimer, tilemap, obj scan/draw, linebuf, framebuf, blank,
   PROM colour mixer), `sound/` (FIR, dcrm, mixers, pole/RC, volume),
   `ram/`, `clocking/`, `sdram/`, `keyboard/`, `lightgun/`, `cheat/`.
   `modules/jtframe/cfg/{cpu,video,sdram,sound}/*.yaml` are ready-to-include
   file lists (e.g. `jtframe_m68k.yaml`, `jtframe_z80.yaml`). CPU resource
   costs are in `doc/cpus.md` and `doc/ip.md`.

### Extend an existing core or create a new one?

| Situation | Action |
|---|---|
| Same PCB, extra sets/clones | Add sets to the existing core's `mame2mra.toml`; no HDL change, or small header-driven options. |
| Same board family, variant (different ROM layout, extra chip, protection, memory map tweak) | Extend the existing core. Select behaviour at run time with the **MRA header** (`JTFRAME_HEADER`, `[header]` in `mame2mra.toml`) or at build time with a macro. Prefer the header: one bitstream serves all sets. |
| Different board, but shares custom chips/subsystems | **New core** that imports the shared HDL from the other core via `files.yaml` (as `harier` pulls `jtoutrun_pcm.v` from `outrun`). Don't copy-paste modules. |
| Variant that no longer fits the FPGA / would bloat the original core | New core reusing HDL, or per-target `JTFRAME_SKIP`. Size matters: MiST/SiDi (Cyclone III, ~25k LE) are the tight targets. |
| Genuinely new hardware | New core. |

If a shared module needs to change for your core, keep the change backward
compatible (parameters/defines with the old default) and re-verify every core
that imports it (use the reuse map above). A shared generic block that is
really framework-level belongs in JTFRAME, but changes to JTFRAME affect all
~90 cores — flag that to the user before doing it.

## 4. Creating a new core

Pick a short lowercase folder name (existing names are 2–7 chars, e.g.
`harier`, `taitox`, `cps15`). Module prefix is `jt<core>_`; `CORENAME` in
`macros.def` is `JT<CORE>` uppercase. Copy structure from the most similar
recent core rather than from scratch — `cores/harier` is a good, heavily
commented recent example; `cores/kicker`/`yiear` for small 8-bit boards.

Minimum set:

1. `cfg/macros.def` — `CORENAME`, `JTFRAME_PXLCLK`/`JTFRAME_PLL`,
   `JTFRAME_WIDTH`/`HEIGHT`, `JTFRAME_COLORW`, `JTFRAME_BUTTONS`, `JTFRAME_RATE`,
   bank starts (`JTFRAME_BA1_START`…, core `*_START` offsets),
   `JTFRAME_HEADER` if used, target sections (`[mist|sidi]` → `JTFRAME_SKIP`
   when it won't fit). Inspect with `jtframe cfgstr <core> --target=mister --output=bash`.
2. `cfg/mame2mra.toml` — `[parse] sourcefile`, `main_setnames`, `skip.*` for
   unsupported sets; `[ROM] regions` with `start` macros matching
   `macros.def`, widths, `reverse`, `sequence`; `[dipsw]`, `[buttons]`,
   `[audio]`. Run `jtframe mra <core>` to produce MRAs and `$ROM/<set>.rom`.
3. `cfg/mem.yaml` — SDRAM buses (addr/data width, offsets from the bank
   macros, caches), BRAMs, `clocks:` for clock enables, `audio:` channel
   description (resistor/capacitor values from the schematics). Explicit SDRAM
   module instantiation is deprecated for new cores.
4. `cfg/files.yaml` — own `hdl`, imported cores, jtframe blocks, sound modules.
5. `hdl/jt<core>_game.v` — `include "jtframe_game_ports.inc"`; generated
   memory ports are appended via `/* jtframe mem_ports */`. Instance order:
   game, sub-CPU, sound, video, SDRAM.
6. `cfg/msg`, `README.md`, `cfg/reg.yaml`, `ver/game/sim.sh`.
7. New beta cores: add to `.beta.yaml` (with platforms) and keep
   `JTFRAME_SKIP` consistent — `beta-checks.sh` runs in CI. Use
   `modules/jtframe/doc/debug_list.md` "New Core Check List" to track progress.

## 5. HDL conventions (from `doc/style.md` and existing code)

- One module per file, filename == module name; instances start with `u_`;
  jtframe instances drop the prefix (`jtframe_ram u_ram`). Parameters UPPERCASE.
- Plain Verilog-2005 style dominates (`.v`); SystemVerilog only where already
  used. Must pass Verilator lint and synthesize in Quartus 13.1 (MiST) and 17+
  (MiSTer) — avoid constructs Quartus 13 rejects.
- **Single clock + clock enables.** Everything runs on `clk` (48 MHz, or 96 MHz
  with `JTFRAME_SDRAM96`) with `cen` strobes, preferably generated from
  `mem.yaml` `clocks:`. No derived clocks, no latches. Cross cen/clock domains
  with jtframe synchronisers.
- Signal names: `LHBL`/`LVBL` active-low blanks; `_n` active low; `_l` one
  clock delayed; `nx_` next value; `pre_`/`post_` pipeline points.
- Address buses are byte-referenced: 16-bit data → `addr[N:1]`, 32-bit →
  `addr[N:2]`.
- File header: SPDX GPL-3.0-or-later, authors, date (copy from a recent file).
- Comment **why**, citing the source: schematic sheet/designator, chip pin,
  MAME line. Look at `cores/harier/cfg/mem.yaml` for the expected level of
  justification of hardware constants. Mark any value that is an ear/eye trim
  or deviates from the PCB, and make PCB-deviating options default to off.
- Debug hooks: `debug_bus` in / `debug_view` out, `gfx_en` layer enables
  (F7–F10), `st_addr`/`st_dout` for sys-info. Tie them off cleanly; they
  disappear under `JTFRAME_RELEASE`. See `doc/debug.md`.

## 6. Testing and verification

Accuracy target is the original PCB; MAME is the reference implementation, not
ground truth. Work in this order and don't claim a level you didn't run.

1. **Lint** (fast, always):
   ```bash
   lint-one.sh <core>                 # add -u JTFRAME_SKIP for cores in development
   lint-one.sh <core> -mist           # also check the smallest target if supported
   lint-mra.sh                        # MRA generation for all cores (CI runs it)
   ```
2. **Unit simulations** for new or modified blocks (video chip, DMA, counters,
   sound glue). Folder `cores/<core>/ver/<unit>/` with `test.v` (module `test`,
   include `test_tasks.vh`, call `pass()`/`fail()`), `gather.f` (UUT first),
   and `.simunit`. Run `simunit.sh --run cores/<core>/ver/<unit>`. CI picks up
   every `.simunit` automatically. Examples: `cores/thundr/ver/cenloop`,
   `cores/cps2/ver/raster`. See `doc/simunit.md`.
3. **Full-system simulation** (Verilator via `jtsim`) from `cores/<core>/ver/game`
   or `ver/<setname>`:
   ```bash
   jtframe mra <core>                # generates $ROM/<set>.rom
   jtsim -setname <set> -video 10     # frames -> PNG, audio -> test.wav
   jtsim -setname <set> -w 5 -video 8 # dump waveforms from frame 5
   jtsim <file>.cab                   # scripted inputs (coin, 1p, up, b1, dipsw=…)
   jtsim -d NOMAIN -q -load           # build sdram_bank*.bin fast without CPUs
   ```
   `jtutil sdram <core>` splits a `.rom` into SDRAM bank files when the
   download has no data transformation. Compare frames and audio against MAME
   at the same frame count. For CPU mismatches use `jtutil trace` (MAME CSV
   trace vs VCD) and the techniques in `doc/debug_list.md`.
4. **Regression**: add the set to `cfg/reg.yaml` (optionally `.cab`, dipsw,
   frames). `run_regression.sh` validates against reference frames/audio in
   `$REGRUNS` — references are added manually by a human, never generated to
   make a test pass.
5. **Synthesis**: `jtcore <core> -mister` (and `-mist`/`-sidi`/`-pocket` as
   supported). Check timing (STA) and resource usage. Quartus may not be
   installed in your environment — say so rather than implying it passed.
6. **Hardware test** (human): MiSTer/Pocket, DIP switches, inputs, audio levels,
   service mode. Request it explicitly; you cannot do it.

CI on pull requests (`.github/workflows/pull-request.yaml`): beta checks,
framework tests, Verilator/MRA lint, unit sims, then compile-all for
non-draft PRs.

### Debug checklist (abridged from `doc/debug_list.md`)

- Wrong RAM size, cen applied to wrong domain, missing frame interrupt, level
  interrupts not held long enough, port direction mistakes.
- Counters around LHBL/LVBL edges; flipped counters are discontinuous.
- Colours: `JTFRAME_COLORW`, bit-plane order, palette bank selection.
- Sound: unsigned outputs must go through `jtframe_dcrm`; check interrupts on
  the sound CPU; check for clipping.
- ROM offsets: wrong `*_START` produces full-size garbage, not an empty file —
  verify content (CRC/reset vector) as `cores/harier/ver/game/sim.sh` does.

## 7. Git workflow in this repo

- Commit subject style: `<core>: <what changed>` (e.g.
  `cps3: avoid rendering outside of the visible area`), or conventional
  `feat(jtframe): …` / `fix(sdram): …` for framework changes. Reference issues
  as `Fixes #NNNN`.
- Keep a commit scoped to one core or one framework concern. If a shared
  module changes, say which importing cores were re-linted/re-simulated.
- Submodule changes (`modules/jt*`) belong in their own upstream repos; here
  you only bump the submodule pointer.
- Do not commit ROMs, MAME dumps of copyrighted data, generated MRA/.rom/.bin,
  or build output. Copies of MAME driver source in `cores/<core>/doc` are fine
  (existing practice) for reference.
- This is a fork of `jotego/jtcores`; do not open PRs (here or upstream)
  without the user's explicit approval.

## 8. Agent behaviour rules

- Evidence first: cite schematic, datasheet, MAME source line, or simulation
  output for every hardware claim. If unknown, say so and propose how to
  measure it.
- Don't "fix" documented deliberate values (ear-trimmed gains, PCB-faithful
  bugs defaulting on) without the source that justifies the change.
- Prefer extending generators (`mem.yaml`, `mame2mra.toml`, header bits) over
  hand-written plumbing.
- Report exactly which verification steps ran (lint / simunit / jtsim frames /
  synthesis / hardware) and which did not.
- Keep MiST/SiDi resource limits in mind; if a change pushes a core over, add
  per-target `JTFRAME_SKIP` and update `.beta.yaml`/README rather than
  silently breaking the small targets.
