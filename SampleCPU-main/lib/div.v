`include "defines.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/06/25 13:51:28
// Design Name: 
// Module Name: div
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


module div(
	input wire rst,							//复位
	input wire clk,							//时钟
	input wire signed_div_i,						//是否为有符号除法运算�?1位有符号
	input wire[31:0] opdata1_i,				//被除�?
	input wire[31:0] opdata2_i,				//除数
	input wire start_i,						///�Ƿ�ʼ��������
	input wire annul_i,						//�Ƿ�ȡ���������㣬1λȡ��
	output reg[63:0] result_o,				//����������
	output reg ready_o,						//���������Ƿ����
	input wire [1:0]sel
);
	
	wire [32:0] div_temp;
	reg [5:0] cnt;							//��¼���̷������˼���
	reg[64:0] dividend;						//��32λ����������м�������k�ε���������ʱ��dividend[k:0]����ľ��ǵ�ǰ�õ����м�����
											//dividend[31:k+1]������Ǳ�����û�в�������Ĳ��֣�dividend[63:32]��ÿ�ε���ʱ�ı�����
	reg [1:0] state;						//���������ڵ�״̬	??	
	reg[31:0] divisor;
	reg[63:0] emp_op1;
	reg[31:0] temp_op1;//shift1
	reg[31:0] temp_op2;//shift2
	reg[63:0] mult1_acc;
	assign div_temp = {1'b0, dividend[63: 32]} - {1'b0, divisor};
	
	
	always @ (posedge clk) begin
		if (rst) begin
			state <= `DivFree;
			result_o <= {`ZeroWord,`ZeroWord};
			ready_o <= `DivResultNotReady;
		end else begin
			case(state)
			
				`DivFree: begin			//����������
					if (start_i == `DivStart && annul_i == 1'b0) begin
						if(opdata2_i == `ZeroWord&&sel==2'b10) begin			///�������Ϊ0
							state <= `DivByZero;
						end else begin
							state <= `DivOn;					//������Ϊ0
							cnt <= 6'b000000;
							if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin			///������Ϊ����
								temp_op1 = ~opdata1_i + 1;
								emp_op1 = {32'b0,~opdata1_i + 1};
							end else begin
							    emp_op1 ={32'b0,opdata1_i};
								temp_op1 = opdata1_i;
							end
							if (signed_div_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin			//����Ϊ����
								temp_op2 = ~opdata2_i + 1;
							end else begin
								temp_op2 = opdata2_i;
							end
							mult1_acc <=64'b0;
							
							if(sel==2'b10)begin
							dividend <= {`ZeroWord, `ZeroWord};
							dividend[32: 1] <= temp_op1;
							divisor <= temp_op2;
							end
							
						end
					end else begin
						ready_o <= `DivResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
				`DivByZero: begin			//����Ϊ0
					dividend <= {`ZeroWord, `ZeroWord};
					state <= `DivEnd;
				end
				
				`DivOn: begin				//������Ϊ0
					if(annul_i == 1'b0) begin			//���г�������
						if(cnt != 6'b100000&&sel==2'b10) begin
							if (div_temp[32] == 1'b1) begin
								dividend <= {dividend[63:0],1'b0};
							end else begin
								dividend <= {div_temp[31:0],dividend[31:0], 1'b1};
							end
							cnt <= cnt +1;		//�����������
						end	else if(sel==2'b10) begin
							if ((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
								dividend[31:0] <= (~dividend[31:0] + 1);
							end
							if ((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin
								dividend[64:33] <= (~dividend[64:33] + 1);
							end
							state <= `DivEnd;
							cnt <= 6'b000000;
						end
						if(cnt != 6'b100000&&sel==2'b01) begin
						    mult1_acc <=(temp_op2[0]==1'b1)?(mult1_acc+emp_op1):mult1_acc;
							emp_op1<={emp_op1[62:0],1'b0};
							temp_op2<={1'b0,temp_op2[31:1]};
//							 mult1_acc <=(temp_op2[0]==1'b1)?(mult1_acc+emp_op1):mult1_acc;
							cnt <= cnt +1;		//�˷��������
						end	else if(sel==2'b01) begin
						    state <= 2'b11;
						    cnt <= 6'b000000;
						end
					   
					end else begin	
						state <= `DivFree;
					end
				end
				
				`DivEnd: begin			//��������
					result_o <= (sel==2'b10)?{dividend[64:33], dividend[31:0]}:
					            (sel==2'b01)?(((opdata1_i[31] == 1'b1&&opdata2_i[31] == 1'b1)||(opdata1_i[31] == 1'b0&&opdata2_i[31] == 1'b0)&&signed_div_i == 1'b1)||signed_div_i == 1'b0)?mult1_acc:(~mult1_acc+1):64'b0;
					ready_o <= `DivResultReady;
					if (start_i == `DivStop) begin
						state <= `DivFree;
						ready_o <= `DivResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
			endcase
		end
	end


endmodule