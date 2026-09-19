module mac_tile (clk, reset, mode, weightLoad,
                   weightStationary, pSumIn0, pSumIn1, activationIn,
                   weightLaneIn0, weightLaneIn1, pSumOut0, pSumOut1,
                   activationOut, weightLaneOut0, weightLaneOut1);
  parameter bw      = 4;     // incoming container width (4 bits)
  parameter psum_bw = 16;    // psum width
  parameter lane_bw = 2;     // width of each SIMD lane in 2-bit mode

  input  [psum_bw-1:0] pSumIn0, pSumIn1;
  output  [psum_bw-1:0] pSumOut0, pSumOut1;
  input  [bw-1:0] weightLaneIn0, weightLaneIn1, activationIn;
  output [bw-1:0] weightLaneOut0, weightLaneOut1;
  output reg [bw-1:0] activationOut;
  //  input  [1:0] inst_w; // inst[1]:execute, inst[0]: kernel loading
  //  output [1:0] inst_e;
  input clk;
  input reset;
  input mode;
  input weightStationary;
  input weightLoad;

  // Holding 2 different weights for 2-4 reconfigurable
  reg [bw-1:0] weightLaneReg0, weightLaneReg1;
  reg [bw-1:0] weightLane0_c, weightLane1_c;

  // weightLoad =1 ->holding the weight in local reg; if 0->pass to the east
  always @(*)
  begin
    if (weightStationary && weightLoad)
    begin
      weightLane0_c = weightLaneIn0;
      weightLane1_c = weightLaneIn1;
    end
    else if (weightStationary && ! weightLoad)
    begin
      weightLane0_c = weightLaneReg0;
      weightLane1_c = weightLaneReg1;
    end
    else
    begin
      weightLane0_c = weightLaneIn0;
      weightLane1_c = weightLaneIn1;
    end
  end

  always @(posedge clk )
  begin
    if (reset)
    begin
      weightLaneReg0 <=0;
      weightLaneReg1 <=0;
    end
    // else if (weightLoad)
    // begin
    //   weightLaneReg0 <=weightLane0_c;
    //   weightLaneReg1 <=weightLane1_c;
    // end
    else
    begin
      weightLaneReg0 <=weightLane0_c;
      weightLaneReg1 <=weightLane1_c;
    end

  end

  // traverse the weight input to east when local weight_reg is already loaded, else traverses 0
  // this saperate weight load will need a control in the mac_row using a variable of size 'number of columns', but helps with reconfigurable Weight & Output stationary part
  assign weightLaneOut0 = (! weightLoad || weightStationary) ? weightLaneIn0 : 0;
  assign weightLaneOut1 = (! weightLoad || weightStationary) ? weightLaneIn1 : 0;


  // reg level for mac instance:
  wire [psum_bw-1:0] pSumOut0_c, pSumOut1_c;
  reg [bw-1:0] activationReg; // to sync activation input with the weight loading into the mac.v
  always @(posedge clk )
  begin
    activationReg <=activationIn;
  end
  reg modeReg;
  always @(posedge clk)
  begin
    modeReg<=mode;
  end
  reg [psum_bw-1:0] pSumIn0Reg, pSumIn1Reg ;
  always @(posedge clk)
  begin
    pSumIn0Reg <=pSumIn0;
    pSumIn1Reg <=pSumIn1;
  end
  // mac.v instance
  mac #(bw,psum_bw,lane_bw) mac_instance(
        .pSumOut0(pSumOut0_c),  // psum lane 0
        .pSumOut1(pSumOut1_c),  // psum lane 1 (unused in scalar mode)
        .activationIn(activationReg),
        .weightLane0(weightLaneReg0),
        .weightLane1(weightLaneReg1),
        .pSumIn0(pSumIn0Reg),
        .pSumIn1(pSumIn1Reg),
        .mode(modeReg),
        .clk(clk),
        .reset(reset)
      );

  // activation pipe going to east from west
  always @(posedge clk )
  begin
    if (reset)
    begin
      activationOut <=0;
    end
    else
    begin
      activationOut <= activationReg;
    end
  end

  //outputing partial sums each clock cycle to south from north
  assign pSumOut0 = pSumOut0_c;
  assign pSumOut1 = pSumOut1_c;
  // always @(posedge clk )
  // begin
  //   if (reset)
  //   begin
  //     pSumOut0 <= 0;
  //     pSumOut1 <= 0;
  //   end
  //   else
  //   begin
  //     pSumOut0 <= pSumOut0_c;
  //     pSumOut1 <= pSumOut1_c;
  //   end
  // end

endmodule
