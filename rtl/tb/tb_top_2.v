`timescale 1ns / 1ps
`include "param.v"

// Testbench for top module
module tb_top();

    // Testbench variables
    reg CLK, RSTb;
    wire [`BIT_INSTR-1:0] instr_bus;
    wire pulse_bus;
    // wire o_Flag_Finish_Out;
    // wire o_Valid_WB_Out;
    // wire [`BIT_DATAWB-1:0] o_Data_WB_Out;
    // wire o_Flag_Finish = o_Data_WB_Out[`BIT_DATAWB-1];
    // wire o_Valid = o_Data_WB_Out[`BIT_DATAWB-2];
    // wire [`BIT_PSUM-1:0] o_Data = o_Data_WB_Out[`BIT_PSUM-1:0];
    wire o_Flag_Finish;
    wire o_Valid;
    wire [`BIT_PSUM-1:0] o_Data;
    wire instr_stall;
    wire [`BIT_STATE-1:0]o_state_debug;
    // wire [`PE_COL*`BIT_ADDR-1:0] o_sram_weight_addr_out;
    // wire [`PE_COL*`BIT_DATA-1:0] o_sram_weight_din_out;

    // Clock generation
    initial CLK = 1'b0;
    always #20  CLK <= ~CLK;

    // Testbench
    initial begin
        CLK <= 1'b0;
        RSTb <= 1'b0;
        #200;
        repeat(20)  @(negedge CLK);
        RSTb <= 1'b1;

        repeat(3000)  @(negedge CLK);   
        $finish;  
    end

    // Instantiate top module
    top top (
        .CLK(CLK),
        .RSTb(RSTb),
        .i_Instr_In(instr_bus),
        .instr_stall(instr_stall),
        .o_Flag_Finish_Out(o_Flag_Finish),
        .o_Valid_WB_Out(o_Valid),
        .o_Data_WB_Out(o_Data),
        // .o_state_debug(o_state_debug),
        .i_instr_pulse(pulse_bus)
        // .o_sram_weight_addr_out(o_sram_weight_addr_out),
        // .o_sram_weight_din_out(o_sram_weight_din_out)
    );

    // Instantiate instruction buffer
    instr_buffer instr_buffer (
        .CLK(CLK),
        .RSTb(RSTb),
        .instr_stall(instr_stall),
        .o_Instr(instr_bus),
        .o_instr_pulse(pulse_bus)
    );

endmodule

// Helper module to buffer instructions
module instr_buffer (
    input CLK,
    input RSTb,
    input instr_stall,
    output reg o_instr_pulse,
    output reg [`BIT_INSTR-1:0] o_Instr
    );

    // Variable declarations
    reg [`BIT_INSTR-1:0] Instr[511:0];
    reg [9:0]   Count;

    // Provide instruction every 1 cycle if not stalled
    always @(posedge CLK or negedge RSTb) begin
        if (!RSTb) begin
            Count         <= 10'd0;
            o_Instr       <= {`BIT_INSTR{1'b0}};
            o_instr_pulse <= 1'b0;
        end else begin
            o_instr_pulse <= 1'b0;       // ±âº» 0 (ÆÞ½º ÇÑ »çÀÌÅ¬ Æø À¯Áö)

            if (!instr_stall) begin
                o_Instr       <= Instr[Count];
                Count         <= Count + 10'd1;
                o_instr_pulse <= 1'b1;   // ÀÌ »çÀÌÅ¬¸¸ 1 ¡æ ±ò²ûÇÑ 1Å¬·° ÆÞ½º
            end
        end
    end


    integer k;
    initial begin
        for (k = 0; k < 512; k = k + 1) begin
            Instr[k] = 0;
        end
        // ISA (v1)
        // OPVALID(1) / OPCODE(3) / SEL(4)+ADDR(16) or PARAM(20) / DATA(8): total(32)
        Instr[0]  <= {`OPVALID, `OPCODE_PARAM, `PARAM_S, 8'd4};
        Instr[1]  <= {`OPVALID, `OPCODE_PARAM, `PARAM_OC, 8'd5};
        Instr[2]  <= {`OPVALID, `OPCODE_PARAM, `PARAM_IC, 8'd23};
        // For writeback test (Debug)
        Instr[3]  <= {`OPVALID, `OPCODE_WBPARAM, `PARAM_S, 8'd0};
        Instr[4]  <= {`OPVALID, `OPCODE_WBPARAM, `PARAM_OC, 8'd0};
        Instr[5]  <= {`OPVALID, `OPCODE_WBPARAM, `PARAM_IC, 8'd0};
        // LDSRAM_I (Load Data to SRAM, Input)
        Instr[6] <= {`OPVALID, `OPCODE_PARAM, `PARAM_TRG, `TRG_ISRAM}; // Select target SRAM(Input)

        Instr[7] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd0, -8'd23};
        Instr[8] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd0, 8'd5};

        // LDSRAM_W (Load Data to SRAM, Weight)
        Instr[9] <= {`OPVALID, `OPCODE_PARAM, `PARAM_TRG, `TRG_WSRAM};
        // Bank(4Bit), Address(16Bit), Data(8Bit)
        Instr[10] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd0, 8'd1};
        Instr[11] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd1, 8'd2};
        Instr[12] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd0, 8'd3};
        Instr[13] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd1, 8'd4};

        Instr[14] <= {`OPVALID, `OPCODE_IGNORE_PSUM_BIT, 20'd0, 8'd0}; // Ignore psum bit when outputting data (For testing purpose)

        // Execute
        Instr[15] <= {`OPVALID, `OPCODE_PARAM, `PARAM_BASE_WSRAM, 8'd0}; // Load Weight to Systolic Array and have to specify the base address
        Instr[16] <= {`OPVALID, `OPCODE_EX, 20'd0, 8'd0};
        Instr[17] <= {`OPVALID, `OPCODE_NOP, 20'd0, 8'd0};

        // Writeback (To external host, Outside top module)
        Instr[18] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd0, 8'd0};
        Instr[19] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd1, 16'd0, 8'd0};


        Instr[20] <= {`OPVALID, `OPCODE_NOP, 20'd0, 8'd0};
        
    end
endmodule