`include "defines.vh"
module mul_div(
  input wire clk,
  input wire rst,		
  input wire signed_flag, //signed is 1, unsigned is 0
  input wire [31:0] data1,//操作数1（乘数/被除数）
  input wire [31:0] data2,//操作数2（乘数/除数）
  input wire DivOrMul,
  input wire inst_mult,
  input wire inst_multu,
  input wire inst_div,
  input wire inst_divu,
  output wire signed [63:0] mul_result,		
  output wire[63:0] div_result,							
  output wire stallreq_for_ex
    );
    

    
    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg [31:0] mul_opdata1_o;
    reg [31:0] mul_opdata2_o;
    
    reg div_start_o;
    reg mul_start_o;
    
    reg signed_div_o;
    reg signed_mul_o;
    
    reg stallreq_for_div;
    reg stallreq_for_mul;
    
    wire div_ready_i;
    wire mul_ready_i;

    wire [1:0]sel;
    assign sel=(inst_div||inst_divu)?2'b10:
               (inst_mult||inst_multu)?2'b01:
               2'b00;
    assign stallreq_for_ex=(stallreq_for_div||stallreq_for_mul)?1'b1:1'b0;

//mul u_mul(
//    	.clk        (clk            ),
//        .resetn     (~rst          ),
//        .mul_signed (signed_flag     ),
//        .ina        ( mul_opdata1_o   ), // 乘法源操作数1
//        .inb        (  mul_opdata2_o   ), // 乘法源操作数2
//        .result     (mul_result     ) // 乘法结果 64bit
//    );
//    mul_32_1 u_mul_32_1(
//    	.rst          (rst          ),
//        .clk          (clk          ),
//        .signed_mul_i (signed_flag ),
//        .opdata1_i    (mul_opdata1_o    ),
//        .opdata2_i    (mul_opdata2_o    ),
//        .start_i      (mul_start_o      ),
//        .annul_i      (1'b0      ),
//        .result_o     (mul_result     ), 
//        .ready_o      (mul_ready_i      )
//    );
//  always @ (*) begin
//        if (rst) begin
//            stallreq_for_mul = `NoStop;
//            mul_opdata1_o = `ZeroWord;
//            mul_opdata2_o = `ZeroWord;
//            mul_start_o = `DivStop;
//            signed_mul_o = 1'b0;
//        end
//        else begin
//            stallreq_for_mul = `NoStop;
//            mul_opdata1_o = `ZeroWord;
//            mul_opdata2_o = `ZeroWord;
//            mul_start_o = `DivStop;
//            signed_mul_o = 1'b0;
//            case ({inst_mult,inst_multu})
//                2'b10:begin
//                    if (mul_ready_i == `DivResultNotReady) begin
//                        mul_opdata1_o = data1;
//                        mul_opdata2_o = data2;
//                        mul_start_o = `DivStart;
//                        signed_mul_o = 1'b1;
//                        stallreq_for_mul = `Stop;
//                    end
//                    else if (mul_ready_i == `DivResultReady) begin
//                        mul_opdata1_o = data1;
//                        mul_opdata2_o = data2;
//                        mul_start_o = `DivStop;
//                        signed_mul_o = 1'b1;
//                        stallreq_for_mul = `NoStop;
//                    end
//                    else begin
//                        mul_opdata1_o = `ZeroWord;
//                        mul_opdata2_o = `ZeroWord;
//                        mul_start_o = `DivStop;
//                        signed_mul_o = 1'b0;
//                        stallreq_for_mul = `NoStop;
//                    end
//                end
//                2'b01:begin
//                    if (mul_ready_i == `DivResultNotReady) begin
//                        mul_opdata1_o = data1;
//                        mul_opdata2_o = data2;
//                        mul_start_o = `DivStart;
//                        signed_mul_o = 1'b0;
//                        stallreq_for_mul = `Stop;
//                    end
//                    else if (mul_ready_i == `DivResultReady) begin
//                        mul_opdata1_o = data1;
//                        mul_opdata2_o = data2;
//                        mul_start_o = `DivStop;
//                        signed_mul_o = 1'b0;
//                        stallreq_for_mul = `NoStop;
//                    end
//                    else begin
//                        mul_opdata1_o = `ZeroWord;
//                        mul_opdata2_o = `ZeroWord;
//                        mul_start_o = `DivStop;
//                        signed_mul_o = 1'b0;
//                        stallreq_for_mul = `NoStop;
//                    end
//                end
//                default:begin
//                end
//            endcase
//        end
//    end  
assign mul_result=div_result;
 div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_flag ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      ),
        .sel (sel)
    );
    
always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({(inst_div||inst_mult),(inst_divu||inst_multu)})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = data1;
                        div_opdata2_o = data2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = data1;
                        div_opdata2_o = data2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = data1;
                        div_opdata2_o = data2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = data1;
                        div_opdata2_o = data2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end
endmodule