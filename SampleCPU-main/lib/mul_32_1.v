`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/12/13 08:34:11
// Design Name: 
// Module Name: mul_32_1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mul_32_1(
    input wire rst,							
	input wire clk,							
	input wire signed_mul_i,						
	input wire[31:0] opdata1_i,				
	input wire[31:0] opdata2_i,				
	input wire start_i,						///是否开始乘法运算
	input wire annul_i,						//是否取消乘法运算，1位取消
	output reg signed [63:0] result_o,				//乘法运算结果
	output reg ready_o			
    );
    reg [5:0] cnt;							//记录乘法进行了几轮
	
	reg [1:0] state;						//乘法器处于的状态	??	
	
	reg[63:0] mult1_shift;
	reg[31:0] mult2_shift;
	reg[63:0] mult1_acc;
	reg[31:0] neg1;
	reg[31:0] neg2;
	always @ (posedge clk) begin
		if (rst) begin
			state <= 2'b00;
			result_o <= {32'b0,32'b0};
			ready_o <= 1'b0;
		end else begin
			case(state)
			
				2'b00: begin			//空闲
					if (start_i == 1'b1 && annul_i == 1'b0) begin
							state <= 2'b10;					
							cnt <= 6'b000000;
							if(signed_mul_i == 1'b1 && opdata1_i[31] == 1'b1) begin			///负数
								mult1_shift <= {32'b0,(~opdata1_i + 1)};
							end else begin
								mult1_shift <= {32'b0,opdata1_i};
							end
							if (signed_mul_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin			//负数
								mult2_shift <= (~opdata2_i + 1);
							end else begin
								mult2_shift <= opdata2_i;
							end
							begin
							    mult1_acc<=64'b0;
							 end
					   end else begin
						ready_o <= 1'b0;
						result_o <= {32'b0, 32'b0};
					end
				end
//							mult1_acc= 
//							           opdata2_i[0]?{32'b0,opdata1_i}:64'b0;
					
			
				
				2'b10: begin				
					if(annul_i == 1'b0) begin			//进行乘法运算
						if(cnt != 6'b100000) begin
						mult1_acc <=(mult2_shift[0]==1'b1)?(mult1_acc+mult1_shift):mult1_acc;
							mult1_shift<=mult1_shift<<1;
							mult2_shift<=mult2_shift>>1;
							
							cnt <= cnt +1;		//乘法运算次数
						end	else begin
									   state <= 2'b11;
									   cnt <= 6'b000000;
									   end
					end else begin	
						state <= 2'b00;
					end
				end
				
				2'b11: begin			//乘法结束
					result_o <= (((opdata1_i[31] == 1'b1&&opdata2_i[31] == 1'b1)||(opdata1_i[31] == 1'b0&&opdata2_i[31] == 1'b0)&&signed_mul_i == 1'b1)||signed_mul_i == 1'b0)?mult1_acc:(~mult1_acc+1);
					ready_o <= 1'b1;
					if (start_i == 1'b0) begin
						state <= 2'b00;
						ready_o <= 1'b0;
						result_o <= {32'b0, 32'b0};
					end
				end
				
			endcase
		end
	end
endmodule
