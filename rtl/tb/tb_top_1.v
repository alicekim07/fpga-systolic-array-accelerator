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
        .o_state_debug(o_state_debug),
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
            o_instr_pulse <= 1'b0;       // 기본 0 (펄스 한 사이클 폭 유지)

            if (!instr_stall) begin
                o_Instr       <= Instr[Count];
                Count         <= Count + 10'd1;
                o_instr_pulse <= 1'b1;   // 이 사이클만 1 → 깔끔한 1클럭 펄스
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
        // Address = 0
        Instr[7] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd0, -8'd112};
        Instr[8] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd0, -8'd117};
        Instr[9] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd0, 8'd101};
        Instr[10] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd0, 8'd124};
        Instr[11] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd0, 8'd28};
        Instr[12] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd0, 8'd53};
        Instr[13] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd0, -8'd2};
        Instr[14] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd0, 8'd62};
        // Address = 4
        Instr[15] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd4, 8'd26};
        Instr[16] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd4, 8'd124};
        Instr[17] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd4, 8'd100};
        Instr[18] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd4, 8'd110};
        Instr[19] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd4, -8'd17};
        Instr[20] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd4, 8'd37};
        Instr[21] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd4, 8'd22};
        Instr[22] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd4, -8'd13};
        // Address = 8
        Instr[23] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd8, -8'd73};
        Instr[24] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd8, 8'd3};
        Instr[25] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd8, 8'd125};
        Instr[26] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd8, 8'd84};
        Instr[27] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd8, -8'd88};
        Instr[28] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd8, 8'd81};
        Instr[29] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd8, 8'd79};
        // Address = 1
        Instr[30] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd1, 8'd105};
        Instr[31] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd1, -8'd58};
        Instr[32] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd1, -8'd120};
        Instr[33] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd1, -8'd36};
        Instr[34] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd1, 8'd5};
        Instr[35] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd1, -8'd122};
        Instr[36] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd1, 8'd108};
        Instr[37] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd1, -8'd57};
        // Address = 5
        Instr[38] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd5, 8'd97};
        Instr[39] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd5, 8'd8};
        Instr[40] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd5, -8'd6};
        Instr[41] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd5, -8'd112};
        Instr[42] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd5, 8'd84};
        Instr[43] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd5, -8'd79};
        Instr[44] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd5, 8'd16};
        Instr[45] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd5, 8'd115};
        // Address = 9
        Instr[46] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd9, 8'd82};
        Instr[47] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd9, 8'd57};
        Instr[48] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd9, -8'd27};
        Instr[49] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd9, 8'd15};
        Instr[50] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd9, 8'd4};
        Instr[51] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd9, -8'd95};
        Instr[52] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd9, 8'd46};
        // Address = 2
        Instr[53] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd2, -8'd97};
        Instr[54] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd2, -8'd57};
        Instr[55] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd2, 8'd10};
        Instr[56] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd2, -8'd40};
        Instr[57] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd2, -8'd66};
        Instr[58] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd2, 8'd65};
        Instr[59] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd2, -8'd109};
        Instr[60] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd2, -8'd55};

        Instr[61] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd6, 8'd43};
        Instr[62] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd6, 8'd61};
        Instr[63] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd6, -8'd89};
        Instr[64] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd6, -8'd66};
        Instr[65] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd6, 8'd91};
        Instr[66] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd6, -8'd109};
        Instr[67] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd6, -8'd65};
        Instr[68] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd6, -8'd65};

        Instr[69] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd10, -8'd13};
        Instr[70] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd10, 8'd118};
        Instr[71] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd10, -8'd106};
        Instr[72] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd10, 8'd86};
        Instr[73] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd10, -8'd54};
        Instr[74] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd10, -8'd65};
        Instr[75] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd10, -8'd94};
        // Address = 3
        Instr[76] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd3, -8'd23};
        Instr[77] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd3, -8'd93};
        Instr[78] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd3, -8'd67};
        Instr[79] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd3, -8'd2};
        Instr[80] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd3, 8'd84};
        Instr[81] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd3, 8'd87};
        Instr[82] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd3, -8'd78};
        Instr[83] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd3, -8'd64};

        Instr[84] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd7, 8'd84};
        Instr[85] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd7, 8'd48};
        Instr[86] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd7, 8'd122};
        Instr[87] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd7, 8'd58};
        Instr[88] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd7, -8'd78};
        Instr[89] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd7, -8'd104};
        Instr[90] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd7, 8'd50};
        Instr[91] <= {`OPVALID, `OPCODE_LDSRAM, 4'd7, 16'd7, -8'd11};

        Instr[92] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd11, 8'd126};
        Instr[93] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd11, -8'd41};
        Instr[94] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd11, -8'd113};
        Instr[95] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd11, 8'd12};
        Instr[96] <= {`OPVALID, `OPCODE_LDSRAM, 4'd4, 16'd11, 8'd63};
        Instr[97] <= {`OPVALID, `OPCODE_LDSRAM, 4'd5, 16'd11, 8'd77};
        Instr[98] <= {`OPVALID, `OPCODE_LDSRAM, 4'd6, 16'd11, 8'd37};

        // ISA (v1)
        // OPVALID(1) / OPCODE(3) / SEL(4)+ADDR(16) or PARAM(20) / DATA(8): total(32)
        // LDSRAM_W (Load Data to SRAM, Weight)
        Instr[99] <= {`OPVALID, `OPCODE_PARAM, `PARAM_TRG, `TRG_WSRAM};
        // Bank(4Bit), Address(16Bit), Data(8Bit)
        Instr[100] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd0, 8'd89};
        Instr[101] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd1, -8'd33};
        Instr[102] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd2, -8'd92};
        Instr[103] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd3, -8'd17};
        Instr[104] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd4, 8'd44};
        Instr[105] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd5, 8'd25};
        Instr[106] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd6, 8'd19};
        Instr[107] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd7, -8'd60};
        Instr[108] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd8, 8'd61};
        Instr[109] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd9, 8'd105};
        Instr[110] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd10, -8'd70};
        Instr[111] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd11, -8'd9};
        Instr[112] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd12, 8'd55};
        Instr[113] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd13, 8'd18};
        Instr[114] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd14, -8'd12};
        Instr[115] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd15, 8'd37};
        Instr[116] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd16, 8'd118};
        Instr[117] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd17, 8'd109};
        Instr[118] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd18, -8'd74};
        Instr[119] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd19, -8'd5};
        Instr[120] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd20, 8'd42};
        Instr[121] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd21, 8'd110};
        Instr[122] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd22, 8'd46};

        Instr[123] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd0, -8'd107};
        Instr[124] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd1, 8'd102};
        Instr[125] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd2, -8'd103};
        Instr[126] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd3, -8'd28};
        Instr[127] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd4, 8'd39};
        Instr[128] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd5, 8'd113};
        Instr[129] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd6, 8'd102};
        Instr[130] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd7, -8'd25};
        Instr[131] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd8, 8'd29};
        Instr[132] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd9, -8'd120};
        Instr[133] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd10, -8'd68};
        Instr[134] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd11, -8'd82};
        Instr[135] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd12, -8'd124};
        Instr[136] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd13, -8'd41};
        Instr[137] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd14, -8'd43};
        Instr[138] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd15, -8'd21};
        Instr[139] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd16, -8'd127};
        Instr[140] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd17, -8'd65};
        Instr[141] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd18, 8'd52};
        Instr[142] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd19, 8'd111};
        Instr[143] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd20, 8'd10};
        Instr[144] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd21, -8'd23};
        Instr[145] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd22, -8'd82};

        Instr[146] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd0, 8'd104};
        Instr[147] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd1, -8'd17};
        Instr[148] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd2, 8'd60};
        Instr[149] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd3, 8'd106};
        Instr[150] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd4, -8'd88};
        Instr[151] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd5, 8'd82};
        Instr[152] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd6, -8'd7};
        Instr[153] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd7, 8'd88};
        Instr[154] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd8, 8'd60};
        Instr[155] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd9, 8'd55};
        Instr[156] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd10, -8'd45};
        Instr[157] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd11, -8'd7};
        Instr[158] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd12, 8'd113};
        Instr[159] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd13, 8'd74};
        Instr[160] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd14, -8'd46};
        Instr[161] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd15, -8'd88};
        Instr[162] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd16, 8'd31};
        Instr[163] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd17, 8'd17};
        Instr[164] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd18, 8'd29};
        Instr[165] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd19, 8'd126};
        Instr[166] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd20, -8'd97};
        Instr[167] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd21, 8'd99};
        Instr[168] <= {`OPVALID, `OPCODE_LDSRAM, 4'd2, 16'd22, 8'd27};

        Instr[169] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd0, -8'd103};
        Instr[170] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd1, 8'd69};
        Instr[171] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd2, 8'd110};
        Instr[172] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd3, -8'd79};
        Instr[173] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd4, -8'd35};
        Instr[174] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd5, -8'd113};
        Instr[175] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd6, 8'd3};
        Instr[176] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd7, 8'd85};
        Instr[177] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd8, -8'd35};
        Instr[178] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd9, -8'd16};
        Instr[179] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd10, 8'd79};
        Instr[180] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd11, 8'd24};
        Instr[181] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd12, -8'd102};
        Instr[182] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd13, -8'd88};
        Instr[183] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd14, 8'd112};
        Instr[184] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd15, -8'd65};
        Instr[185] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd16, -8'd31};
        Instr[186] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd17, 8'd104};
        Instr[187] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd18, 8'd42};
        Instr[188] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd19, 8'd87};
        Instr[189] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd20, -8'd34};
        Instr[190] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd21, 8'd69};
        Instr[191] <= {`OPVALID, `OPCODE_LDSRAM, 4'd3, 16'd22, 8'd70};

        Instr[192] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd23, 8'd25};
        Instr[193] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd24, -8'd97};
        Instr[194] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd25, -8'd70};
        Instr[195] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd26, 8'd124};
        Instr[196] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd27, 8'd27};
        Instr[197] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd28, 8'd27};
        Instr[198] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd29, -8'd68};
        Instr[199] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd30, 8'd109};
        Instr[200] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd31, 8'd3};
        Instr[201] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd32, -8'd61};
        Instr[202] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd33, -8'd90};
        Instr[203] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd34, 8'd29};
        Instr[204] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd35, -8'd35};
        Instr[205] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd36, -8'd96};
        Instr[206] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd37, 8'd99};
        Instr[207] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd38, -8'd87};
        Instr[208] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd39, 8'd46};
        Instr[209] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd40, -8'd81};
        Instr[210] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd41, -8'd31};
        Instr[211] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd42, 8'd1};
        Instr[212] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd43, -8'd92};
        Instr[213] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd44, -8'd56};
        Instr[214] <= {`OPVALID, `OPCODE_LDSRAM, 4'd0, 16'd45, -8'd87};

        Instr[215] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd23, 8'd0};
        Instr[216] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd24, 8'd0};
        Instr[217] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd25, 8'd0};
        Instr[218] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd26, 8'd0};
        Instr[219] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd27, 8'd0};
        Instr[220] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd28, 8'd0};
        Instr[221] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd29, 8'd0};
        Instr[222] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd30, 8'd0};
        Instr[223] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd31, 8'd0};
        Instr[224] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd32, 8'd0};
        Instr[225] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd33, 8'd0};
        Instr[226] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd34, 8'd0};
        Instr[227] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd35, 8'd0};
        Instr[228] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd36, 8'd0};
        Instr[229] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd37, 8'd0};
        Instr[230] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd38, 8'd0};
        Instr[231] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd39, 8'd0};
        Instr[232] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd40, 8'd0};
        Instr[233] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd41, 8'd0};
        Instr[234] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd42, 8'd0};
        Instr[235] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd43, 8'd0};
        Instr[236] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd44, 8'd0};
        Instr[237] <= {`OPVALID, `OPCODE_LDSRAM, 4'd1, 16'd45, 8'd0};

        // Execute
        Instr[238] <= {`OPVALID, `OPCODE_PARAM, `PARAM_BASE_WSRAM, 8'd0}; // Load Weight to Systolic Array and have to specify the base address
        Instr[239] <= {`OPVALID, `OPCODE_EX, 20'd0, 8'd0};
        Instr[240] <= {`OPVALID, `OPCODE_NOP, 20'd0, 8'd0};

        // Writeback (To external host, Outside top module)
        Instr[241] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd0, 8'd0};
        Instr[242] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd1, 8'd0};
        Instr[243] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd2, 8'd0};
        Instr[244] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd3, 8'd0};
        Instr[245] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd1, 16'd0, 8'd0};
        Instr[246] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd1, 16'd1, 8'd0};
        Instr[247] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd1, 16'd2, 8'd0};
        Instr[248] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd1, 16'd3, 8'd0};
        Instr[249] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd2, 16'd0, 8'd0};
        Instr[250] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd2, 16'd1, 8'd0};
        Instr[251] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd2, 16'd2, 8'd0};
        Instr[252] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd2, 16'd3, 8'd0};
        Instr[253] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd3, 16'd0, 8'd0};
        Instr[254] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd3, 16'd1, 8'd0};
        Instr[255] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd3, 16'd2, 8'd0};
        Instr[256] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd3, 16'd3, 8'd0};
        Instr[257] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd4, 8'd0};
        Instr[258] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd5, 8'd0};
        Instr[259] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd6, 8'd0};
        Instr[260] <= {`OPVALID, `OPCODE_WBPSRAM, 4'd0, 16'd7, 8'd0};

        Instr[261] <= {`OPVALID, `OPCODE_NOP, 20'd0, 8'd0};
    end
endmodule