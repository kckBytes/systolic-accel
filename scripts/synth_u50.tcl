# =============================================================================
# synth_u50.tcl -- non-project, out-of-context synth + place + route of `core`
# on the Alveo U50, with reports written where STATE.md expects them.
#
#   vivado -mode batch -source scripts/synth_u50.tcl -tclargs <part2> <outdir>
#
#   part2  : 0 -> 4-bit x 4-bit config (the simulated / verified one)
#            1 -> 2x2-bit activation SIMD config
#   outdir : where reports go (the .bat passes _build/impl_u50_part<N>)
#
# Reports produced in <outdir>:
#   synth_utilization.rpt          post-synth, flat
#   synth_utilization_hier.rpt     post-synth, per module (tile / array / SRAM)
#   timing_summary_routed.rpt      post-route WNS / TNS / WHS / failing endpoints
#   utilization_routed.rpt         post-route, flat
#   utilization_routed_hier.rpt    post-route, per module
#   summary.txt                    one-line extract for STATE.md
# =============================================================================

set part2  [expr {[llength $argv] > 0 ? [lindex $argv 0] : 0}]
set outdir [expr {[llength $argv] > 1 ? [lindex $argv 1] : "_build/impl_u50_part$part2"}]
set period [expr {[llength $argv] > 2 ? [lindex $argv 2] : 4.000}]
set root   [file normalize [file join [file dirname [info script]] ..]]
set part   xcu50-fsvh2104-2-e
set top    core

file mkdir $outdir
puts "== systolic_accel :: $top :: part2=$part2 :: $part :: period=$period ns :: out=$outdir"

create_project -in_memory -part $part
set_property target_language Verilog [current_project]

# RTL: the canonical set only. rtl_mode/ and rtl/_orig/ are deliberately NOT
# read (glob is not recursive).
foreach f [lsort [glob -directory [file join $root rtl] *.v]] { read_verilog $f }

# Constraints: scripts/constraints/core_u50.xdc is the reference copy at 4.000 ns.
# The period is substituted here so one script covers 4.000 (250 MHz) and
# 3.106 (322 MHz, the venture's clock on the same part). Everything else in the
# XDC is reproduced verbatim.
set xdc [file join $outdir core_u50_${period}ns.xdc]
set fh [open $xdc w]
puts $fh "create_clock -period $period -name clk \[get_ports clk\]"
puts $fh "set_input_delay  -clock clk 1.000 \[get_ports {reset inst\[*\] D_xmem\[*\]}\]"
puts $fh "set_output_delay -clock clk 1.000 \[get_ports {ofifo_valid sfu_out\[*\]}\]"
close $fh
read_xdc $xdc

synth_design -top $top -part $part -mode out_of_context -generic part2=$part2
report_utilization              -file [file join $outdir synth_utilization.rpt]
report_utilization -hierarchical -file [file join $outdir synth_utilization_hier.rpt]

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -max_paths 5 -file [file join $outdir timing_summary_routed.rpt]
report_utilization               -file [file join $outdir utilization_routed.rpt]
report_utilization -hierarchical -file [file join $outdir utilization_routed_hier.rpt]
report_timing -sort_by group -max_paths 3 -path_type full -file [file join $outdir worst_paths_routed.rpt]

# ---- one-line summary --------------------------------------------------------
set wns  [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs  [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
set per  [get_property PERIOD [get_clocks clk]]
set fmax [expr {1000.0 / ($per - $wns)}]
set lut  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == CLB && PRIMITIVE_SUBGROUP == LUT}]]
set ff   [llength [get_cells -hier -filter {PRIMITIVE_GROUP == REGISTER}]]
set bram [llength [get_cells -hier -filter {PRIMITIVE_GROUP == BLOCKRAM}]]
set dsp  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == ARITHMETIC && PRIMITIVE_SUBGROUP == DSP}]]
# one path per endpoint, only those with negative setup slack
set fail [llength [get_timing_paths -max_paths 100000 -nworst 1 -unique_pins -slack_lesser_than 0 -setup]]

set line "top=$top part2=$part2 part=$part period_ns=$per WNS_ns=[format %.3f $wns] WHS_ns=[format %.3f $whs] failing_setup_endpoints=$fail fmax_est_MHz=[format %.1f $fmax] LUT=$lut FF=$ff BRAM=$bram DSP=$dsp"
set fh [open [file join $outdir summary.txt] w]
puts $fh $line
close $fh
puts "== SUMMARY: $line"
