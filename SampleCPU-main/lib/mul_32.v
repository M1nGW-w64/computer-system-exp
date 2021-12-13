



module mul_32(
    input wire rst,							//澶嶄綅
	input wire clk,							//鏃堕挓
	input wire signed_mul_i,						//鏄惁涓烘湁绗﹀彿闄ゆ硶杩愮畻锛?1浣嶆湁绗﹀彿
	input wire[31:0] opdata1_i,				//琚櫎鏁?
	input wire[31:0] opdata2_i,				//闄ゆ暟
	input wire start_i,						///是否开始乘法运算
	input wire annul_i,						//是否取消乘法运算，1位取消
	output reg signed [63:0] result_o,				//乘法运算结果
	output reg ready_o						//乘法运算是否结束
    );
    
	reg [5:0] cnt;							//记录乘法进行了几轮
	
	reg [1:0] state;						//乘法器处于的状态	??	
	
	reg[63:0] mult1_shift;
	reg[31:0] mult2_shift;
	reg[63:0] mult1_acc;
	reg[1:0]n_or_p;
	reg[31:0] neg1;
	reg[31:0] neg2;
	always @ (posedge clk) begin
		if (rst) begin
			state <= 2'b00;
			result_o <= {32'b0,32'b0};
			ready_o <= 1'b0;
			n_or_p<=2'b00;
		end else begin
			case(state)
			
				2'b00: begin			//空闲
					if (start_i == 1'b1 && annul_i == 1'b0) begin
							state <= 2'b10;					
							cnt <= 6'b000000;
							if(signed_mul_i == 1'b1 && opdata1_i[31] == 1'b1) begin			///负数
								mult1_shift <= {32'b0,(~opdata1_i + 1)}<<1;
								n_or_p[0]<=1'b1;
								neg1=~opdata1_i + 1;
							end else begin
								mult1_shift <= {32'b0,opdata1_i}<<1;
							end
							if (signed_mul_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin			//负数
								mult2_shift <= (~opdata2_i + 1)>>1;
								n_or_p[1]<=1'b1;
								neg2=~opdata2_i + 1;
							end else begin
								mult2_shift <= opdata2_i>>1;
							end
							if(signed_mul_i == 1'b1 &&opdata1_i[31] == 1'b1) begin			///负数
								if (signed_mul_i == 1'b1 &&opdata2_i[31] == 1'b1  ) begin			//负数
								   mult1_acc<=neg2[0]?{32'b0,neg1}:64'b0;
							    end else begin
							       mult1_acc<=opdata2_i[0]?{32'b0,neg1}:64'b0;
							    end
							end else if(signed_mul_i == 1'b1 &&opdata1_i[31] == 1'b0)begin
								if (signed_mul_i == 1'b1 &&opdata2_i[31] == 1'b1  ) begin			//负数
								mult1_acc<=neg2[0]?{32'b0,opdata1_i}:64'b0;
							    end else begin
							    mult1_acc<=opdata2_i[0]?{32'b0,opdata1_i}:64'b0;
							    end
							 end else begin
							    mult1_acc<=opdata2_i[0]?{32'b0,opdata1_i}:64'b0;
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
							mult1_shift<=mult1_shift<<1;
							mult2_shift<=mult2_shift>>1;
							mult1_acc <=(mult2_shift[0]==1'b1)?(mult1_acc+mult1_shift):mult1_acc;
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
					n_or_p<=2'b00;
					if (start_i == 1'b0) begin
						state <= 2'b00;
						ready_o <= 1'b0;
						result_o <= {32'b0, 32'b0};
						n_or_p<=2'b00;
					end
				end
				
			endcase
		end
	end

    
endmodule
