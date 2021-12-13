`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1+64+1+2+4:0] ex_to_mem_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    
    
     output wire [37+64+1+2:0] ex_to_id_forwarding,
     output wire stallreq_for_ex,
     output wire ex_aluop//判断是否是load指令
);

    reg [`ID_TO_EX_WD-1+64+1+2:0] id_to_ex_bus_r;
    reg stallreq_for_div_r;
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    wire inst_div, inst_divu;
    wire inst_mtlo,inst_mthi;
    wire lo_wen;
    wire hi_wen;
    assign {
    
        ex_pc,          // 148:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );
   assign inst_mtlo=((inst[31:26] == 6'b000000) && (inst[5:0] == 6'b010011)&&(inst[20:6]==15'b0)) ? 1'b1 : 1'b0 ;
   assign inst_mthi=((inst[31:26] == 6'b000000) && (inst[5:0] == 6'b010001)&&(inst[20:6]==15'b0)) ? 1'b1 : 1'b0 ;
    assign ex_result =((inst[31:16]==16'b0)&&(inst[5:0]==6'b010010))?rf_rdata1:
                       ((inst[31:16]==16'b0)&&(inst[5:0]==6'b010000))?rf_rdata2:
                              alu_result;

 //assign ex_result =alu_result;
  wire[3:0] load_select;
assign load_select=(inst[31:26]==6'b100011)?4'b0000://LW
                    (inst[31:26]==6'b100000)?4'b1001://有符号LB
                    (inst[31:26]==6'b100100)?4'b0001://无符号LBU
                    (inst[31:26]==6'b100001)?4'b1011://LH
                    (inst[31:26]==6'b100101)?4'b0011://LHU
                    4'b0000;
wire [31:0] store_select;
assign store_select=(inst[31:26]==6'b101011&&data_ram_wen==4'b1111)?4'b1111://SW
                    (inst[31:26]==6'b101000&&data_ram_wen==4'b1111&&ex_result[1:0]==2'b00)?4'b0001://SB
                    (inst[31:26]==6'b101000&&data_ram_wen==4'b1111&&ex_result[1:0]==2'b01)?4'b0010://SB
                    (inst[31:26]==6'b101000&&data_ram_wen==4'b1111&&ex_result[1:0]==2'b10)?4'b0100://SB
                    (inst[31:26]==6'b101000&&data_ram_wen==4'b1111&&ex_result[1:0]==2'b11)?4'b1000://SB
                    (inst[31:26]==6'b101001&&data_ram_wen==4'b1111&&ex_result[1:0]==2'b10)?4'b1100://SH
                    (inst[31:26]==6'b101001&&data_ram_wen==4'b1111&&ex_result[1:0]==2'b00)?4'b0011://SH
                    4'b0000; 
wire [31:0] store_data;
assign store_data=(inst[31:26]==6'b101011)?rf_rdata2:
                   (ex_result[1:0]==2'b00&&inst[31:26]==6'b101000)?{4{rf_rdata2[7:0]}}:
                   (ex_result[1:0]==2'b01&&inst[31:26]==6'b101000)?{4{rf_rdata2[7:0]}}:
                   (ex_result[1:0]==2'b10&&inst[31:26]==6'b101000)?{4{rf_rdata2[7:0]}}:
                   (ex_result[1:0]==2'b11&&inst[31:26]==6'b101000)?{4{rf_rdata2[7:0]}}:
                   (ex_result[1:0]==2'b00&&inst[31:26]==6'b101001)?{2{rf_rdata2[15:0]}}:
                   (ex_result[1:0]==2'b10&&inst[31:26]==6'b101001)?{2{rf_rdata2[15:0]}}:
                   rf_rdata2;
    assign ex_aluop=(data_ram_en&&(data_ram_wen==4'b0000))?1'b1:1'b0;
    assign data_sram_addr =ex_result ;
    assign data_sram_en =data_ram_en ;
    assign data_sram_wen =store_select ;
    assign data_sram_wdata =store_data;
    
    
    
    wire DivOrMul;
    wire [63:0] mul_result;
    wire [63:0] div_result;
    wire inst_mult;
    wire inst_multu;
    wire [31:0]data1;
    wire [31:0]data2;
    wire signed_flag;
   assign inst_mult = ((inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011000)&&(inst[15:6]==10'b0)) ? 1'b1 : 1'b0 ;
   assign inst_multu = (inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011001)&&(inst[15:6]==10'b0) ? 1'b1 : 1'b0 ;
   assign inst_div = (inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011010) ? 1'b1 : 1'b0 ;
   assign inst_divu = (inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011011) ? 1'b1 : 1'b0 ;
   assign DivOrMul=(inst_div||inst_divu)?1'b1:(inst_mult||inst_multu)?1'b0:1'b0;
   assign data1=DivOrMul?rf_rdata1:alu_src1;
   assign data2=DivOrMul?rf_rdata2:alu_src2;
   assign signed_flag=(inst_div||inst_mult)?1'b1:(inst_divu||inst_multu)?1'b0:1'b0;        
       
 mul_div u_mul_div(
        .clk          (clk          ),
    	.rst          (rst          ),
        .signed_flag (signed_flag ),
        .data1    (data1    ),
        .data2    (data2    ),
        .DivOrMul      (DivOrMul      ),
        .inst_mult(inst_mult),
        .inst_multu(inst_multu),
        .inst_div(inst_div),
        .inst_divu(inst_divu),
        .mul_result      (mul_result      ),
        .div_result     (div_result     ), // 除法结果 64bit
        .stallreq_for_ex      (stallreq_for_ex      )
    );

    wire inst_div_or_divu_or_mul;
    assign inst_div_or_divu_or_mul =(inst_div||inst_divu)||(inst_mult||inst_multu);
    wire [63:0]div_mul_result;
    assign div_mul_result=(inst_div||inst_divu)?div_result:
                           (inst_mult||inst_multu)?mul_result:
                           (inst_mtlo)?{32'b0, rf_rdata1}:
                           (inst_mthi)?{ rf_rdata1,32'b0}:
                           64'b0;
//  assign lo_wen=(inst_div||inst_divu||inst_mult||inst_multu)?1'b1:
//                   inst_mtlo?1'b1:1'b0;
//   assign hi_wen=(inst_div||inst_divu||inst_mult||inst_multu)?1'b1:
//                   inst_mthi?1'b1:1'b0;
assign lo_wen=inst_mtlo?1'b1:1'b0;
assign hi_wen=inst_mthi?1'b1:1'b0;

    assign ex_to_mem_bus = {
         load_select,
         lo_wen,
         hi_wen,
         inst_div_or_divu_or_mul,
          div_mul_result,
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    
 
    
    assign ex_to_id_forwarding = {
     lo_wen,
         hi_wen,
        inst_div_or_divu_or_mul,
         div_mul_result,
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
endmodule