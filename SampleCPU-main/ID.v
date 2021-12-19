`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,

    input wire [`WB_TO_RF_WD-1+64+1+2:0] wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1+1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus ,
    
    
    input wire [37+64+1+2:0] ex_to_id_forwarding,
    input wire [37+64+1+2:0] mem_to_id_forwarding,
    output wire stallreq_for_id,
    input wire ex_aluop
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end
    reg stall_flag;//暂存信号
    reg [31:0]inst_reg;//临时存储rdata寄存器
    reg stall_flag1;//暂存信号
    reg [31:0]inst_reg1;//临时存储rdata寄存器
     always @ (posedge clk) begin
        if (stall[2]==`Stop && stall[3]==`NoStop) begin
            inst_reg <= inst_sram_rdata;
            stall_flag <= 1'b1;   
        end
        
        else begin
            inst_reg <= 32'b0;
            stall_flag <= 1'b0;       
        end
    end
    always @ (posedge clk) begin
        if (stall[3]==`Stop && stall[4]==`NoStop && inst_reg1==32'b0) begin
            inst_reg1 <= inst_sram_rdata;
            stall_flag1 <= 1'b1;   
        end
        
        else if(stall[3]==1'b0)begin
            inst_reg1 <= 32'b0;
            stall_flag1 <= 1'b0;       
        end
    end
    assign inst = stall_flag1 ? inst_reg1 :
    stall_flag ? inst_reg :
     inst_sram_rdata ;
    //在mem段传回内存真正的值时，ID段inst不能被改变，否则rs、rt会被篡改，导致mem传回的值没有解决问题，原inst被覆盖。
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    wire [63:0] wb_div_mul_result;
    wire [63:0] mem_div_mul_result;
    wire [63:0] ex_div_mul_result;
     wire  wb_div_mul_flag;
    wire  mem_div_mul_flag;
    wire  ex_div_mul_flag;
    wire  ex_lo_wen;
    wire  wb_lo_wen;
    wire  mem_lo_wen;
    wire  ex_hi_wen;
    wire  wb_hi_wen;
    wire  mem_hi_wen;
    
    assign {
    wb_lo_wen,
    wb_hi_wen,
    wb_div_mul_flag,
     wb_div_mul_result,
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;
    
    
    ////////////////////////
    wire ex_forwarding_we;
    wire [4:0] ex_forwarding_waddr;
    wire [31:0] ex_forwarding_wdata;
    
    wire mem_forwarding_we;
    wire [4:0] mem_forwarding_waddr;
    wire [31:0] mem_forwarding_wdata;
    
    wire [31:0]r1;
    wire [31:0]r2;
    wire ex_lo;
    wire ex_hi;
    wire mem_lo;
    wire mem_hi;
 assign{
    ex_lo_wen,
    ex_hi_wen,
    ex_div_mul_flag,
    ex_div_mul_result,
    ex_forwarding_we,
    ex_forwarding_waddr,
    ex_forwarding_wdata
    }=ex_to_id_forwarding;
 assign{
    mem_lo_wen,
    mem_hi_wen,
    mem_div_mul_flag,
    mem_div_mul_result,
    mem_forwarding_we,
    mem_forwarding_waddr,
    mem_forwarding_wdata
    }=mem_to_id_forwarding;
////////////////////////////////////////////////////////
    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;
   wire[31:0]rr1;
wire [31:0] rr2;
 wire[31:0]lo_r1;
    wire[31:0]hi_r2;
    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
        
    );

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];
    
//reg[31:0]r1,r2;
//wire[31:0]rd1,rd2;
// always @ (posedge clk) begin
//     if(rst)begin
//     r1=32'b 0;
//     end
//       else if ((ex_forwarding_we==1'b1)&&(ex_forwarding_waddr==rs)) begin
//             r1 <= ex_forwarding_wdata;
//        end
//        else if ((mem_forwarding_we==1'b1)&&(mem_forwarding_waddr==rs)) begin
//            r1 <= mem_forwarding_wdata;
//        end
//        else r1=rdata1;
//     end
     
//  always @ (posedge clk) begin
//  if(rst)begin
//     r2=32'b 0;
//     end
//       else if ((ex_forwarding_we==1'b1)&&(ex_forwarding_waddr==rt)) begin
//             r2 <= ex_forwarding_wdata;
//        end
//        else if ((mem_forwarding_we==1'b1)&&(mem_forwarding_waddr==rt)) begin
//            r2 <= mem_forwarding_wdata;
//        end
//        else r2=rdata2;
//    end

assign r1 = (ex_forwarding_we &&(ex_forwarding_waddr==rs))?ex_forwarding_wdata: 
            ((mem_forwarding_we &&(mem_forwarding_waddr==rs))?mem_forwarding_wdata:((wb_rf_we &&(wb_rf_waddr==rs))?wb_rf_wdata : rdata1));
assign r2 = (ex_forwarding_we &&(ex_forwarding_waddr==rt))?ex_forwarding_wdata:
            ((mem_forwarding_we &&(mem_forwarding_waddr==rt))?mem_forwarding_wdata:((wb_rf_we &&(wb_rf_waddr==rt))?wb_rf_wdata : rdata2));
assign stallreq_for_id=(ex_aluop &&((ex_forwarding_waddr==rs)||(ex_forwarding_waddr==rt)))?1'b1:1'b0;
   wire inst_ori, inst_lui, inst_addiu, inst_beq, inst_subu,
         inst_jal, inst_jr, inst_addu, inst_or, inst_sll, inst_lw,
         inst_sw,inst_xor, inst_sltu, inst_bne, inst_slt, inst_slti,
         inst_sltiu, inst_j, inst_add, inst_sub, inst_and, inst_andi,
         inst_nor, inst_xori, inst_sllv, inst_sra, inst_srav, inst_srl,
         inst_srlv,inst_bgez,inst_bgtz,inst_blez,inst_bltz,inst_bltzal,inst_bgezal,inst_jalr,
         inst_mfhi,inst_mflo, inst_mthi, inst_mtlo, inst_div ,inst_divu, inst_lb, inst_lbu,
         inst_lh, inst_lhu, inst_sb, inst_sh;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    
    assign inst_subu    = (op_d[6'b00_0000]&&func_d[6'b10_0011]);
    assign inst_jal     =  op_d[6'b00_0011];
    assign inst_jr      = (op_d[6'b00_0000]&&func_d[6'b00_1000]);
    assign inst_addu    = (op_d[6'b00_0000]&&func_d[6'b10_0001]);
    assign inst_bne     =  op_d[6'b00_0101];
    assign inst_sll     = (op_d[6'b00_0000]&&func_d[6'b00_0000]);
    
    assign inst_or      = (op_d[6'b00_0000]&&func_d[6'b10_0101]);
    assign inst_sw      =  op_d[6'b10_1011];
    assign inst_lw      =  op_d[6'b10_0011];
    assign inst_xor     =  (op_d[6'b00_0000]&&func_d[6'b10_0110]);
    assign inst_sltu    =  (op_d[6'b00_0000]&&func_d[6'b10_1011]);
    assign inst_slt     =  (op_d[6'b00_0000]&&func_d[6'b10_1010]);
    assign inst_slti    =  op_d[6'b00_1010];
    assign inst_sltiu   =  op_d[6'b00_1011];
    assign inst_j       =  op_d[6'b00_0010];
    assign inst_add     =  (op_d[6'b00_0000]&&func_d[6'b10_0000]);
    assign inst_addi    =  op_d[6'b00_1000];
    assign inst_sub     =  (op_d[6'b00_0000]&&func_d[6'b10_0010]);
    assign inst_and     =  (op_d[6'b00_0000]&&func_d[6'b10_0100]);
    assign inst_andi    =  op_d[6'b00_1100];
    assign inst_nor     =  (op_d[6'b00_0000]&&func_d[6'b10_0111]);
    assign inst_xori    =  op_d[6'b00_1110];
    assign inst_sllv    =  (op_d[6'b00_0000]&&func_d[6'b00_0100]);
    assign inst_sra     =  (op_d[6'b00_0000]&&func_d[6'b00_0011]);
    assign inst_srav    =  (op_d[6'b00_0000]&&func_d[6'b00_0111]);
    assign inst_srl     =  (op_d[6'b00_0000]&&func_d[6'b00_0010]);
    assign inst_srlv    =  (op_d[6'b00_0000]&&func_d[6'b00_0110]);
    assign inst_bgez    =  (op_d[6'b00_0001]&&rt_d[5'b00_001]);
    assign inst_bgtz    =  (op_d[6'b00_0111]&&rt_d[5'b00_000]);
    assign inst_blez    =  (op_d[6'b00_0110]&&rt_d[5'b00_000]);
    assign inst_bltz    =  (op_d[6'b00_0001]&&rt_d[5'b00_000]);
    assign inst_bltzal  =  (op_d[6'b00_0001]&&rt_d[5'b10_000]);
    assign inst_bgezal  =  (op_d[6'b00_0001]&&rt_d[5'b10_001]);
    assign inst_jalr    =  (op_d[6'b00_0000]&&rt_d[5'b00_000]&&func_d[6'b00_1001]);
    assign inst_mfhi    =  (op_d[6'b00_0000]&&rs_d[5'b00_000]&&rt_d[5'b00_000]&&func_d[6'b01_0000]);
    assign inst_mflo    =  (op_d[6'b00_0000]&&rs_d[5'b00_000]&&rt_d[5'b00_000]&&func_d[6'b01_0010]);
    assign inst_mthi    =  (op_d[6'b00_0000]&&rt_d[5'b00_000]&&func_d[6'b01_0001]);
    assign inst_mtlo    =  (op_d[6'b00_0000]&&rt_d[5'b00_000]&&func_d[6'b01_0011]);
    assign inst_mult    =  (op_d[6'b00_0000]&&func_d[6'b01_1000]);
    assign inst_div     =  (op_d[6'b00_0000]&&func_d[6'b01_1010]);
    assign inst_divu     =  (op_d[6'b00_0000]&&func_d[6'b01_1011]);
    assign inst_lb     =  op_d[6'b10_0000];
    assign inst_lbu     =  op_d[6'b10_0100];
    assign inst_lh     =  op_d[6'b10_0001];
    assign inst_lhu     =  op_d[6'b10_0101];
    assign inst_sb     =  op_d[6'b10_1000];
    assign inst_sh     =  op_d[6'b10_1001];
    
    // rs to reg1 操作数一有三种可能
    assign sel_alu_src1[0] = inst_ori 
                             |inst_addiu 
                             |inst_subu
                             |inst_jr
                             |inst_addu
                             |inst_or
                             |inst_sw
                             |inst_lw
                             |inst_xor
                             |inst_sltu
                             |inst_slt
                             |inst_slti
                             |inst_sltiu
                             |inst_add
                             |inst_addi
                             |inst_sub
                             |inst_and
                             |inst_andi
                             |inst_nor 
                             |inst_xori
                             |inst_sllv
                             |inst_srav
                             |inst_srlv
                             |inst_mflo
                             |inst_mult
                             |inst_mtlo
                             |inst_mthi
                             |inst_lb
                             |inst_lbu
                             |inst_lh
                             |inst_lhu
                             |inst_sb
                             |inst_sh ;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal|inst_bltzal|inst_bgezal|inst_jalr;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll|inst_sra|inst_srl;

    
    // rt to reg2 操作数二有四种可能
    assign sel_alu_src2[0] = inst_subu
                             |inst_addu
                             |inst_bne
                             |inst_sll
                             |inst_or
                             |inst_xor
                             |inst_sltu
                             |inst_slt
                             |inst_add
                             |inst_sub
                             |inst_and
                             |inst_nor
                             |inst_sllv
                             |inst_sra
                             |inst_srav
                             |inst_srl
                             |inst_srlv
                             |inst_mfhi
                             |inst_mult;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu|inst_sw|inst_lw|inst_slti|inst_sltiu|inst_addi|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh  ;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal|inst_bltzal|inst_bgezal|inst_jalr;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori|inst_andi|inst_xori;

  

    assign op_add = inst_addiu|inst_jal|inst_addu|inst_sw|inst_lw|inst_add|inst_addi|inst_bltzal|inst_bgezal|inst_jalr|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh ;
    assign op_sub = inst_subu|inst_sub;
    assign op_slt = inst_slt|inst_slti ;
    assign op_sltu = inst_sltu|inst_sltiu;
    assign op_and = inst_and|inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori|inst_or;
    assign op_xor = inst_xor|inst_xori;
    assign op_sll = inst_sll|inst_sllv;
    assign op_srl = inst_srl|inst_srlv;
    assign op_sra = inst_sra|inst_srav;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = inst_sw|inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu|inst_sb|inst_sh ;

    // write enable全1为写，全0为读
    assign data_ram_wen = (inst_sw||inst_sb||inst_sh)?4'b1111:
                           (inst_lw||inst_lb||inst_lbu||inst_lh||inst_lhu)?4'b0000:4'b0000;



    // regfile sotre enable，写入信号，写寄存器才触发
    assign rf_we = inst_ori 
                   |inst_lui 
                   | inst_addiu
                   |inst_subu
                   |inst_jal
                   |inst_addu
                   |inst_sll
                   |inst_or
                   |inst_lw
                   |inst_xor
                   |inst_sltu
                   |inst_slt
                   |inst_slti 
                   |inst_sltiu
                   |inst_add
                   |inst_addi
                   |inst_sub
                   |inst_and
                   |inst_andi
                   |inst_nor
                   |inst_xori
                   |inst_sllv
                   |inst_sra
                   |inst_srav
                   |inst_srl
                   |inst_srlv
                   |inst_bltzal
                   |inst_bgezal
                   |inst_jalr
                   |inst_mfhi
                   |inst_mflo
                   |inst_lb
                   |inst_lbu
                   |inst_lh
                   |inst_lhu
                   ;



    // store in [rd] 根据字段进行地址的写入，看写入的是rt还是rd
    assign sel_rf_dst[0] = inst_subu|inst_addu|inst_sll|inst_or|inst_xor|inst_sltu|inst_slt|inst_add|inst_sub|inst_and|inst_nor|inst_sllv|inst_sra|inst_srav|inst_srl|inst_srlv|inst_jalr|inst_mfhi|inst_mflo;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu|inst_lw|inst_slti|inst_sltiu|inst_addi|inst_andi|inst_xori|inst_lb|inst_lbu|inst_lh|inst_lhu ;
    // store in [31]，31号寄存器固定用法，某些跳转指令会将地址传入这里
    assign sel_rf_dst[2] = inst_jal|inst_bltzal|inst_bgezal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0; 

    assign id_to_ex_bus = {
    
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rr1,         // 63:32
        rr2          // 31:0
      
    };

    assign rr1=(inst_mflo||inst_mfhi)?lo_r1:r1;
     assign rr2=(inst_mflo||inst_mfhi)?hi_r2:r2;
    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_neq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;
    assign rs_eq_rt = (r1 == r2);//beq判断，两个寄存器内容是否相同
    assign rs_neq_rt= (r1!= r2);
    assign br_e = (inst_beq & rs_eq_rt)
                 ||inst_jal
                 ||inst_jr
                 ||(inst_bne & rs_neq_rt)
                 ||inst_j
                 ||(inst_bgez&&(r1[31]==1'b0))
                 ||(inst_bgtz&&(r1!=32'b0)&&(r1[31]==1'b0))
                 ||(inst_blez&&((r1[31]!=1'b0)||r1==32'b0))
                 ||(inst_bltz&&(r1[31]!=1'b0))
                 ||(inst_bltzal&&(r1[31]!=1'b0))
                 ||(inst_bgezal&&(r1[31]==1'b0))
                 ||inst_jalr;
    //assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 32'b0;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}) : 
                      inst_jal?({pc_plus_4 [31:28],inst[25:0],2'b00}):
                      inst_jr?(r1):
                      inst_bne?(pc_plus_4+{{14{inst[15]}},{inst[15:0],2'b00}}):
                      inst_j?({pc_plus_4 [31:28],inst[25:0],2'b00}):
                      inst_bgez?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}):
                      inst_bgtz?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}):
                      inst_blez?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}):
                      inst_bltz?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}):
                      inst_bltzal?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}):
                      inst_bgezal?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b00}):
                      inst_jalr?(r1):
                      32'b0;//有疑问
    assign br_bus = {
        br_e,
        br_addr
    };
    
    reg [31:0] HI;
    reg [31:0] LO;
    always @ (posedge clk) begin
        if (wb_div_mul_flag!=1'b0||wb_lo_wen==1'b1) begin
           LO<= wb_div_mul_result[31:0];
      
        end
        if (wb_div_mul_flag!=1'b0||wb_hi_wen==1'b1) begin
         
           HI<= wb_div_mul_result[63:32];
        end
    end
   
   assign lo_r1 = ((ex_div_mul_flag==1'b1||ex_lo_wen==1'b1)&&inst_mflo)?ex_div_mul_result[31:0]:
                ((mem_div_mul_flag==1'b1||mem_lo_wen==1'b1)&&inst_mflo)?mem_div_mul_result[31:0]:
                ((wb_div_mul_flag==1'b1||wb_lo_wen==1'b1)&&inst_mflo)?wb_div_mul_result[31:0] : 
                LO;
   assign hi_r2 =  ((ex_div_mul_flag==1'b1||ex_hi_wen==1'b1)&&inst_mfhi)?ex_div_mul_result[63:32]:
                ((mem_div_mul_flag==1'b1||mem_hi_wen==1'b1)&&inst_mfhi)?mem_div_mul_result[63:32]:
                ((wb_div_mul_flag==1'b1||wb_hi_wen==1'b1)&&inst_mfhi)?wb_div_mul_result[63:32] :
                 HI;
endmodule