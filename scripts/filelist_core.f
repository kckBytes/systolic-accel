# =============================================================================
# filelist_core.f -- core_tb (xsim). Paths are RELATIVE TO THE PROJECT ROOT;
# scripts\run_sim_core.bat prefixes them with the root at run time and writes
# the absolute list into the build directory, so xvlog can run from there.
# Plain Verilog-2001, no packages. Leaves first, integration, then the TB.
# =============================================================================

# --- storage and FIFOs ---
rtl/sram_32b_w2048.v
rtl/sram_128b_w2048.v
rtl/fifo_depth8.v
rtl/fifo_depth64.v
rtl/fifo_mux_2_1.v
rtl/fifo_mux_8_1.v
rtl/fifo_mux_16_1.v
rtl/ififo.v
rtl/ofifo.v

# --- MAC hierarchy: mac -> mac_tile -> mac_row -> mac_array ---
rtl/mac.v
rtl/mac_tile.v
rtl/mac_row.v
rtl/mac_array.v

# --- post-array ---
rtl/sfu.v

# --- integration ---
rtl/core.v

# --- testbench ---
tb/core_tb.v
