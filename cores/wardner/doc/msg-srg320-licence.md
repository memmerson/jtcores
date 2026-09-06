# Draft: licence request to srg320

**Where:** open as an issue on https://github.com/srg320/TMS320C1X
**Title:** Would you consider adding a licence to this repository?

---

Hi,

I'm looking at bringing up Toaplan's TMS320C10-based boards (Wardner / Twin Cobra /
Flying Shark) as a core in jotego's jtcores framework. Those boards need a working
TMS320C10 — the DSP drives enemy fire, collisions and sprite placement directly in the
main CPU's RAM, so it can't be stubbed.

While tracing the existing FPGA implementations I found that the `TMS320C1X.sv` and
`TMS320C1X_pkg.sv` used in va7deo's Demon's World core are yours: the `_pkg.sv` there
is byte-identical to this repository, and the main file differs only by the port
changes needed to move the ROM and RAM outside the module. It's clearly the origin.

This repository has no `LICENSE` file and the source files carry no licence header.
va7deo's repository is under GPL-2.0, but a downstream repository can't grant rights
to code it doesn't own, so as far as I can tell there is currently no licence on this
core at all. That makes it unusable in jtcores, which is GPL-3.0-or-later.

Would you be willing to add a licence? Any of these would work for jtcores:

- GPL-3.0-or-later (matches jtcores directly), or
- GPL-2.0-or-later (compatible via the "or later" clause), or
- a permissive licence such as MIT or BSD-2-Clause.

Bare GPL-2.0-only unfortunately would not be compatible.

If you do, I'd credit you as the author in the module header and in the core's
README, and I'd be happy to send back any fixes found while verifying it against
MAME's `tms320c1x` trace output.

If you'd rather not, no problem — I'll write an independent implementation. I'd just
rather ask than assume.

Thanks for the work on this. The BSMT2000 heritage (`rom_file = "bsmt2000.mif"`)
was a nice find.

Marc
