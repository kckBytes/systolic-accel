# PROVENANCE — who wrote what

*Built 2026-09-19 from the two repo copies. "Header" means the file carries
`// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department`. That header
is the only authorship evidence on disk; the repo's `.git` history is gone.*

**Answered by Chaitanya 2026-09-19:** team project; "most of the work everyone
did independently"; he did not write the testbenches. So: `tb/` is not his;
the RTL edits and training are his own independent work within the team. The
resume claims the tile, the measured array numbers, and the training — not the
testbench. The `?` cells below stay as a reminder that per-file attribution
inside the team was never recorded.

## rtl/ — canonical (from `284_latest/284FinalProject-sfu_alt/Part2/verilog/`)

| File | Header | What it is | Evidence of editing | Yours / teammate / course |
|---|---|---|---|---|
| `mac.v` | yes | 4b×4b signed multiply + 16b add, combinational | none — matches the `hardware/example/mac.v` shape | course |
| `mac_tile.v` | yes | one PE: two `mac` instances (lsb/msb), two weight regs, `part2` mux | **heavily edited**: `part2` parameter, `b_q_lsb/msb`, `load_ready_q_lsb/msb`, sequential weight load, `(msb<<2)+lsb` recombination | ? |
| `mac_row.v` | yes | 8 tiles west→east | `part2` threaded through; `valid[i-1]` fix (original line commented out) | ? |
| `mac_array.v` | yes | 8 rows north→south, inst pipeline | `part2` threaded through | ? |
| `ififo.v`, `ofifo.v` | yes | L0 / output FIFOs | none seen | course |
| `fifo_depth8.v`, `fifo_depth64.v`, `fifo_mux_*.v` | yes | FIFO primitives | none seen | course |
| `sram_32b_w2048.v`, `sram_128b_w2048.v` | yes | behavioural SRAMs (xmem / pmem) | none seen | course |
| `core.v` | **no** | integration: xmem → L0 → array → OFIFO → pmem → SFU; 34-bit inst decode | original file | ? |
| `sfu.v` | **no** | accumulate over kij + ReLU, synchronous, `acc` edge-detected | original file | ? |

## rtl_mode/ — abandoned branch (from `284FinalProject-main/.../Part1/verilog/`)

| File | Header | What it is | Status |
|---|---|---|---|
| `mac.v` | no | from-scratch: runtime `mode` (0: 4b scalar, 1: 2×2b SIMD), **two psum lanes** `pSumOut0/1` | standalone only |
| `mac_tile.v` | no | from-scratch: `weightStationary`, `weightLoad`, `mode` ports; lane regs | **synthesized alone on Artix-7 2025-12-02 → 59 LUT / 81 FF / 0 DSP** (`docs/`) |
| `mac_row.v` | no | **still instantiates the OLD tile ports** (`in_w/out_e/inst_w/inst_e`) | does not elaborate against this tile |
| `core.v` | no | adds `sram_mux_sel` (inst[34]) and an SFU→pmem write-back mux | never simulated with a passing check |
| `sfu.v` | no | `always @(posedge acc)` / `negedge acc` — event-triggered on a data signal | not synthesizable as written; superseded by `rtl/sfu.v` |

This is the branch the December resume line described ("dataflow switchable
at runtime"). The tile exists; the array around it was never rewired. It is
kept as a record and as the starting point for the WS/OS extension.

## tb/

| File | Header | Notes |
|---|---|---|
| `core_tb.v` | yes | instructor template, **substantially filled in**: L0 load sequencing, kij loop, `l0_read_to_PE_*_delay`, part2 MSB-weight pass, 16-way self-check. `parameter part2 = 1` at top; overridden by `--generic_top` in the .bat |
| `l0_tb.v`, `sram_tb_32.v`, `sram_tb_128.v` | yes | course unit TBs |
| `vectors/part1/` | — | `activation.txt`, `weight_k1..9.txt`, `acc_scan.txt`, **`out.txt` (golden)** |
| `vectors/part2/` | — | `activation.txt` (2-bit packed), `weight_k1..9.txt` (16 rows), `acc_scan.txt`. **No `out.txt`.** |
| `gen/a_scan_gen.py` | — | generates `acc_scan.txt` (pmem address order for the 3×3 kernel over a 6×6 padded map) |

## training/

`[PROJ]4BitVGG.ipynb` (best acc 92.00, test 9198/10000), `[PROJ]2BitVGG.ipynb`
(best acc 89.79, test 8856/10000), both CIFAR-10, `models/vgg_quant.py`,
`models/quant_layer.py`. Authorship unknown from the files.

## docs/

- `ECE284 Project Description_ FA2025-2.pdf` — the assignment. Parts 1–5.
- `README_original_repo.md` — the repo's own README, unchanged.
- `mac_tile_utilization_synth_artix7_2025-12-02.rpt` — the only pre-existing synthesis evidence.
