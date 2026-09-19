# STATE — systolic_accel

*Every number here has a file path. If a number is not here, it has not been
measured. Resume lines cite this file.*

## CURRENT STATE — 2026-09-19 (evening: FIFOs in LUTRAM)

**Headline, routed on xcu50 at 4.000 ns, `part2=0`, after `rtl/fifo_depth64.v`
was reimplemented with distributed-RAM storage** (`_build/impl_u50_part0_4.000ns/`):

| | Before (register-file FIFOs) | After (LUTRAM FIFOs) |
|---|---|---|
| CLB LUTs | 6,252 | **2,623** (2,399 logic + 224 as memory) |
| CLB Registers | 12,125 | **1,864** |
| `ofifo_instance` | 2,703 LUT / 8,325 FF | 273 LUT / 112 FF |
| `l0_instance` | 1,328 LUT / 2,168 FF | 177 LUT / 120 FF |
| `mac_array_instance` | 1,879 LUT / 1,481 FF | 1,831 LUT / 1,481 FF (**70%** of LUTs) |
| WNS / failing endpoints | +0.655 ns / 0 of 25,514 | **+0.443 ns / 0 of 6,699** |
| WHS | +0.047 | +0.023 |
| BRAM / URAM / DSP | 2 / 2 / 0 | 2 / 2 / 0 |
| Worst path | URAM → SFU add, 3.272 ns | URAM → SFU add, 3.484 ns (unchanged structure) |

Both configurations re-verified **16/16** after the change (`_build/sim_part1`,
`_build/sim_part2`). Before-run reports kept in `_build/impl_u50_part0_before_lutram/`.

**And at 3.106 ns (322 MHz, the venture's clock on the same part) it closes**
(`_build/impl_u50_part0_3.106ns/`): **WNS +0.041 ns, WHS +0.018, 0 failing of
6,699 endpoints; 2,676 CLB LUTs (2,452 logic + 224 memory), 1,864 FF, 2 BRAM,
2 URAM, 0 DSP.** Worst path is still URAM → SFU add (2.992 ns, 77% logic); the
router got it under by 41 ps with the FIFO mux trees gone. Item 3 below (pipeline
the URAM read) is now margin, not necessity.

### The table below is the pre-LUTRAM build, kept for the record

| Item | Value | Source |
|---|---|---|
| Simulation, `part2=0` | **16 / 16 output feature maps match; "No error detected"** | `_build/sim_part1/log_xsim.txt` |
| Simulation, `part2=1` | **16 / 16 output feature maps match; "No error detected"** — as of 2026-09-19 evening, after the fix below. Before it: no `out.txt` existed and the run produced a wrong answer for reasons that were not the RTL's. | `_build/sim_part2/log_xsim.txt` |
| Reference model | `tb/gen/ref_model.py` — independent NumPy conv, written from the spec + file headers. Reproduces part1's pre-existing `out.txt` **16/16 lines identical**, then generated part2's. | `tb/gen/ref_model.py` |
| Target | `xcu50-fsvh2104-2-e` (Alveo U50), Vivado 2025.2, out-of-context | `scripts/synth_u50.tcl` |
| Clock constraint | 4.000 ns (250 MHz), inputs/outputs timed at 1.0 ns | `scripts/constraints/core_u50.xdc` |
| **WNS / TNS** | **+0.655 ns / 0.000**, 0 failing of 25,514 setup endpoints | `_build/impl_u50_part0/timing_summary_routed.rpt:142` |
| WHS | +0.047 ns, 0 failing hold endpoints | same line |
| Estimated fmax | **~299 MHz** (= 1 / (4.000 − 0.655)); the design was not re-run at that period, so "estimated" | `summary.txt` |
| **CLB LUTs** | **6,252** | `_build/impl_u50_part0/utilization_routed.rpt` |
| **CLB Registers** | **12,125** | same |
| CARRY8 | 136 | same |
| Block RAM | 2 × RAMB36 (xmem, 32b × 2048) | same |
| URAM | 2 × URAM288 (pmem, 128b × 2048) | same |
| DSP | **0** — the 5b × 4b products are LUT-mapped | same |
| Worst setup path | `pmem_instance/memory_reg_uram_0/CLK` → `sfu_instance/current_psum_reg[76]/D`: 3.272 ns, **77% logic** (URAM clock-to-out + 16-bit add through 2 × CARRY8), 4 levels. Paths 2 and 3 are the same URAM → SFU structure. | `timing_summary_routed.rpt:205-214` |

### Where the area goes (routed, `utilization_routed_hier.rpt`)

| Block | LUT | FF | Share of LUT | Share of FF |
|---|---|---|---|---|
| `mac_array_instance` (64 tiles) | 1,879 | 1,481 | 30% | 12% |
| `ofifo_instance` (8 × `fifo_depth64` × 16 b, register file) | **2,703** | **8,325** | **43%** | **69%** |
| `l0_instance` (8 × `fifo_depth64` × 4 b, register file) | 1,328 | 2,168 | 21% | 18% |
| `sfu_instance` | 312 | 129 | 5% | 1% |

The compute is a third of the LUTs and an eighth of the flops. The two
register-file FIFOs are the rest.

### FIND-SA-01 — part2 was never verifiable, and why (closed 2026-09-19)

Diagnosed by putting the model's answer next to the RTL's own printed
`core_out` and testing hypotheses until one reproduced the RTL **exactly**
(columns 0, 3–7 exact; 1–2 off by one pixel from load skew). The RTL was
computing precisely what it was fed. Two things fed it wrong:

1. **`core_tb.v` load loop drained 8 L0 words in part2; 16 were written.**
   The leftover 8 weight words became the first 8 "activations" of the
   execute phase — the whole 6×6 map shifted by 8 positions. Fix: loop bound
   `col` → `(part2+1)*col` (two places, marked in the file).
2. **Weight file and activation file disagreed on lane pairing.** The
   activation nibble for tile row r holds channels `{2r+1, 2r}`; the 64-bit
   weight line, read as two 32-bit halves, put channels `{r, 8+r}` into the
   same tile. Each tile multiplied an activation by another channel's weight.
   Fix: `tb/gen/repack_part2_weights.py` rewrites the weight files so the
   halves carry `{2r}` and `{2r+1}`. As-found files kept in
   `tb/vectors/part2_as_found/`; the model reads those (canonical channel
   order) and the RTL reads the repacked ones (its view of the same numbers).

Neither is an RTL defect. Both are exactly the kind of thing the symmetric
trap hides: a testbench written from the same understanding as the vectors
agrees with itself. The model was written from the assignment PDF and the
file headers instead, and disagreed.

What the check covers now: one pass = **8 of the 16 output channels**
(8-column array). Lines 8–15 of the weight files are repacked but unread.
A second pass with a separate pmem region is the natural next step.

### Earlier runs, kept for the record

- `_build/impl_u50_part0/run1_inputs_untimed/` — same flow, but the XDC's
  `set_input_delay` line was rejected by Vivado (`remove_from_collection` is
  not legal in an XDC), so input-port paths were untimed. WNS +0.603, 6,253 LUT.
  Superseded by the run above; kept because it was the first.
- `docs/mac_tile_utilization_synth_artix7_2025-12-02.rpt` — the **only**
  pre-existing synthesis evidence: `rtl_mode/mac_tile.v` alone, `xc7a200tfbg676-2`,
  59 LUT / 81 FF / 0 DSP. Different tile, different part, tile-only. Not comparable.

### Training (unchanged, `training/`)

| Notebook | Dataset | Result | Source line |
|---|---|---|---|
| `[PROJ]4BitVGG.ipynb` | CIFAR-10 | best acc **92.00**, test 9198/10000 | notebook output cells |
| `[PROJ]2BitVGG.ipynb` | CIFAR-10 | best acc **89.79**, test 8856/10000 | notebook output cells |

---

## WHAT THE RESUME MAY SAY (as of this build)

- 8×8 weight-stationary systolic array; SRAM → L0 → array → OFIFO → pmem → SFU
- multi-precision MAC tile: 4-bit, or 2×2-bit SIMD, selected by a build parameter
  (*not* "runtime" — that branch never integrated; see `rtl_mode/`)
- simulated 16/16 against an independent NumPy reference, **both** the 4-bit and the 2×2-bit SIMD config
- the reference model found two testbench/vector defects the RTL had been hiding (FIND-SA-01)
- **Alveo U50, Vivado 2025.2: WNS +0.655 ns at 4.0 ns, 0 failing endpoints, 6,252 LUT, 12,125 FF, 2 BRAM, 2 URAM, 0 DSP**
- VGG16 on CIFAR-10: 92.0% (4-bit W/A), 89.8% (2-bit activations)

Not until measured: anything at 3.106 ns / 322 MHz; anything about `part2=1`
being correct; anything about weight-/output-stationary switching.

---

## NEXT — what more can be done, in the order that pays

Each item is something an interviewer can ask "and then what happened?" about.

1. ~~**Close `part2=1` verification.**~~ **DONE 2026-09-19** — see FIND-SA-01.
   Follow-on: a second pass for output channels 8–15 (weight lines 8–15,
   pmem offset), so the check covers the whole 16→16 layer.

2. ~~**Move the FIFOs out of flops.**~~ **DONE 2026-09-19** — 6,252 → 2,623 LUT,
   12,125 → 1,864 FF, 16/16 on both configs. See the headline table.

3. **Pipeline the URAM read.** The worst path is URAM → 16-bit add → FF.
   Vivado already warned it could not pipeline `pmem` because of the read-address
   register. One output register on `sram_128b_w2048` (and an `acc` delay of
   one cycle in the SFU) moves the limiter into the array. Then re-run at
   3.106 ns to see whether it closes at the venture's 322 MHz on the same part.

4. **Finish Part 3 — weight-/output-stationary reconfigurable dataflow.**
   `rtl_mode/mac_tile.v` has the ports (`weightStationary`, `weightLoad`);
   `rtl_mode/mac_row.v` still wires the old tile. Rewire row/array/core for
   the new tile, add an `inst` bit for the dataflow, and write the OS control
   sequence in the TB. This is the one line the December resume claimed and
   the files do not support. Making it true is worth more than any other item.

5. **Use the DSPs.** 0 of 5,952 DSP48E2 are used; the multiplies are in
   LUTs. Forcing `(* use_dsp = "yes" *)` on `mac` — or packing two 4b×4b
   products into one 27×18 multiplier — trades LUTs for DSPs and likely
   shortens the tile path. A second timing/area point on the same design.

6. **cocotb testbench.** Replace the fixed-vector `core_tb.v` with a Python
   testbench that generates random 6×6 maps and 3×3 kernels, drives the
   same instruction sequence, and checks against the NumPy model from (1).
   This is the "Python verification" half of what HRT's FPGA posting asks
   for, on a design that is already yours.

7. **Scale the layer.** The TB runs one 8-in / 8-out channel slice of one
   conv layer. Tiling a full VGG16 conv layer (e.g. 64 → 64 channels over a
   32×32 map) through the same core, with the host-side loop in Python,
   turns "a systolic array" into "an accelerator that ran a layer."

## OPEN — needs Chaitanya, not files

- **Authorship.** `PROVENANCE.md` last column. Was this a team project? Which
  files are yours: the tile edits, `core.v`, `sfu.v`, the TB sequencing, the
  training notebooks? The resume line stays generic ("built the tile, SFU and
  integration") until answered.
- **Which config was submitted?** `part2=1`'s TB is set as default
  (`parameter part2 = 1`) but had no golden output on disk. Was Part 2 graded
  on the waveform, or did an `out.txt` exist somewhere off-disk? (If one did,
  it would have failed — see FIND-SA-01.)
