`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1+64+1+2+4:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,

    output wire [`MEM_TO_WB_WD-1+64+1+2:0] mem_to_wb_bus,
    
    
    output wire [37+64+1+2:0] mem_to_id_forwarding
);

    reg [`EX_TO_MEM_WD-1+64+1+2+4:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;
    wire [63:0] div_mul_result;
    wire inst_div_or_divu_or_mul;
    wire lo_wen;
    wire hi_wen;
    wire[3:0] load_select;
    assign {
    load_select,
     lo_wen,
         hi_wen,
    inst_div_or_divu_or_mul,
      div_mul_result,
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;
    wire [31:0]load_deal;
    assign load_deal= (load_select==4'b0000)?data_sram_rdata:
                       (load_select==4'b1001&&ex_result[1:0]==2'b00)?{{24{data_sram_rdata[7]}},data_sram_rdata[7:0]}:
                       (load_select==4'b1001&&ex_result[1:0]==2'b01)?{{24{data_sram_rdata[15]}},data_sram_rdata[15:8]}:
                       (load_select==4'b1001&&ex_result[1:0]==2'b10)?{{24{data_sram_rdata[23]}},data_sram_rdata[23:16]}:
                       (load_select==4'b1001&&ex_result[1:0]==2'b11)?{{24{data_sram_rdata[31]}},data_sram_rdata[31:24]}:
                         (load_select==4'b0001&&ex_result[1:0]==2'b00)?{24'b0,data_sram_rdata[7:0]}:
                         (load_select==4'b0001&&ex_result[1:0]==2'b01)?{24'b0,data_sram_rdata[15:8]}:
                         (load_select==4'b0001&&ex_result[1:0]==2'b10)?{24'b0,data_sram_rdata[23:16]}:
                         (load_select==4'b0001&&ex_result[1:0]==2'b11)?{24'b0,data_sram_rdata[31:24]}:
                           (load_select==4'b0011&&ex_result[1:0]==2'b00)?{16'b0,data_sram_rdata[15:0]}:
                           (load_select==4'b0011&&ex_result[1:0]==2'b10)?{16'b0,data_sram_rdata[31:16]}:
                             (load_select==4'b1011&&ex_result[1:0]==2'b00)?{{16{data_sram_rdata[15]}},data_sram_rdata[15:0]}:
                             (load_select==4'b1011&&ex_result[1:0]==2'b10)?{{16{data_sram_rdata[31]}},data_sram_rdata[31:16]}:
                               data_sram_rdata;

    assign rf_wdata = (data_ram_wen==4'b0000&&data_ram_en==1'b1)?load_deal:sel_rf_res ? mem_result : ex_result;
//    assign rf_wdata = sel_rf_res ? mem_result : ex_result;
    assign mem_to_wb_bus = {
     lo_wen,
         hi_wen,
    inst_div_or_divu_or_mul,
       div_mul_result,
        mem_pc,     // 41:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };
    
    
assign mem_to_id_forwarding = {
 lo_wen,
         hi_wen,
        inst_div_or_divu_or_mul,
        div_mul_result,
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };



endmodule