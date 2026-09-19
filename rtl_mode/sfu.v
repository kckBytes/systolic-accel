/**
* 1. When acc is sent high, at the posedge reset internal registers and prepare to add things
* 2. At the next clk posedge, you will get the read address from pmem. Read that and add it 
* to the internal sum across the columns
* ...... Step2 will happen 9 times
* 3. The TB will make acc low. At the negedge, we need to output the accumulation
* 4. The output accumulation will be wired through a mux to SRAM and TB will give a write signal to it
**/

/*
    reg [psum_bw - 1:0] after_relu_q [col - 1:0];
    reg [psum_bw - 1:0] current_psum [col - 1:0];
    */

/**
* Assumption is accumulation is set high/low only at nededge
**/
module sfu (clk, reset, acc, D_pmem, after_relu);

    parameter col = 8;
    parameter psum_bw = 16;

    input clk;
    input reset;
    input acc;
    input [col*psum_bw-1:0] D_pmem;
    output [col*psum_bw - 1:0] after_relu;

    reg [col*psum_bw - 1:0] current_psum;
    
    reg [col*psum_bw - 1:0] after_relu_q;
    assign after_relu = after_relu_q;
    
    // Assumption this is happening at clk nededge
    always @ (posedge acc or posedge reset) begin
        // Prepare for accumulations. Reset internal registers
        current_psum <= 0;
        after_relu_q <= 0;
    end
    
    integer i;
    always @ (negedge acc) begin
        for (i = 0; i < col; i = i + 1) begin
            if (current_psum[(i+1) * psum_bw - 1] == 1'b1) begin
                after_relu_q[i * psum_bw +: psum_bw] <= 0;
            end
            else begin
                after_relu_q[i * psum_bw +: psum_bw] <= current_psum[i * psum_bw +: psum_bw];
            end
        end
    end

    always @ (posedge clk) begin
        if (acc) begin
            for (i = 0; i < col; i = i + 1) begin
                current_psum[i * psum_bw +: psum_bw] <= current_psum[i * psum_bw +: psum_bw] + D_pmem[i * psum_bw +: psum_bw];
            end
        end
    end

/*
    CLK -|_|-|_|-|_|-|_|-|

    ACC _|------------------|_________________|
*/

endmodule
