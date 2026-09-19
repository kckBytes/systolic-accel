module mac #(
    parameter bw      = 4,    // incoming container width (4 bits)
    parameter psum_bw = 16,   // psum width
    parameter lane_bw = 2     // width of each SIMD lane in 2-bit mode
  )(
    output reg signed [psum_bw-1:0] pSumOut0,  // psum lane 0
    output reg signed [psum_bw-1:0] pSumOut1,  // psum lane 1 (unused in scalar mode)

    input        [bw-1:0]       activationIn,     // 4-bit container from west
    input signed [bw-1:0]       weightLane0,    // weight for lane 0 (and scalar mode)
    input signed [bw-1:0]       weightLane1,    // weight for lane 1 (SIMD mode)
    input signed [psum_bw-1:0]  pSumIn0,    // incoming psum lane 0
    input signed [psum_bw-1:0]  pSumIn1,    // incoming psum lane 1
    input                       mode,   // 0: 4-bit scalar, 1: 2x2-bit SIMD
    input clk, reset
  );

  // SCALAR (4 BIT PATH):
  wire signed [2*bw:0] productScalar;
  wire signed [bw:0] a_pad;

  assign a_pad = {1'b0, activationIn}; // force to be unsigned number
  assign productScalar = a_pad * weightLane0;

  wire [psum_bw-1:0] pSumOutScalar;
  assign pSumOutScalar = productScalar + pSumIn0; //only 0th lane's psum is needed
  ///////////////////////////////////////////////////////

  // SIMD
  wire [lane_bw-1:0] activationInLane0;
  wire [lane_bw-1:0] activationInLane1;
  assign activationInLane0 = activationIn [lane_bw-1:0];               // activationIn[1:0]
  assign activationInLane1 = activationIn [2*lane_bw-1:lane_bw];       // activationIn[3:2]

  wire signed [bw:0] a0_pad;
  wire signed [bw:0] a1_pad;
  assign a0_pad = {{(bw-lane_bw+1){1'b0}}, activationInLane0};
  assign a1_pad = {{(bw-lane_bw+1){1'b0}}, activationInLane1};


  wire signed [2*bw:0] productSIMD0, productSIMD1;
  assign productSIMD0 = a0_pad * weightLane0;
  assign productSIMD1 = a1_pad * weightLane1;

  wire signed [psum_bw-1:0] pSumSIMD0;
  wire signed [psum_bw-1:0] pSumSIMD1;

  assign pSumSIMD0 = productSIMD0 + pSumIn0;
  assign pSumSIMD1 =  productSIMD1 + pSumIn1;

  //////////////////

  // Final partial sum output based on mode-control-signal
  always @(posedge clk)
  begin
    if (reset)
    begin
      pSumOut0 <=0;
      pSumOut1 <=0;
    end
    else if (mode)
    begin
      pSumOut0 <= pSumSIMD0;
      pSumOut1 <= pSumSIMD1;
    end
    else
    begin
      pSumOut0 <= pSumOutScalar;
      pSumOut1 <= pSumIn1;
    end
  end





endmodule
