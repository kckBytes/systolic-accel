#!/usr/bin/env python3
"""
repack_part2_weights.py -- make the part2 weight files agree with the activation
packing and with how core_tb.v + mac_tile.v actually consume them.

WHY (found 2026-09-19 by ref_model.py against the RTL's own output)
  The as-found part2 weight_kN.txt has 16 lines x 64 b, line = output channel,
  nibble k = input channel k (k = 15..0). core_tb.v reads each line as two
  32-bit words (hi half first), so xmem[0x400 + 2c] = oc c, ic 15..8 and
  xmem[0x401 + 2c] = oc c, ic 7..0. In part2 mode a tile latches two words in
  sequence: the first into its LSB-lane weight, the second into its MSB-lane
  weight. So tile (row r, col c) ends up with
        b_lsb = w[oc c][ic 8+r],   b_msb = w[oc c][ic r].
  But the activation file packs tile row r's nibble as
        [3:2] = ic 2r+1 (MSB lane),   [1:0] = ic 2r (LSB lane).
  The tile computes a_lsb*b_lsb + a_msb*b_msb = act[2r]*w[8+r] + act[2r+1]*w[r].
  Wrong channels multiplied together.

WHAT THIS DOES
  Rewrites each 64-bit line so that
        hi 32 b, nibble r = w[oc][ic 2r]      (LSB lane, latched first)
        lo 32 b, nibble r = w[oc][ic 2r+1]    (MSB lane, latched second)
  Now tile (r, c) computes act[2r]*w[2r] + act[2r+1]*w[2r+1], and the 8 rows
  together cover all 16 input channels of output channel c.

  The as-found files are copied to tb/vectors/part2_as_found/ first. Nothing
  is deleted.

  Only the first 8 lines (oc 0..7) are consumed by one pass of core_tb.v --
  the array has 8 columns. Lines 8..15 are repacked too, for a future second
  pass, but are not read by the current testbench.
"""
import os, shutil, sys

here = os.path.dirname(os.path.abspath(__file__))
vdir = os.path.join(here, '..', 'vectors', 'part2')
keep = os.path.join(here, '..', 'vectors', 'part2_as_found')

def nib(v, k): return (v >> (4 * k)) & 0xF

def repack_line(line):
    v = int(line, 2)
    hi = 0; lo = 0
    for r in range(8):
        hi |= nib(v, 2 * r)     << (4 * r)   # ic 2r   -> LSB lane
        lo |= nib(v, 2 * r + 1) << (4 * r)   # ic 2r+1 -> MSB lane
    return format((hi << 32) | lo, '064b')

def main():
    os.makedirs(keep, exist_ok=True)
    for k in range(1, 10):
        src = os.path.join(vdir, f'weight_k{k}.txt')
        bak = os.path.join(keep, f'weight_k{k}.txt')
        if not os.path.exists(bak):
            shutil.copy2(src, bak)
        with open(bak) as f:
            raw = [l.rstrip('\n') for l in f]
        out = []
        for l in raw:
            s = l.strip()
            out.append(l if (not s or s.startswith('#')) else repack_line(s))
        with open(src, 'w') as f:
            f.write('\n'.join(out) + '\n')
        print(f'repacked weight_k{k}.txt  (as-found copy in part2_as_found/)')
    # activation.txt and acc_scan.txt are unchanged; copy for completeness
    for name in ('activation.txt', 'acc_scan.txt'):
        b = os.path.join(keep, name)
        if not os.path.exists(b):
            shutil.copy2(os.path.join(vdir, name), b)

if __name__ == '__main__':
    main()
