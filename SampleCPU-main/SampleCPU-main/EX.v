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
     output wire ex_aluop//�ж��Ƿ���loadָ��
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
    
    assign ex_aluop=(data_ram_en&&(data_ram_wen==4'b0000))?1'b1:1'b0;
    assign data_sram_addr =ex_result ;
    assign data_sram_en =data_ram_en ;
    assign data_sram_wen =data_ram_wen ;
    assign data_sram_wdata =rf_rdata2;
    
    
     // MUL part
    wire [63:0] mul_result;
    wire mul_signed; // �з��ų˷����
    wire inst_mult;
    wire inst_multu;
   assign inst_mult = ((inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011000)&&(inst[15:6]==10'b0)) ? 1'b1 : 1'b0 ;
   assign inst_multu = (inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011001)&&(inst[15:6]==10'b0) ? 1'b1 : 1'b0 ;
   assign mul_signed=inst_mult?1'b1:1'b0;
    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        (  alu_src1    ), // �˷�Դ������1
        .inb        (  alu_src2    ), // �˷�Դ������2
        .result     (mul_result     ) // �˷���� 64bit
    );

    // DIV part
    wire [63:0] div_result;
   
    wire div_ready_i;
    reg stallreq_for_div;
    assign stallreq_for_ex = stallreq_for_div;
    assign inst_div = (inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011010) ? 1'b1 : 1'b0 ;
   assign inst_divu = (inst[31:26] == 6'b000000) && (inst[5:0] == 6'b011011) ? 1'b1 : 1'b0 ;
    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

 
    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // ������� 64bit
        .ready_o      (div_ready_i      )
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
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
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
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
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

    // mul_result �� div_result ����ֱ��ʹ��
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
wire[3:0] load_select;
assign load_select=(inst[31:26]==6'b100011)?4'b0000://LW
                    (inst[31:26]==6'b100000)?4'b1001://�з���LB
                    (inst[31:26]==6'b100100)?4'b0001://�޷���LBU
                    (inst[31:26]==6'b100001)?4'b1011://LH
                    (inst[31:26]==6'b100101)?4'b0011://LHU
                    4'b0000;
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