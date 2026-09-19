#!/usr/bin/env python3
"""
ref_model.py -- independent reference model for the systolic_accel core_tb flow.

WHAT IT IS
  A second implementation of the math the RTL performs, written from the
  assignment (docs/ECE284 Project Description_ FA2025-2.pdf) and the vector
  file headers -- NOT from mac_tile.v. It reads the same activation.txt and
  weight_k1..9.txt the testbench reads, computes the expected 16 output
  words, and writes out.txt in the format core_tb.v compares against.

  Two independent implementations agreeing is evidence. The RTL agreeing
  with a checker derived from the RTL is not.

THE MATH (one 3x3 conv layer, stride 1, on a 6x6 zero-padded map -> 4x4)
  out[oc][opix] = ReLU( sum_{kij=0..8} sum_{ic} act[ic][nij(opix,kij)] * w[kij][oc][ic] )
  with 16-bit two's-complement wrap on the accumulator (the hardware psum is
  16 bits; overflow is NOT saturated, it wraps -- exactly like the RTL).

FILE FORMATS (from the three comment lines at the top of each file)
  activation.txt : 36 lines x 32 b.  line t = nij t (row-major over 6x6).
                   bits [31:28] = channel 7 ... bits [3:0] = channel 0.
                   part1: 4-bit unsigned codes, 8 channels.
                   part2: 2-bit unsigned codes, 16 channels, two per nibble
                          (nibble k holds channels 2k+1 in [3:2] and 2k in [1:0]).
  weight_kN.txt  : one line per output channel (column).
                   part1: 8 lines x 32 b, bits [31:28] = ic 7 ... [3:0] = ic 0, 4-bit signed.
                   part2: 16 lines x 64 b, bits [63:60] = ic 15 ... [3:0] = ic 0, 4-bit signed.
  out.txt        : 16 lines x 128 b. line = opix (row-major over 4x4).
                   bits [127:112] = oc 7 ... [15:0] = oc 0, 16-bit two's complement.
  acc_scan.txt   : 144 lines = 16 opix x 9 kij, pmem address kij*36 + nij.
                   Regenerated here from the same rule as tb/gen/a_scan_gen.py
                   and cross-checked against the file on disk.

USAGE
  python ref_model.py part1            # validate against existing out.txt
  python ref_model.py part2 --write    # generate out.txt for part2
  python ref_model.py part1 --write    # overwrite part1 out.txt (only if it matched)
"""
import sys, os, argparse
import numpy as np

NIJ_LEN, ONIJ_LEN, KSZ = 6, 4, 3
PAD = (NIJ_LEN - ONIJ_LEN) // 2                      # 1
DIRS = [(dr, dc) for dr in (-1, 0, 1) for dc in (-1, 0, 1)]   # kij order, row-major

def read_data_lines(path):
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip()]
    return [l for l in lines if not l.startswith('#')]

def to_signed(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v

def parse_activations(path, act_bits, n_ic):
    """returns act[nij][ic] as ints"""
    lines = read_data_lines(path)
    assert len(lines) == NIJ_LEN * NIJ_LEN, f'{path}: expected 36 data lines, got {len(lines)}'
    act = np.zeros((NIJ_LEN * NIJ_LEN, n_ic), dtype=np.int64)
    for t, line in enumerate(lines):
        v = int(line, 2)
        for ic in range(n_ic):
            act[t, ic] = (v >> (act_bits * ic)) & ((1 << act_bits) - 1)
    return act

def parse_weights(dirpath, w_bits, n_ic, n_oc):
    """returns w[kij][oc][ic] as signed ints"""
    w = np.zeros((KSZ * KSZ, n_oc, n_ic), dtype=np.int64)
    for kij in range(KSZ * KSZ):
        lines = read_data_lines(os.path.join(dirpath, f'weight_k{kij+1}.txt'))
        assert len(lines) == n_oc, f'weight_k{kij+1}: expected {n_oc} lines, got {len(lines)}'
        for oc, line in enumerate(lines):
            v = int(line, 2)
            for ic in range(n_ic):
                w[kij, oc, ic] = to_signed((v >> (w_bits * ic)) & ((1 << w_bits) - 1), w_bits)
    return w

def acc_scan_addresses():
    """[opix][kij] -> pmem address, same rule as a_scan_gen.py"""
    addr = []
    for r in range(PAD, NIJ_LEN - PAD):
        for c in range(PAD, NIJ_LEN - PAD):
            row = []
            for (dr, dc) in DIRS:
                nij = (r + dr) * NIJ_LEN + (c + dc)
                kij = DIRS.index((dr, dc))
                row.append(kij * (NIJ_LEN * NIJ_LEN) + nij)
            addr.append(row)
    return np.array(addr, dtype=np.int64)

def conv_reference(act, w, psum_bits=16):
    """out[opix][oc] with 16-bit wrap, then ReLU. Pure integer math."""
    n_opix = ONIJ_LEN * ONIJ_LEN
    n_oc = w.shape[1]
    out = np.zeros((n_opix, n_oc), dtype=np.int64)
    addr = acc_scan_addresses()
    mask = (1 << psum_bits) - 1
    for opix in range(n_opix):
        for oc in range(n_oc):
            acc = 0
            for kij in range(KSZ * KSZ):
                nij = addr[opix, kij] - kij * (NIJ_LEN * NIJ_LEN)
                # the array's psum for (kij, nij): dot over input channels
                psum = int(np.dot(act[nij], w[kij, oc]))
                acc += psum
            acc &= mask                                   # 16-bit wrap
            out[opix, oc] = 0 if (acc >> (psum_bits - 1)) & 1 else acc   # ReLU on sign bit
    return out

def format_out(out, n_oc, psum_bits=16):
    lines = []
    for opix in range(out.shape[0]):
        v = 0
        for oc in range(n_oc):
            v |= (int(out[opix, oc]) & ((1 << psum_bits) - 1)) << (psum_bits * oc)
        lines.append(format(v, f'0{psum_bits * n_oc}b'))
    return lines

CFG = {
    # n_oc_out: output channels the TB compares (one pass of an 8-column array).
    # w_src: for part2 the math reads the AS-FOUND weights (nibble k = ic k);
    #        the repacked files in part2/ are the RTL's view of the same numbers.
    'part1': dict(act_bits=4, n_ic=8,  n_oc=8,  n_oc_out=8, w_bits=4, w_src='part1'),
    'part2': dict(act_bits=2, n_ic=16, n_oc=16, n_oc_out=8, w_bits=4, w_src='part2_as_found'),
}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cfg', choices=CFG)
    ap.add_argument('--write', action='store_true', help='write out.txt (and acc_scan.txt)')
    ap.add_argument('--vectors', default=None, help='vector dir (default tb/vectors/<cfg>)')
    a = ap.parse_args()
    c = CFG[a.cfg]
    here = os.path.dirname(os.path.abspath(__file__))
    vdir = a.vectors or os.path.join(here, '..', 'vectors', a.cfg)

    wdir = os.path.join(here, '..', 'vectors', c['w_src'])
    if not os.path.isdir(wdir):
        wdir = vdir            # as-found copy not made yet: files are still canonical
    act = parse_activations(os.path.join(vdir, 'activation.txt'), c['act_bits'], c['n_ic'])
    w   = parse_weights(wdir, c['w_bits'], c['n_ic'], c['n_oc'])
    print(f'[{a.cfg}] act {act.shape} codes in [{act.min()},{act.max()}]  w {w.shape} in [{w.min()},{w.max()}]  (weights read from {os.path.basename(os.path.normpath(wdir))})')

    # cross-check acc_scan against the file on disk
    addr = acc_scan_addresses()
    disk = [int(l, 2) for l in read_data_lines(os.path.join(vdir, 'acc_scan.txt'))]
    assert disk == addr.flatten().tolist(), 'acc_scan.txt on disk differs from the rule in a_scan_gen.py'
    print(f'[{a.cfg}] acc_scan.txt: 144 addresses match the generator rule')

    out = conv_reference(act, w)
    lines = format_out(out[:, :c['n_oc_out']], c['n_oc_out'])
    print(f'[{a.cfg}] out: {out.shape}, max psum {out.max()}, nonzero {np.count_nonzero(out)}/{out.size}; writing oc 0..{c["n_oc_out"]-1}')

    out_path = os.path.join(vdir, 'out.txt')
    if os.path.exists(out_path):
        disk_lines = read_data_lines(out_path)
        n_match = sum(1 for i in range(min(len(lines), len(disk_lines))) if lines[i] == disk_lines[i])
        print(f'[{a.cfg}] existing out.txt: {n_match}/{len(disk_lines)} lines identical to model')
        if n_match != len(disk_lines):
            for i in range(len(disk_lines)):
                if lines[i] != disk_lines[i]:
                    print(f'   first mismatch at opix {i}')
                    print(f'   model: {lines[i]}')
                    print(f'   disk : {disk_lines[i]}')
                    break
            if a.write:
                print('   --write refused: model does not reproduce the existing file'); sys.exit(1)
    else:
        print(f'[{a.cfg}] no out.txt on disk')

    if a.write:
        with open(out_path, 'w') as f:
            f.write('#time0row7[msb-lsb],time0row6[msb-lst],....,time0row0[msb-lst]#\n')
            f.write('#time1row7[msb-lsb],time1row6[msb-lst],....,time1row0[msb-lst]#\n')
            f.write('#................#\n')
            f.write('\n'.join(lines) + '\n')
        print(f'[{a.cfg}] wrote {out_path}')

if __name__ == '__main__':
    main()
