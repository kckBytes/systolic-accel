# =============================================================================
# core_u50.xdc -- timing-only constraints for an out-of-context build of `core`
# on the Alveo U50 (xcu50-fsvh2104-2-e). No pin constraints: OOC, no I/O.
#
# 4.000 ns = 250 MHz. Chosen as a first target because the venture fabric on
# the same part closes at 322 MHz (3.106 ns) with a pipelined datapath and
# this array's tile has a 4x4 multiply feeding a 16-bit add in one cycle.
# The report tells us the truth either way: if WNS is negative, achievable
# fmax = 1 / (4.000 - WNS).
# =============================================================================
create_clock -period 4.000 -name clk [get_ports clk]

# Inputs/outputs are driven/sampled by the TB in the same clock domain in the
# real system; for OOC give them a nominal half-cycle budget so paths from and
# to the ports are timed rather than ignored.
# (remove_from_collection is not legal inside an XDC, so the inputs are named.
#  Port list from rtl/core.v:7-21 -- clk, reset, inst[33:0], D_xmem[31:0] in;
#  ofifo_valid, sfu_out[127:0] out.)
set_input_delay  -clock clk 1.000 [get_ports {reset inst[*] D_xmem[*]}]
set_output_delay -clock clk 1.000 [get_ports {ofifo_valid sfu_out[*]}]
