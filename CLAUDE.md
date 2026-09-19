# CLAUDE.md — systolic_accel

Inherits the workspace root rules. Adds:

## What this is
The ECE 284 (UCSD, Fall 2025) systolic-array CNN accelerator, reconstituted
from two half-diverged copies of the course repo into one buildable tree.
Course framework + the team's tile, SFU, integration and training work
(team project, members worked independently — see PROVENANCE.md).

## Project-specific rules
- **Provenance is load-bearing.** Every RTL file is marked in `PROVENANCE.md`
  as course-framework, edited-framework, or original. A resume or interview
  claim about this project must match that table. Files carrying the
  "Created by prof. Mingu Kang" header are the instructor's; do not strip it.
- **Do not redistribute the course framework.** The header says so. This tree
  stays private; nothing from `rtl/` goes to a public repo without the
  instructor's files removed or permission obtained.
- **`rtl/` is canonical; `rtl_mode/` is a record.** `rtl_mode/` holds the
  abandoned runtime-`mode` tile branch. It does not elaborate as an array
  (`mac_row.v` there has the old port list). Never add it to a filelist.
- **Two build configurations, one parameter.** `part2=0` is 4-bit × 4-bit;
  `part2=1` is 2×2-bit SIMD. Both verified 16/16 against `tb/gen/ref_model.py`.
- **Numbers on the resume come from `_build/` reports via `STATE.md`.** Never
  from memory, never from the Artix-7 tile-only report in `docs/` unless the
  line says Artix-7 and tile-only.
- **No absolute paths in anything committed.** Scripts derive the project root
  from their own location (`%~dp0`, `[info script]`, `$PSScriptRoot`).

## Run
```
scripts\run_sim_core.bat part1        # xsim, self-checking, ~1 min
scripts\run_sim_core.bat part2
scripts\run_synth_u50.bat 0 4.000     # OOC synth+P&R on xcu50, reports in _build\impl_u50_part0_4.000ns
scripts\run_synth_u50.bat 0 3.106     # same at 322 MHz
python tb\gen\ref_model.py part1      # reference model; --write regenerates out.txt
```
