// fifo_depth64.v -- 64-deep FIFO, storage in distributed RAM (LUTRAM).
//
// 2026-09-19 reimplementation. The as-found version (rtl/_orig/fifo_depth64.v,
// course framework) held the 64 entries in 64 named registers and read them
// through a 16:1 -> 2:1 -> 2:1 mux tree. Post-route on xcu50 that cost
// 166 LUT + 270 FF per 4-bit instance and ~338 LUT + ~1040 FF per 16-bit
// instance; the two FIFO banks were 43% of the design's LUTs and 69% of its
// flops while the 64-tile MAC array was 30% / 12%.
//
// Same ports, same parameters, same pointer arithmetic, same flags, same
// write-when-full quirk (data lands, pointer holds), same asynchronous read.
// Only the storage changed: an array with a combinational read, which Vivado
// maps to RAM64M/RAM64X1S distributed RAM on UltraScale+. The read path is
// one LUT deep instead of three mux levels.
//
// Verified 16/16 on both configurations after the change (STATE.md).

module fifo_depth64 (rd_clk, wr_clk, in, out, rd, wr, o_full, o_empty, reset);

  parameter bw = 4;
  parameter simd = 1;       // kept for interface compatibility
  parameter lrf_depth = 1;  // kept for interface compatibility

  input  rd_clk;
  input  wr_clk;
  input  rd;
  input  wr;
  input  reset;
  output o_full;
  output o_empty;
  input  [simd*bw-1:0] in;
  output [simd*bw-1:0] out;

  reg [6:0] rd_ptr = 7'b0000000;
  reg [6:0] wr_ptr = 7'b0000000;

  (* ram_style = "distributed" *)
  reg [simd*bw-1:0] mem [0:63];

  wire empty = (wr_ptr == rd_ptr);
  wire full  = (wr_ptr[5:0] == rd_ptr[5:0]) && (wr_ptr[6] != rd_ptr[6]);

  assign o_full  = full;
  assign o_empty = empty;

  // asynchronous read, as before: `out` follows rd_ptr combinationally
  assign out = mem[rd_ptr[5:0]];

  always @ (posedge rd_clk) begin
    if (reset)
      rd_ptr <= 7'b0000000;
    else if (rd && !empty)
      rd_ptr <= rd_ptr + 1;
  end

  always @ (posedge wr_clk) begin
    if (reset)
      wr_ptr <= 7'b0000000;
    else if (wr && !full)
      wr_ptr <= wr_ptr + 1;
  end

  // storage has no reset (neither did the registers); write lands whenever
  // wr is high and reset is not, exactly as the original case statement did
  // (it sat in the non-reset branch)
  always @ (posedge wr_clk) begin
    if (!reset && wr)
      mem[wr_ptr[5:0]] <= in;
  end

endmodule
