# systolic_accel — Multi-Precision Systolic-Array CNN Accelerator

UCSD ECE 284 (VLSI Implementation of ML), Fall 2025. An 8×8 weight-stationary
systolic array with SRAM → L0 FIFO → array → output FIFO → pmem → SFU
(accumulate + ReLU), driven by a 34-bit instruction word from the testbench,
and a quantization-aware VGG16 (CIFAR-10) that produces the 4-bit weights and
activations it consumes.

Reconstituted 2026-09-19 from two diverged repo copies into one buildable tree.
**Read `PROVENANCE.md` before making any claim about who wrote what.**
Current measurements live in `STATE.md`.

## Layout

```
rtl/            canonical RTL (one `part2` parameter selects the configuration)
rtl_mode/       abandoned runtime-`mode` tile branch; record only, never in a filelist
tb/             core_tb.v (self-checking, 16 output maps) + unit TBs
tb/vectors/     part1/ (has golden out.txt)   part2/ (NO golden out.txt)
tb/gen/         a_scan_gen.py  -- pmem address order for the 3x3 kernel walk
training/       [PROJ]4BitVGG.ipynb, [PROJ]2BitVGG.ipynb, models/
scripts/        filelist_core.f, run_sim_core.bat, run_synth_u50.bat, synth_u50.tcl,
                constraints/core_u50.xdc
docs/           assignment PDF, original README, the Dec-2025 Artix-7 tile report
_build/         generated; gitignored
```

## The two configurations

| `part2` | Activation | Weight | What the tile does | Verified |
|---|---|---|---|---|
| 0 | 4-bit | 4-bit | two 2b×4b `mac`s, recombined `(msb<<2)+lsb` = one 4b×4b product | **yes — 16/16** |
| 1 | 2×2-bit SIMD | 4-bit ×2 | two 2b×4b `mac`s with *different* weights, summed into one psum | no golden output on disk |

Both configurations are the same RTL; `part2` is a Verilog parameter threaded
`core → mac_array → mac_row → mac_tile` and overridden at elaboration
(`xelab --generic_top`, `synth_design -generic`).

## How the data moves (one kij step, `part2=0`)

1. TB writes the 6×6 padded activation map (36 words × 32 b = 8 rows × 4 b) into **xmem**.
2. For each of the 9 kernel positions: TB writes 8 weight words to xmem at 0x400, streams them into **L0**, then asserts `load` for 8 cycles — each tile latches its weight as it passes (`b_q_lsb`/`b_q_msb`).
3. TB streams the 36 activation words through L0 with `execute` high; psums flow north→south across 8 rows and emerge from **OFIFO**, which the TB drains into **pmem** at `kij*36 + nij`.
4. Accumulation: for each of the 16 output pixels, the TB reads the 9 pmem addresses from `acc_scan.txt` with `acc` high; **SFU** sums them and applies ReLU; the TB compares against `out.txt`.

## Run

```
scripts\run_sim_core.bat part1      # ~1 min; prints the 16 compare lines
scripts\run_sim_core.bat part2      # runs; compare stage fails by construction
scripts\run_synth_u50.bat 0         # OOC synth + P&R on xcu50-fsvh2104-2-e, ~7 min
scripts\run_synth_u50.bat 1
```

Reports land in `_build\impl_u50_part<N>\`; `summary.txt` is the one-line
extract that `STATE.md` cites.

## What this is not

- Not a runtime-reconfigurable weight-/output-stationary array. That was Part 3
  of the assignment; a tile with the ports exists in `rtl_mode/`, nothing drives them.
- Not MNIST. The training is CIFAR-10.
- Not public. Files carrying the instructor's header are not to be redistributed.
