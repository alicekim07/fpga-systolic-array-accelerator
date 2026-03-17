`include "./param.v"


module systolic_ctrl(
    // # region Systolic Array Control Module
        input CLK, RSTb,
        input [`BIT_INSTR-1:0] Instr_In,
        // For WriteBack(Read Path)
        output Flag_Finish_Out,
        output Valid_WB_Out,
        output [`BIT_PSUM-1:0] Data_WB_Out,
        // For SRAM Input Writing
        output [`PE_ROW-1:0] sram_input_we, // SRAM Write Enable
        output [`PE_ROW-1:0] sram_input_en , // SRAM Enable
        output [`PE_ROW*`BIT_ADDR-1:0] sram_input_addr, // 26112 Data, More than 15 Bit needed
        output [`PE_ROW*`BIT_DATA-1:0] sram_input_din, // Data to write
        // For SRAM Weight Writing
        output [`PE_COL-1:0] sram_weight_we , // SRAM Write Enable
        output [`PE_COL-1:0] sram_weight_en , // SRAM Enable
        output [`PE_COL*`BIT_ADDR-1:0] sram_weight_addr, // 26112 Data, More than 15 Bit needed
        output [`PE_COL*`BIT_DATA-1:0] sram_weight_din, // Data to write
        // For SRAM Psum Writing (A Port)
        output [`PE_COL-1:0] sram_psum_we_a, // SRAM Write Enable
        output [`PE_COL-1:0] sram_psum_en_a, // SRAM Enable
        output [`PE_COL*`BIT_ADDR-1:0] sram_psum_addr_a, // Address to write
        output [`PE_COL*`BIT_PSUM-1:0] sram_psum_din_a, // Data to write
        // For SRAM Psum Reading (B Port)
        output [`PE_COL-1:0] sram_psum_we_b, // SRAM Write Enable
        output [`PE_COL-1:0] sram_psum_en_b, // SRAM Enable
        output [`PE_COL*`BIT_ADDR-1:0] sram_psum_addr_b, // Address to read
        input [`PE_COL*`BIT_PSUM-1:0] sram_psum_dout_b, // Data to read
        // For SRAM Bias Reading / Writing
        output [`PE_COL-1:0] sram_bias_we, // SRAM Write Enable
        output [`PE_COL-1:0] sram_bias_en, // SRAM Enable
        output [`PE_COL*`BIT_ADDR-1:0] sram_bias_addr, // Address to write
        output [`PE_COL*`BIT_PSUM-1:0] sram_bias_din, // Data to write
        input [`PE_COL*`BIT_PSUM-1:0] sram_bias_dout, // Data to read
        // For Systolic Weight Control
        output [`BIT_ROW_ID-1:0] systolic_en_row_id, // Row ID for systolic array
        output [`PE_COL-1:0] systolic_en_w, // Enable for systolic array
        // For Systolic Psum In Control
        output [`PE_COL*`BIT_ADDR-1:0] systolic_addr_p, // Address for systolic array
        output [`PE_COL*`BIT_VALID-1:0] systolic_valid_p, // Valid for systolic array
        // For Stall
        output instr_stall,
        // For Weight muxing
        output weight_to_systolic_sel,
        // For debug
        output [`BIT_STATE-1:0] state_out, // Debug output for state
            // output [`PE_COL*`BIT_ADDR-1:0] sram_weight_addr_out,
            // output [`PE_COL*`BIT_DATA-1:0] sram_weight_din_out
        // For instruction stablize
        input instr_pulse,
        // For AXIS Slave DMA
        output stream_ready,
        input stream_valid,
        input [`BIT_INSTR-1 : 0] stream_data,
        input stream_last,
        // For AXIS Master DMA
        output signed [`BIT_INSTR-1 : 0] m_axis_tdata,
        output m_axis_tvalid,
        output m_axis_tlast,
        input m_axis_tready,
        // For ignoring psum bit
        output ignore_psum_bit
    // #endregion
    );

    // o_Flag_Finish : Finish Flag ('1' When OPCODE_EX has been finished. '0' otherwise), o_Flag Finish returns to '0' if writeback starts
    // o_Valid : Valid Output Data Flag('1' when o_Data is valid. '0' otherwise)
    // o_Data : 24-bit Output Data

    // # 0) Parameter
    // # region parameter
        parameter integer WB_VALID_HOLD_CYCLES = 3;
        localparam integer WB_READY_CNT_WIDTH = 2;
        localparam integer WB_CNT_WIDTH = 2;
        parameter integer BYTES_PER_ELEM = 1; // INT8
        parameter integer ELEMS_PER_WORD = 8; // 8개의 INT8 = 1 Word
        parameter integer BYTES_PER_WORD = BYTES_PER_ELEM * ELEMS_PER_WORD;
        parameter integer ADDR_SHIFT = 3;
        localparam integer LANE_ISRAM = 8;
        localparam integer LANE_WSRAM = 4;
        localparam integer LANE_PSRAM = 4;
        localparam integer SELW_ISRAM = 3; // clog2(8)
        localparam integer SELW_WSRAM = 2; // clog2(4)
        localparam integer SELW_PSRAM = 2; // clog2(4)
        localparam integer SELW_BSRAM = 2; // clog2(4)
        localparam integer BIT_IC = 20; 
        localparam integer BIT_S = 20; 
        localparam integer BIT_BLOCK = 20;
        localparam integer BIT_BASE_ADDR_DMA = 32; // Max 64K bytes
        localparam integer WARM_UP_CYCLES = 2; // psram latency 대응
    // # endregion

    // 1) 외부 상태/카운터 선언부 : q/d 쌍 만들기
    // # region External State Declaration
        // For WriteBack(Read Path)
        reg Flag_Finish_Out_q, Flag_Finish_Out_d;
        reg Valid_WB_Out_q, Valid_WB_Out_d;
        reg [`BIT_PSUM-1:0] Data_WB_Out_q, Data_WB_Out_d;
        // For SRAM Input Writing
        reg [`PE_ROW-1:0] sram_input_we_q, sram_input_we_d; // SRAM Write Enable
        reg [`PE_ROW-1:0] sram_input_en_q, sram_input_en_d; // SRAM Enable
        reg [`PE_ROW*`BIT_ADDR-1:0] sram_input_addr_q, sram_input_addr_d; // 26112 Data, More than 15 Bit needed
        reg [`PE_ROW*`BIT_DATA-1:0] sram_input_din_q, sram_input_din_d; // Data to write
        // For SRAM Weight Writing
        reg [`PE_COL-1:0] sram_weight_we_q, sram_weight_we_d; // SRAM Write Enable
        reg [`PE_COL-1:0] sram_weight_en_q, sram_weight_en_d; // SRAM Enable
        reg [`PE_COL*`BIT_ADDR-1:0] sram_weight_addr_q, sram_weight_addr_d; // 26112 Data, More than 15 Bit needed
        reg [`PE_COL*`BIT_DATA-1:0] sram_weight_din_q, sram_weight_din_d; // Data to write
        // For SRAM Psum Writing (A Port)
        reg [`PE_COL-1:0] sram_psum_we_a_q, sram_psum_we_a_d; // SRAM Write Enable
        reg [`PE_COL-1:0] sram_psum_en_a_q, sram_psum_en_a_d; // SRAM Enable
        reg [`PE_COL*`BIT_ADDR-1:0] sram_psum_addr_a_q, sram_psum_addr_a_d; // Address to write
        reg [`PE_COL*`BIT_PSUM-1:0] sram_psum_din_a_q, sram_psum_din_a_d; // Data to write
        // For SRAM Psum Reading (B Port)
        reg [`PE_COL-1:0] sram_psum_we_b_q, sram_psum_we_b_d; // SRAM Write Enable
        reg [`PE_COL-1:0] sram_psum_en_b_q, sram_psum_en_b_d; // SRAM Enable
        reg [`PE_COL*`BIT_ADDR-1:0] sram_psum_addr_b_q, sram_psum_addr_b_d; // Address to read
        // For SRAM Bias Writing
        reg [`PE_COL-1:0] sram_bias_we_q, sram_bias_we_d; // SRAM Write Enable
        reg [`PE_COL-1:0] sram_bias_en_q, sram_bias_en_d; // SRAM Enable
        reg [`PE_COL*`BIT_ADDR-1:0] sram_bias_addr_q, sram_bias_addr_d; // Address to write
        reg [`PE_COL*`BIT_PSUM-1:0] sram_bias_din_q, sram_bias_din_d; // Data to write
        // For Systolic Weight Control
        reg [`BIT_ROW_ID-1:0] systolic_en_row_id_q, systolic_en_row_id_d; // Row ID for systolic array
        reg [`PE_COL-1:0] systolic_en_w_q, systolic_en_w_d; // Enable for systolic array
        // For Systolic Psum In Control
        reg [`PE_COL*`BIT_ADDR-1:0] systolic_addr_p_q, systolic_addr_p_d; // Address for systolic array
        reg [`PE_COL*`BIT_VALID-1:0] systolic_valid_p_q, systolic_valid_p_d; // Valid for systolic array
        // For AXIS Master DMA

    // # endregion

    // 2) 내부 상태/카운터 선언부 : q/d 쌍 만들기
    // # region Internal State Declaration
        // State Variables
        reg [`BIT_STATE:0] state_q, state_d;
        // Define the opcode, param, and data
        reg opvalid_q, opvalid_d;
        reg [`BIT_OPCODE-1:0] opcode_q, opcode_d;
        reg [`BIT_PARAM-1:0] param_q, param_d;
        reg [`BIT_SEL-1:0] sel_q, sel_d;
        reg [`BIT_ADDR-1:0] addr_q, addr_d;
        reg [`BIT_DATA-1:0] data_q, data_d;
        // Instruction register
        reg [`BIT_INSTR-1:0] instr_reg_q, instr_reg_d;
        // Define Parameters
        reg [`BIT_PARAM-1:0] Param_S_q, Param_S_d;
        reg [`BIT_PARAM-1:0] Param_OC_q, Param_OC_d;
        reg [`BIT_PARAM-1:0] Param_IC_q, Param_IC_d;
        reg [`BIT_PARAM-1:0] Param_TRG_q, Param_TRG_d;
        // For PSUM INIT
        reg [`BIT_ADDR-1:0] psum_init_addr_q, psum_init_addr_d; // Psum init count
        // IC, OC for Execute
        reg [`BIT_PARAM:0] State_IC_q, State_IC_d;
        reg [`BIT_PARAM:0] State_OC_q, State_OC_d;
        reg [`BIT_PARAM:0] Next_IC_q, Next_IC_d;
        reg [`BIT_PARAM:0] Next_OC_q, Next_OC_d;
        reg [`BIT_PARAM:0] Run_IC_q, Run_IC_d; // # of Enabled IC (PE Rows)
        reg [`BIT_PARAM:0] Run_OC_q, Run_OC_d; // # of Enabled OC (PE Cols)
        // Count
        reg [3:0] load_cnt_q, load_cnt_d; // Load count for systolic array
        reg [31:0] run_cnt_q, run_cnt_d; // Run count for systolic array

        reg [63:0] clk_cnt_q, clk_cnt_d; // Clock count for systolic array
        reg [63:0] run_total_cnt_q, run_total_cnt_d; // Execution count for performance measurement
        reg [63:0] set_total_cnt_q, set_total_cnt_d; // Total count for set state
        reg [63:0] load_total_cnt_q, load_total_cnt_d; // Total count for load state
        reg [63:0] dma_isram_total_cnt_q, dma_isram_total_cnt_d; // Total count for DMA ISRAM write
        reg [63:0] dma_wsram_total_cnt_q, dma_wsram_total_cnt_d; // Total count for DMA WSRAM write
        reg [63:0] dma_psram_total_cnt_q, dma_psram_total_cnt_d; // Total count for DMA PSRAM write
        reg [63:0] control_overhead_cnt_q, control_overhead_cnt_d; // Count for control overhead 
        reg [63:0] interface_overhead_cnt_q, interface_overhead_cnt_d; // Count for interface overhead (excluding control overhead)
        //
        reg [`PE_COL*`BIT_VALID-1:0] systolic_valid_p_raw_q, systolic_valid_p_raw_d; // Valid for systolic array
        //
        reg [`BIT_DATA-1:0] Param_BASE_WSRAM_q, Param_BASE_WSRAM_d;
        reg [`BIT_DATA-1:0] Param_BASE_WSRAM_WH_q, Param_BASE_WSRAM_WH_d;
        // For Instruction Handling
        reg instr_seen_q, instr_seen_d;
        //
        reg [`BIT_SEL-1:0] sel_dma_q, sel_dma_d;
        reg [BIT_BASE_ADDR_DMA-1:0] base_addr_dma_d, base_addr_dma_q;
        reg [BIT_IC-1:0] ic_idx_q, ic_idx_d;
        reg [BIT_S-1:0] s_dma_q, s_dma_d;
        reg [BIT_S-1:0] m_s_dma_q, m_s_dma_d;
        reg [BIT_BLOCK-1:0] block_dma_q, block_dma_d;
        reg [BIT_BLOCK-1:0] m_block_dma_q, m_block_dma_d;
        reg [`BIT_ADDR-1:0] bsram_addr_dma_q, bsram_addr_dma_d;
        // Base address for calculation
        reg [`BIT_PARAM-1:0] Base_I_calc_q, Base_W_calc_q;
        // AXI Master DMA
        reg [31:0] wb_sent_cnt_q, wb_sent_cnt_d;
        reg [31:0] wb_total_cnt_q, wb_total_cnt_d;
        reg [`BIT_SEL-1:0] m_psram_sel_dma_q, m_psram_sel_dma_d;

        reg [`BIT_PSUM-1:0] m_axis_tdata_buffer_data_q, m_axis_tdata_buffer_data_d;
        reg m_axis_tdata_buffer_full_q, m_axis_tdata_buffer_full_d;
        reg [31:0] m_axis_tdata_buffer_cnt_q, m_axis_tdata_buffer_cnt_d;

        // Ignore Psum Data Bit
        reg ignore_psum_active_q, ignore_psum_active_d;
        reg ignore_psum_req_q, ignore_psum_req_d;
    // # endregion

    // 3) 출력 포트 연결은 항상 _q 쪽으로
    // # region Output Port Assignment
        assign Flag_Finish_Out = Flag_Finish_Out_q;
        assign Valid_WB_Out = Valid_WB_Out_q;
        assign Data_WB_Out = Data_WB_Out_q;
        assign sram_input_we = sram_input_we_q;
        assign sram_input_en = sram_input_en_q;
        assign sram_input_addr = sram_input_addr_q;
        assign sram_input_din = sram_input_din_q;
        assign sram_weight_we = sram_weight_we_q;
        assign sram_weight_en = sram_weight_en_q;
        assign sram_weight_addr = sram_weight_addr_q;
        assign sram_weight_din = sram_weight_din_q;
        assign sram_psum_we_a = sram_psum_we_a_q;
        assign sram_psum_en_a = sram_psum_en_a_q;
        assign sram_psum_addr_a = sram_psum_addr_a_q;
        assign sram_psum_din_a = sram_psum_din_a_q;
        assign sram_psum_we_b = sram_psum_we_b_q;
        assign sram_psum_en_b = sram_psum_en_b_q; // & ~sram_loader_psum_en_a & ~sram_psum_en_a_q; // Disable if loader or A port is writing
        assign sram_psum_addr_b = sram_psum_addr_b_q;
        assign systolic_en_row_id = systolic_en_row_id_q;
        assign systolic_en_w = systolic_en_w_q;
        assign systolic_addr_p = systolic_addr_p_q;
        assign systolic_valid_p = systolic_valid_p_q;
        
        assign sram_bias_we = sram_bias_we_q;
        assign sram_bias_en = sram_bias_en_q;
        assign sram_bias_addr = sram_bias_addr_q;
        assign sram_bias_din = sram_bias_din_q;

        assign m_axis_tdata = {{(32-`BIT_PSUM){m_axis_tdata_buffer_data_q[`BIT_PSUM-1]}}, m_axis_tdata_buffer_data_q[`BIT_PSUM-1:0]};
        assign m_axis_tvalid = m_axis_tdata_buffer_full_q;

        assign ignore_psum_bit = ignore_psum_active_q;
    // # endregion

    // 4) 내부 wire 신호
    // # region Internal Wire Declaration
        // instr_reg_q에서만 필드 추출 (Instr_In 직접 참조 금지!)
        wire opvalid_w = instr_reg_q[(`BIT_DATA + `BIT_PARAM + `BIT_OPCODE) +: `BIT_VALID];
        wire [`BIT_OPCODE-1:0] opcode_w = instr_reg_q[(`BIT_DATA + `BIT_PARAM) +: `BIT_OPCODE];
        wire [`BIT_PARAM-1:0]  param_w  = instr_reg_q[`BIT_DATA +: `BIT_PARAM];
        wire [`BIT_SEL-1:0]    sel_w    = instr_reg_q[`BIT_DATA + `BIT_ADDR +: `BIT_SEL];
        wire [`BIT_ADDR-1:0]   addr_w   = instr_reg_q[`BIT_DATA +: `BIT_ADDR];
        wire [`BIT_DATA-1:0]   data_w   = instr_reg_q[0 +: `BIT_DATA];
        wire [`BIT_ADDR-1:0]   Base_W_full;
 
        wire [SELW_ISRAM-1:0] isram_sel = sel_q[SELW_ISRAM-1:0];
        wire [SELW_WSRAM-1:0] wsram_sel = sel_q[SELW_WSRAM-1:0];
        wire [SELW_PSRAM-1:0] psram_sel = sel_q[SELW_PSRAM-1:0];
        wire [SELW_BSRAM-1:0] bsram_sel = sel_q[SELW_BSRAM-1:0];
        // For DMA SRAM Write
        wire stream_fire;
        wire enter_write_sram_dma;
        wire enter_write_back_stream_dma;
        wire [`BIT_ADDR-1:0] isram_addr_dma;
        wire [`BIT_ADDR-1:0] wsram_addr_dma;
        wire [`BIT_ADDR-1:0] bsram_addr_dma;
        wire [BIT_BLOCK-1:0] num_block_w;
        wire [`BIT_SEL-1:0] last_block_rows_w;
        wire [`BIT_SEL-1:0] block_rows_w;
        wire [BIT_BLOCK-1:0] wb_num_block_w;
        wire [`BIT_SEL-1:0] wb_last_block_cols_w;
        wire [`BIT_SEL-1:0] wb_block_cols_w;
        // For DMA AXI Master
        wire [`BIT_SEL-1:0] m_psram_sel_dma;
        wire [`BIT_ADDR-1:0] m_psram_addr_dma;
        wire [31:0] wb_sent_cnt;
        wire [31:0] wb_total_cnt;
        //
        wire enter_write_back_addr_dma;
    // # endregion

    // 4) 파생 신호(콤비)
    // # region Derived Signals
        assign instr_stall = (instr_seen_d || instr_seen_q);
        assign weight_to_systolic_sel = (load_cnt_q < Run_IC_q+1) ? 1'b1 : 1'b0; // Weight to systolic array
        assign Base_W_full = {Param_BASE_WSRAM_WH_q[`BIT_DATA-1:0], Param_BASE_WSRAM_q[`BIT_DATA-1:0]};
        assign stream_ready = (state_q == `WRITE_SRAM_DMA);
        assign stream_fire = stream_valid && stream_ready;
        assign enter_write_sram_dma = (state_q != `WRITE_SRAM_DMA) && (state_d == `WRITE_SRAM_DMA);
        assign enter_write_back_stream_dma = (state_q != `WRITE_BACK_STREAM_DMA) && (state_d == `WRITE_BACK_STREAM_DMA);
        assign num_block_w = (Param_IC_q == 0) ? 1 : ((Param_IC_q + `PE_ROW - 1) / `PE_ROW);
        assign last_block_rows_w = (Param_IC_q == 0) ? 1 : ((Param_IC_q % `PE_ROW) == 0 ? `PE_ROW : (Param_IC_q % `PE_ROW));
        assign block_rows_w = (block_dma_q == num_block_w - 1) ? last_block_rows_w : `PE_ROW;
        assign wb_num_block_w = (Param_OC_q == 0) ? 1 : ((Param_OC_q + `PE_COL - 1) / `PE_COL);
        assign wb_last_block_cols_w = (Param_OC_q == 0) ? 1 : ((Param_OC_q % `PE_COL) == 0 ? `PE_COL : (Param_OC_q % `PE_COL));
        assign wb_block_cols_w = (m_block_dma_q == wb_num_block_w - 1) ? wb_last_block_cols_w : `PE_COL;
        assign isram_addr_dma = s_dma_q + Param_S_q * block_dma_q;
        assign m_psram_addr_dma = m_s_dma_q + Param_S_q * m_block_dma_q;
        assign wsram_addr_dma = Base_W_full + base_addr_dma_q + ic_idx_q;
        assign bsram_addr_dma = bsram_addr_dma_q;
        assign m_psram_sel_dma = m_psram_sel_dma_q;
        assign wb_sent_cnt = wb_sent_cnt_q;
        assign wb_total_cnt = wb_total_cnt_q;
        assign m_axis_tlast = (wb_sent_cnt_q == wb_total_cnt - 1) ? 1'b1 : 1'b0;
    // # endregion

    // 5) 임시 Combination 신호
    // # region Temporay Combinational Signals
        integer i;
        integer width;
        integer pos;
        integer total_len;
        integer win_start;
        integer win_end;
        reg [`PE_COL-1:0] oc_mask;
        reg [`BIT_ADDR-1:0] pattern_array [0:`PE_ROW-1]; // Pattern array for systolic array
        reg [`BIT_ADDR-1:0] pattern_array_d [0:`PE_ROW-1]; // Pattern array for systolic array
        reg [`PE_COL-1:0] valid_window;
        reg [`BIT_STATE-1:0] state_prev;
    // # endregion

    // 6) Combination Block : 기본 hold 후 state 별로 *_d 갱신
    // # region Combinational Block
        always @(*) begin
            // 0. Default hold
            // # region Default Hold
                Flag_Finish_Out_d = Flag_Finish_Out_q;
                Valid_WB_Out_d = Valid_WB_Out_q;
                Data_WB_Out_d = Data_WB_Out_q;
                sram_input_we_d = sram_input_we_q;
                sram_input_en_d = sram_input_en_q;
                sram_input_addr_d = sram_input_addr_q;
                sram_input_din_d = sram_input_din_q;
                sram_weight_we_d = sram_weight_we_q;
                sram_weight_en_d = sram_weight_en_q;
                sram_weight_addr_d = sram_weight_addr_q;
                sram_weight_din_d = sram_weight_din_q;
                sram_psum_we_a_d = sram_psum_we_a_q;
                sram_psum_en_a_d = sram_psum_en_a_q;
                sram_psum_addr_a_d = sram_psum_addr_a_q;
                sram_psum_din_a_d = sram_psum_din_a_q;
                sram_psum_we_b_d = sram_psum_we_b_q;
                sram_psum_en_b_d = sram_psum_en_b_q;
                sram_psum_addr_b_d = sram_psum_addr_b_q;
                systolic_en_row_id_d = systolic_en_row_id_q;
                systolic_en_w_d = systolic_en_w_q;
                systolic_addr_p_d = systolic_addr_p_q;
                systolic_valid_p_d = systolic_valid_p_q;
                state_d = state_q;
                clk_cnt_d = clk_cnt_q + 1;
                run_total_cnt_d = run_total_cnt_q;
                set_total_cnt_d = set_total_cnt_q;
                load_total_cnt_d = load_total_cnt_q;
                dma_isram_total_cnt_d = dma_isram_total_cnt_q;
                dma_wsram_total_cnt_d = dma_wsram_total_cnt_q;
                dma_psram_total_cnt_d = dma_psram_total_cnt_q;
                control_overhead_cnt_d = control_overhead_cnt_q;
                interface_overhead_cnt_d = interface_overhead_cnt_q;

                opvalid_d = opvalid_q;
                opcode_d = opcode_q;
                param_d = param_q;
                sel_d = sel_q;
                addr_d = addr_q;
                data_d = data_q;
                Param_S_d = Param_S_q;
                Param_OC_d = Param_OC_q;
                Param_IC_d = Param_IC_q;
                Param_TRG_d = Param_TRG_q;

                psum_init_addr_d = psum_init_addr_q;

                State_IC_d = State_IC_q;
                State_OC_d = State_OC_q;
                Next_IC_d = Next_IC_q;
                Next_OC_d = Next_OC_q;
                Run_IC_d = Run_IC_q;
                Run_OC_d = Run_OC_q;
                load_cnt_d = load_cnt_q;
                run_cnt_d = run_cnt_q;
                systolic_valid_p_raw_d = systolic_valid_p_raw_q;

                Param_BASE_WSRAM_d = Param_BASE_WSRAM_q;
                Param_BASE_WSRAM_WH_d = Param_BASE_WSRAM_WH_q;
                //
                instr_reg_d = instr_reg_q;
                //
                instr_seen_d = instr_seen_q;
                if (instr_pulse) begin
                    instr_seen_d = 1'b1;
                end
                sel_dma_d = sel_dma_q;
                base_addr_dma_d = base_addr_dma_q;
                ic_idx_d = ic_idx_q;
                s_dma_d = s_dma_q;
                m_s_dma_d = m_s_dma_q;
                block_dma_d = block_dma_q;
                m_block_dma_d = m_block_dma_q;
                bsram_addr_dma_d = bsram_addr_dma_q;

                m_psram_sel_dma_d = m_psram_sel_dma_q;
                wb_sent_cnt_d = wb_sent_cnt_q;
                wb_total_cnt_d = wb_total_cnt_q;

                m_axis_tdata_buffer_data_d = m_axis_tdata_buffer_data_q;
                m_axis_tdata_buffer_full_d = m_axis_tdata_buffer_full_q;
                m_axis_tdata_buffer_cnt_d = m_axis_tdata_buffer_cnt_q;

                ignore_psum_active_d = ignore_psum_active_q;
                ignore_psum_req_d = ignore_psum_req_q;
            // # endregion
            // # region Default derived signals
                oc_mask = {`PE_COL{1'b0}};
                valid_window = {`PE_COL{1'b0}};
            // # endregion
            // 1. Reset Condition
            // # region Reset register
                if (enter_write_sram_dma) begin
                    sel_dma_d = 0;
                    base_addr_dma_d = 0;
                    ic_idx_d = 0;
                    s_dma_d = 0;
                    m_s_dma_d = 0;
                    block_dma_d = 0;
                    m_block_dma_d = 0;
                    bsram_addr_dma_d = 0;
                end
                if (enter_write_back_stream_dma) begin
                    wb_total_cnt_d = Param_S_q * Param_OC_q;
                end
            // # endregion

            // 2. Next State Logic
            case (state_q)
                `IDLE: begin
                    state_d = `FETCH;
                end
                `FETCH: begin
                    state_d = `STABLIZE;
                end
                `STABLIZE: begin
                    if (instr_seen_q) begin
                        state_d = `DECODE;
                    end else begin
                        state_d = `STABLIZE;
                    end
                end
                `DECODE: begin
                    state_d = `EXECUTE; 
                end
                `EXECUTE: begin
                    if (opvalid_q) begin
                        case (opcode_q)
                            `OPCODE_NOP:       state_d = `INSTR_CLEAR;
                            `OPCODE_PARAM:     state_d = `PARAM_SET;
                            `OPCODE_LDSRAM:    state_d = `WRITE_SRAM;
                            `OPCODE_IGNORE_PSUM_BIT:    state_d = `IGNORE_PSUM_BIT_SET;
                            `OPCODE_EX: state_d = `SET;
                            `OPCODE_WBPSRAM: state_d = `WRITE_BACK;
                            `OPCODE_WBPARAM: state_d = `WRITE_BACK_PARAM;
                            `OPCODE_WRITESRAM_DMA: state_d = `WRITE_SRAM_DMA;
                            default:         state_d = `INSTR_CLEAR;
                        endcase
                    end else begin
                        state_d = `INSTR_CLEAR;
                    end
                end
                `PARAM_SET: begin
                    state_d = `INSTR_CLEAR;
                end
                `WRITE_SRAM: begin
                    state_d = `INSTR_CLEAR;
                end
                `IGNORE_PSUM_BIT_SET: begin
                    state_d = `INSTR_CLEAR;
                end
                `SET: begin
                    // $display("State_IC_q: %d, Param_IC_q: %d", State_IC_q, Param_IC_q); 
                    state_d = `PRELOAD;
                end
                `PRELOAD: begin
                    state_d = `LOAD;
                end
                `LOAD: begin
                    state_d = (load_cnt_q == `PE_ROW-1) ? `RUN : `PRELOAD;
                end
                `RUN: begin
                    // $display("Next_IC_q, Next_OC_q: %d, %d", Next_IC_q, Next_OC_q);
                    if (run_cnt_q < (Param_S_q + `PE_ROW + `PE_COL + 1)) begin
                        state_d = `RUN;
                    end else begin
                        if (Next_IC_q == 0 && Next_OC_q == 0) begin
                            state_d = `WRITE_BACK_STREAM_DMA;
                        end else begin
                            state_d = `SET;
                        end
                    end
                end
                `WRITE_BACK: begin
                    state_d = `WRITE_BACK_READY;
                end
                `WRITE_BACK_READY: begin
                    state_d = `WRITE_BACK_OUTPUT;
                end
                `WRITE_BACK_OUTPUT: begin
                    state_d = `INSTR_CLEAR;
                end
                `WRITE_BACK_PARAM: begin
                    state_d = `INSTR_CLEAR;
                end
                `INSTR_CLEAR: begin
                    state_d = `FETCH;
                end
                `WRITE_SRAM_DMA: begin
                    if (stream_fire && stream_last)
                        state_d = `INSTR_CLEAR;
                    else
                        state_d = `WRITE_SRAM_DMA;
                end
                `WRITE_BACK_STREAM_DMA: begin
                    if (m_axis_tready && m_axis_tvalid && m_axis_tlast) begin
                        state_d = `INSTR_CLEAR;
                    end else begin
                        state_d = `WRITE_BACK_STREAM_DMA;
                    end
                end
                default: state_d = `INSTR_CLEAR;
            endcase
            // 3. Output/Action Logic
            case (state_q)
                `FETCH: begin
                    interface_overhead_cnt_d = interface_overhead_cnt_q + 1; // Count interface overhead for fetch
                    // Fetch instruction and update outputs accordingly
                    Valid_WB_Out_d = 1'b0; // Clear valid flag
                    sram_input_we_d = 0; // Disable write to Input SRAM
                    sram_input_en_d = 0; // Disable Input SRAM
                    sram_weight_en_d = 0; // Disable Weight SRAM
                    sram_weight_we_d = 0; // Disable write to Weight SRAM
                    sram_bias_we_d = 0; // Disable write to Bias SRAM
                    sram_bias_en_d = 0; // Disable Bias SRAM
                    // instr_seen_d = 1'b0;                    
                    sram_psum_we_b_d = {`PE_COL{1'b0}}; // Ensure write is disabled
                    sram_psum_en_b_d = {`PE_COL{1'b0}}; // Disable Psum SRAM enable
                    wb_sent_cnt_d = 0;
                    m_axis_tdata_buffer_data_d = 0;
                    m_axis_tdata_buffer_full_d = 0;
                    m_axis_tdata_buffer_cnt_d = 0;
                    m_s_dma_d = 0;
                    m_block_dma_d = 0;
                    m_psram_sel_dma_d = 0;
                end
                `STABLIZE: begin
                    interface_overhead_cnt_d = interface_overhead_cnt_q + 1; // Count interface overhead for stablize
                    instr_reg_d = Instr_In;
                end
                `DECODE: begin
                    interface_overhead_cnt_d = interface_overhead_cnt_q + 1; // Count interface overhead for decode
                    opvalid_d = instr_reg_q[(`BIT_DATA + `BIT_PARAM + `BIT_OPCODE) +: `BIT_VALID]; // Extract valid bit from instruction
                    opcode_d = instr_reg_q[(`BIT_DATA + `BIT_PARAM) +: `BIT_OPCODE]; // Extract opcode from instruction
                    param_d = instr_reg_q[`BIT_DATA +: `BIT_PARAM]; // Extract param from instruction
                    sel_d = instr_reg_q[`BIT_DATA + `BIT_ADDR +: `BIT_SEL]; // Extract select bits from instruction
                    addr_d = instr_reg_q[`BIT_DATA +: `BIT_ADDR]; // Extract address from instruction
                    data_d = instr_reg_q[0 +: `BIT_DATA]; // Extract data from instruction
                end
                `EXECUTE: begin
                    interface_overhead_cnt_d = interface_overhead_cnt_q + 1; // Count interface overhead for execute
                    if (opvalid_q) begin
                        case (opcode_q) 
                            `OPCODE_EX: begin
                                Flag_Finish_Out_d = 1'b0; // Clear finish flag
                                // run_total_cnt_d = 64'd0;
                                // set_total_cnt_d = 64'd0;
                                // load_total_cnt_d = 64'd0;
                                // dma_isram_total_cnt_d = 64'd0;
                                // dma_wsram_total_cnt_d = 64'd0;
                                // dma_psram_total_cnt_d = 64'd0;
                            end
                            `OPCODE_WBPSRAM: begin
                                sel_d = sel_q;
                                addr_d = addr_q;
                            end
                        endcase
                    end
                end
                `PARAM_SET: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for parameter setting
                    // Set parameters and update outputs accordingly
                    case (param_q)
                        `PARAM_S: begin
                            // Set S parameter
                            Param_S_d = data_q;
                        end
                        `PARAM_S_WH: begin
                            // Set Higher bits of S parameter
                            Param_S_d = {data_q, Param_S_q[`BIT_DATA-1:0]}; // Concatenate higher bits with existing S parameter
                        end
                        `PARAM_IC: begin
                            // Set IC parameter
                            Param_IC_d = data_q;
                        end
                        `PARAM_IC_WH: begin
                            // Set Higher bits of IC parameter
                            Param_IC_d = {data_q, Param_IC_q[`BIT_DATA-1:0]}; // Concatenate higher bits with existing IC parameter
                        end
                        `PARAM_OC: begin
                            // Set OC parameter
                            Param_OC_d = data_q;
                        end
                        `PARAM_OC_WH: begin
                            // Set Higher bits of OC parameter
                            Param_OC_d = {data_q, Param_OC_q[`BIT_DATA-1:0]}; // Concatenate higher bits with existing OC parameter
                        end
                        `PARAM_TRG: begin
                            // Set target for SRAM (Input, Weight, Psum)
                            Param_TRG_d = data_q;
                        end
                        `PARAM_BASE_WSRAM: begin
                            // Set base address for WSRAM
                            Param_BASE_WSRAM_d = data_q[`BIT_DATA-1:0];
                        end
                        `PARAM_BASE_WSRAM_WH: begin
                            // Set Higher bits of base address for WSRAM
                            Param_BASE_WSRAM_WH_d = data_q[`BIT_DATA-1:0];               
                        end


                        default: begin 
                            // Default case, do nothing or reset outputs as needed 
                        end
                    endcase
                end
                `WRITE_SRAM: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for SRAM writing
                    // Write to SRAM and update outputs accordingly
                    case (Param_TRG_q)
                        `TRG_ISRAM: begin
                            // Write to Input SRAM
                            sram_input_we_d = 0; sram_input_we_d[isram_sel] = 1'b1; // Enable write to selected SRAM
                            sram_input_en_d = 0; sram_input_en_d[isram_sel] = 1'b1; // Enable selected SRAM
                            sram_input_addr_d[isram_sel*`BIT_ADDR+:`BIT_ADDR] = addr_q; // Address to write
                            sram_input_din_d[isram_sel*`BIT_DATA+:`BIT_DATA] = data_q; // Data to write
                        end
                        `TRG_WSRAM: begin
                            // Write to Weight SRAM
                            sram_weight_we_d = 0; sram_weight_we_d[wsram_sel] = 1'b1; // Enable write to selected SRAM
                            sram_weight_en_d = 0; sram_weight_en_d[wsram_sel] = 1'b1; // Enable selected SRAM
                            sram_weight_addr_d[wsram_sel*`BIT_ADDR+:`BIT_ADDR] = Base_W_full + addr_q;
                            sram_weight_din_d[wsram_sel*`BIT_DATA+:`BIT_DATA] = data_q; // Data to write
                        end
                        // `TRG_PSRAM: begin
                        //     // Write to Psum SRAM (if applicable)
                        //     sram_psum_we_a_d = 0; sram_psum_we_a_d[psram_sel] = 1'b1; // Enable write to selected SRAM
                        //     sram_psum_en_a_d = 0; sram_psum_en_a_d[psram_sel] = 1'b1; // Enable selected SRAM
                        //     sram_psum_addr_a_d[psram_sel*`BIT_ADDR+:`BIT_ADDR] = addr_q; // Address to write
                        //     sram_psum_din_a_d[psram_sel*`BIT_DATA+:`BIT_DATA] = data_q; // Data to write
                        // end
                        `TRG_BSRAM: begin
                            // Write to Bias SRAM
                            sram_bias_we_d = 0; sram_bias_we_d[bsram_sel] = 1'b1; // Enable write to selected SRAM
                            sram_bias_en_d = 0; sram_bias_en_d[bsram_sel] = 1'b1; // Enable selected SRAM
                            sram_bias_addr_d[bsram_sel*`BIT_ADDR+:`BIT_ADDR] = addr_q; // Address to write
                            sram_bias_din_d[bsram_sel*`BIT_PSUM+:`BIT_PSUM] = data_q; // Data to write
                        end
                        default: begin 
                            // Default case, do nothing or reset outputs as needed 
                        end
                    endcase
                end
                `IGNORE_PSUM_BIT_SET: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for ignore psum bit setting
                    ignore_psum_req_d = 1'b1; // Set ignore psum bit flag
                end  
                `SET: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for set state
                    // Set up for execution and update outputs accordingly
                    set_total_cnt_d = set_total_cnt_q + 1;
                    // Ignore Bit for Psum
                    if (Next_IC_q == 0) begin
                        ignore_psum_active_d = ignore_psum_req_q; // If starting a new IC block, update ignore_psum_active based on the request
                    end else begin
                        ignore_psum_active_d = 1'b0;
                    end
                    // Reset load count and enable signals
                    load_cnt_d = 0; // Reset load count
                    run_cnt_d = 0; // Reset run count
                    // Load IC/OC status
                    State_IC_d = Next_IC_q;
                    State_OC_d = Next_OC_q;
                    // Determine Run_OC
                    if (Next_OC_q + `PE_COL <= Param_OC_q) begin
                        Run_OC_d = `PE_COL;
                    end else begin
                        Run_OC_d = Param_OC_q - Next_OC_q;
                    end
                    // Determine Run_IC
                    if (Next_IC_q + `PE_ROW <= Param_IC_q) begin
                        Run_IC_d = `PE_ROW;
                    end else begin
                        Run_IC_d = Param_IC_q - Next_IC_q;
                    end
                    // Next Index
                    if (Next_IC_q + `PE_ROW < Param_IC_q) begin
                        Next_IC_d = Next_IC_q + `PE_ROW;
                        Next_OC_d = Next_OC_q;
                    end else if (Next_OC_q + `PE_COL < Param_OC_q) begin
                        Next_IC_d = 0;
                        Next_OC_d = Next_OC_q + `PE_COL;
                    end else begin
                        Next_IC_d = 0;
                        Next_OC_d = 0;
                    end
                end
                `PRELOAD: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for preload state
                    load_total_cnt_d = load_total_cnt_q + 1;
                    // 1. Enable Weight read
                    sram_weight_en_d = (Run_OC_q == 0) ? {`PE_COL{1'b0}} : ({`PE_COL{1'b1}} >> (`PE_COL - Run_OC_q));
                    for (i = 0; i < `PE_COL; i = i + 1) begin
                        if (i < Run_OC_q) begin
                            sram_weight_addr_d[i*`BIT_ADDR +: `BIT_ADDR] = Base_W_full + Base_W_calc_q + load_cnt_q;
                        end else begin
                            sram_weight_addr_d[i*`BIT_ADDR +: `BIT_ADDR] = {`BIT_ADDR{1'b0}};
                        end
                        // $display("PRELOAD: Bank=%0d, Weight Addr = %0d", i, sram_weight_addr_d[i*`BIT_ADDR +: `BIT_ADDR]);
                        // $display("PRELOAD DEBUG: load=%0d full=%0d calc=%0d (IC=%0d + ICstep=%0d * OCstep=%0d)", load_cnt_q, Base_W_full, Base_W_calc, State_IC_q, Param_IC_q, (State_OC_q / `PE_COL));
                    end
                end
                `LOAD: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for load state`
                    load_total_cnt_d = load_total_cnt_q + 1;
                    // Load data and update outputs accordingly
                    load_cnt_d = load_cnt_q + 1; // Increment load count
                    // 2. Systolic Weight Write Control
                    systolic_en_row_id_d = load_cnt_q; // Set row ID
                    systolic_en_w_d = {`PE_COL{1'b1}}; // Enable for systolic array
                end
                `RUN: begin
                    // Execution counter
                    run_total_cnt_d = run_total_cnt_q + 1;
                    // Execute and update outputs accordingly
                    sram_psum_en_b_d = 0; // Disable
                    systolic_valid_p_raw_d = 0; // Disable
                    //
                    if (run_cnt_q < (Param_S_q + `PE_ROW + `PE_COL + 1)) begin
                        run_cnt_d = run_cnt_q + 1; // Increment run count
                    end else begin
                        if (Next_IC_q == 0 && Next_OC_q == 0) begin
                            Flag_Finish_Out_d = 1'b1; // Set finish flag
                        end else begin
                            Flag_Finish_Out_d = 1'b0; // Clear finish flag
                        end
                    end
                    // 1. Enable Input SRAM Read
                    // $display("RUN: run_cnt=%0d", run_cnt_q);
                    if (run_cnt_q < Param_S_q) begin
                        sram_input_we_d = 0; // Disable write to Input SRAM
                        sram_input_en_d = (Run_IC_q == 0) ? {`PE_ROW{1'b0}} : ({`PE_ROW{1'b1}} >> (`PE_ROW - Run_IC_q));
                        for (i = 0; i < `PE_ROW; i = i + 1) begin
                            sram_input_addr_d[i*`BIT_ADDR+:`BIT_ADDR] = (i < Run_IC_q) ? (Base_I_calc_q + run_cnt_q) : {`BIT_ADDR{1'b0}};
                        end
                    end
                    // 2. Enable Psum SRAM Read
                    sram_psum_we_b_d = 0; // Disable write to Psum SRAM
                    sram_psum_en_b_d = (Run_OC_q == 0) ? {`PE_COL{1'b0}} : ({`PE_COL{1'b1}} >> (`PE_COL - Run_OC_q));
                    sram_psum_en_b_d = ignore_psum_active_q ? 0 : sram_psum_en_b_d; // If ignore_psum bit is active, disable Psum SRAM read
                    for (i = 0; i < `PE_COL; i = i + 1) begin
                        sram_psum_addr_b_d[i*`BIT_ADDR+:`BIT_ADDR] = (i < Run_OC_q) ? (((State_OC_q/`PE_COL)*Param_S_q) + pattern_array[i]) : {`BIT_ADDR{1'b0}};
                    end
                    // 3. Systolic Psum Write Control
                    for (i = 0; i < `PE_COL; i = i + 1) begin
                        systolic_addr_p_d[i*`BIT_ADDR+:`BIT_ADDR] = (i < Run_OC_q) ? (((State_OC_q/`PE_COL)*Param_S_q) + pattern_array_d[i]) : {`BIT_ADDR{1'b0}};
                    end
                    // 4. Set Psum Valid bits based on run_cnt
                    // 4-1. Calculate window start (clamped to 0)
                    if (run_cnt_q >= Param_S_q -1)
                        win_start = run_cnt_q - (Param_S_q - 1);
                    else
                        win_start = 0;
                    // 4-2. Calculate window end (clamped to PE_COL-1)
                    win_end = run_cnt_q;
                    if (win_end >= `PE_COL)
                        win_end = `PE_COL - 1;
                    // 4-3. Apply window
                    for (i = 0; i < `PE_COL; i = i + 1) begin
                        if (i >= win_start && i <= win_end)
                            systolic_valid_p_raw_d[i] = 1'b1;
                        else
                            systolic_valid_p_raw_d[i] = 1'b0;
                    end

                    // 5. Masking
                    oc_mask = (Run_OC_q == 0) ? {`PE_COL{1'b0}} : ({`PE_COL{1'b1}} >> (`PE_COL - Run_OC_q));
                    systolic_valid_p_d = systolic_valid_p_raw_q & oc_mask; // Apply mask
                end
                `WRITE_BACK: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for write back
                    // Write back results and update outputs accordingly
                    Valid_WB_Out_d = 1'b0; // Clear valid flag
                    // 1. Setup for Psum SRAM read
                    sram_psum_we_b_d = {`PE_COL{1'b0}}; // Disable write to Psum SRAM
                    sram_psum_en_b_d = 0; sram_psum_en_b_d[psram_sel] = 1'b1; // Enable selected Psum SRAM
                    sram_psum_addr_b_d[psram_sel*`BIT_ADDR+:`BIT_ADDR] = addr_q; // Address to read
                    // 2. Setup for Bias SRAM read
                    sram_bias_we_d = 0; // Disable write to Bias SRAM
                    sram_bias_en_d = 0; sram_bias_en_d[bsram_sel] = 1'b1; // Enable selected Bias SRAM
                    sram_bias_addr_d[bsram_sel*`BIT_ADDR+:`BIT_ADDR] = addr_q / Param_S_q; // Address to read
                end
                `WRITE_BACK_READY: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for write back ready
                    // BRAM latency 기다리는 동안 EN경로 유지
                    Valid_WB_Out_d = 1'b0;

                    // (A) B 포트 Write 금지
                    sram_psum_we_b_d = {`PE_COL{1'b0}}; // Ensure write is disabled

                    // (B) lane 선택/enable -> sel_q 비트만 1
                    sram_psum_en_b_d = {`PE_COL{1'b0}};
                    sram_psum_en_b_d[psram_sel] = 1'b1;
                    //sram_psum_en_b_d = sram_psum_en_b_q; // Maintain previous enable state

                    // (C) 주소 셋업 -> 해당 lane에 addr_q 반영
                    sram_psum_addr_b_d[psram_sel*`BIT_ADDR +: `BIT_ADDR] = addr_q;

                    // 2. Setup for Bias SRAM read
                    sram_bias_we_d = 0; // Disable write to Bias SRAM
                    sram_bias_en_d = 0; sram_bias_en_d[bsram_sel] = 1'b1; // Enable selected Bias SRAM
                    sram_bias_addr_d[bsram_sel*`BIT_ADDR+:`BIT_ADDR] = addr_q / Param_S_q; // Address to read
                end
                `WRITE_BACK_OUTPUT: begin
                    control_overhead_cnt_d = control_overhead_cnt_q + 1; // Count control overhead for write back output
                    // Write back output data and update outputs accordingly

                    // 첫 사이클에만 샘플, 이후엔 유지
                    Data_WB_Out_d = sram_psum_dout_b[psram_sel*`BIT_PSUM+:`BIT_PSUM] + sram_bias_dout[bsram_sel*`BIT_PSUM+:`BIT_PSUM]; // Sample output data from Psum SRAM
                    Valid_WB_Out_d = 1'b1;

                    // 이제 EN 내려도 안전
                    sram_psum_en_b_d = {`PE_COL{1'b0}}; // Disable Psum SRAM enable
                    sram_psum_we_b_d = {`PE_COL{1'b0}}; // Ensure write is disabled
                    sram_bias_en_d = {`PE_COL{1'b0}}; // Disable Bias SRAM enable
                    sram_bias_we_d = {`PE_COL{1'b0}}; // Disable write to Bias SRAM
                end
                `WRITE_BACK_PARAM: begin
                    // Write back parameters and update outputs accordingly
                    case(param_q)
                        `PARAM_BASE_WSRAM: begin
                            // Write back base address for WSRAM
                            Data_WB_Out_d = Base_W_full; // Output base address
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_S: begin
                            // Write back S parameter
                            Data_WB_Out_d = Param_S_q; // Output S parameter
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_OC: begin
                            // Write back OC parameter
                            Data_WB_Out_d = Param_OC_q; // Output OC parameter
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_IC: begin
                            // Write back IC parameter
                            Data_WB_Out_d = Param_IC_q; // Output IC parameter
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_TRG: begin
                            // Write back target for SRAM
                            Data_WB_Out_d = Param_TRG_q; // Output target
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_CLK_TOTAL_CNT: begin
                            // Write back total clock count
                            Data_WB_Out_d = clk_cnt_q; // Output clock count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_RUN_TOTAL_CNT: begin
                            // Write back execution count
                            Data_WB_Out_d = run_total_cnt_q; // Output execution count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_SET_TOTAL_CNT: begin
                            // Write back set execution count
                            Data_WB_Out_d = set_total_cnt_q; // Output execution count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_LOAD_TOTAL_CNT: begin
                            // Write back load execution count
                            Data_WB_Out_d = load_total_cnt_q; // Output execution count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_DMA_ISRAM_TOTAL_CNT: begin
                            // Write back DMA Input SRAM count
                            Data_WB_Out_d = dma_isram_total_cnt_q; // Output DMA count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_DMA_WSRAM_TOTAL_CNT: begin
                            // Write back DMA Weight SRAM count
                            Data_WB_Out_d = dma_wsram_total_cnt_q; // Output DMA count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_DMA_PSRAM_TOTAL_CNT: begin
                            // Write back DMA Psum SRAM count
                            Data_WB_Out_d = dma_psram_total_cnt_q; // Output DMA count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_CONTROL_OVERHEAD_TOTAL_CNT: begin
                            // Write back control overhead count
                            Data_WB_Out_d = control_overhead_cnt_q; // Output control overhead count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end
                        `PARAM_INTERFACE_OVERHEAD_TOTAL_CNT: begin
                            // Write back interface overhead count
                            Data_WB_Out_d = interface_overhead_cnt_q; // Output interface overhead count
                            Valid_WB_Out_d = 1'b1; // Set valid flag
                        end

                        default: begin
                            // Default case, do nothing or reset outputs as needed
                        end
                    endcase
                end
                `INSTR_CLEAR: begin
                    interface_overhead_cnt_d = interface_overhead_cnt_q + 1; // Count interface overhead for instruction clear
                    instr_seen_d = 1'b0; // Clear instruction seen flag
                end
                `WRITE_SRAM_DMA: begin
                    // Write to SRAM via DMA and update outputs accordingly
                    if (stream_fire) begin
                        case (Param_TRG_q)
                            `TRG_ISRAM: begin
                                dma_isram_total_cnt_d = dma_isram_total_cnt_q + 1;
                                // Write to Input SRAM
                                sram_input_we_d = 0; sram_input_we_d[sel_dma_q] = 1'b1; // Enable write to selected SRAM
                                sram_input_en_d = 0; sram_input_en_d[sel_dma_q] = 1'b1; // Enable selected SRAM
                                sram_input_addr_d[sel_dma_q*`BIT_ADDR+:`BIT_ADDR] = isram_addr_dma; // Address to write
                                sram_input_din_d[sel_dma_q*`BIT_DATA+:`BIT_DATA] = stream_data[0+:`BIT_DATA]; // Data to write

                                // Original column-first update logic (kept for reference)
                                // if (s_dma_q == Param_S_q - 1) begin
                                //     // Reset s_dma
                                //     s_dma_d = 0;
                                //     if (sel_dma_q == `PE_ROW - 1) begin
                                //         sel_dma_d = 0;
                                //         block_dma_d = block_dma_q + 1;
                                //
                                //     end else begin
                                //         sel_dma_d = sel_dma_q + 1;
                                //     end
                                // end else begin
                                //     s_dma_d = s_dma_q + 1;
                                // end

                                // Row-first with block rollover, and no-padding partial-block handling.
                                if (sel_dma_q == block_rows_w - 1) begin
                                    sel_dma_d = 0;

                                    if (block_dma_q == num_block_w - 1) begin
                                        block_dma_d = 0;

                                        if (s_dma_q == Param_S_q - 1) begin
                                            s_dma_d = 0;
                                        end else begin
                                            s_dma_d = s_dma_q + 1;
                                        end
                                    end else begin
                                        block_dma_d = block_dma_q + 1;
                                    end
                                end else begin
                                    sel_dma_d = sel_dma_q + 1;
                                end
                                $display("[%0t] DMA WRITE ISRAM: sel=%0d addr=%0d data=%0h", $time, sel_dma_q, isram_addr_dma, stream_data[0+:`BIT_DATA]);
                            end
                            `TRG_WSRAM: begin
                                dma_wsram_total_cnt_d = dma_wsram_total_cnt_q + 1;
                                // Write to Weight SRAM
                                sram_weight_we_d = 0; sram_weight_we_d[sel_dma_q] = 1'b1; // Enable write to selected SRAM
                                sram_weight_en_d = 0; sram_weight_en_d[sel_dma_q] = 1'b1; // Enable selected SRAM
                                sram_weight_addr_d[sel_dma_q*`BIT_ADDR+:`BIT_ADDR] = wsram_addr_dma; // Address to write
                                sram_weight_din_d[sel_dma_q*`BIT_DATA+:`BIT_DATA] = stream_data[0+:`BIT_DATA]; // Data to write

                                // Update DMA counters
                                if (ic_idx_q == Param_IC_q - 1) begin
                                    // Reset ic_idx
                                    ic_idx_d = 0;
                                    // Check PE_COL end
                                    if (sel_dma_q == `PE_COL - 1) begin
                                        sel_dma_d = 0;
                                        base_addr_dma_d = base_addr_dma_q + Param_IC_q;
                                    end else begin
                                        sel_dma_d = sel_dma_q + 1;
                                    end
                                end else begin
                                    ic_idx_d = ic_idx_q + 1;
                                end
                            end
                            `TRG_BSRAM: begin
                                // Write to Bias SRAM
                                sram_bias_we_d = 0; sram_bias_we_d[sel_dma_q] = 1'b1; // Enable write to selected SRAM
                                sram_bias_en_d = 0; sram_bias_en_d[sel_dma_q] = 1'b1; // Enable selected SRAM
                                sram_bias_addr_d[sel_dma_q*`BIT_ADDR+:`BIT_ADDR] = bsram_addr_dma; // Address to write
                                sram_bias_din_d[sel_dma_q*`BIT_PSUM+:`BIT_PSUM] = stream_data[0+:`BIT_PSUM]; // Data to write

                                // Update DMA counters
                                if (sel_dma_q == `PE_COL - 1) begin
                                    sel_dma_d = 0;
                                    bsram_addr_dma_d = bsram_addr_dma_q + 1;
                                end else begin
                                    sel_dma_d = sel_dma_q + 1;
                                end
                            end
                            default: begin 
                                // Default case, do nothing or reset outputs as needed 
                            end
                        endcase
                    end
                end                 
                `WRITE_BACK_STREAM_DMA: begin
                    dma_psram_total_cnt_d = dma_psram_total_cnt_q + 1;
                    // 1. Buffer Fill
                    if (m_axis_tdata_buffer_full_q == 0) begin
                        m_axis_tdata_buffer_cnt_d = m_axis_tdata_buffer_cnt_q + 1;
                        if (m_axis_tdata_buffer_cnt_q == 0) begin
                            // 1. Setup for Psum SRAM read
                            sram_psum_we_b_d = {`PE_COL{1'b0}}; // Disable write to Psum SRAM
                            sram_psum_en_b_d = 0; sram_psum_en_b_d[m_psram_sel_dma] = 1'b1; // Enable selected Psum SRAM
                            sram_psum_addr_b_d[m_psram_sel_dma*`BIT_ADDR+:`BIT_ADDR] = m_psram_addr_dma; // Address to read
                            // 2. Setup for Bias SRAM read
                            sram_bias_we_d = 0; // Disable write to Bias SRAM
                            sram_bias_en_d = 0; sram_bias_en_d[m_psram_sel_dma] = 1'b1; // Enable selected Bias SRAM
                            sram_bias_addr_d[m_psram_sel_dma*`BIT_ADDR+:`BIT_ADDR] = m_psram_addr_dma / Param_S_q; // Address to read
                            // 3. Write back output data and update outputs accordingly
                        end
                        if (m_axis_tdata_buffer_cnt_q == 2) begin
                            m_axis_tdata_buffer_data_d = sram_psum_dout_b[m_psram_sel_dma_q*`BIT_PSUM+:`BIT_PSUM] + sram_bias_dout[m_psram_sel_dma_q*`BIT_PSUM+:`BIT_PSUM];
                            m_axis_tdata_buffer_full_d = 1;
                            m_axis_tdata_buffer_cnt_d = 0;
                        end
                    end
                    // 2. Buffer Consume
                    if (m_axis_tvalid && m_axis_tready) begin
                        m_axis_tdata_buffer_full_d = 0;
                    end

                    // 3. sel 및 addr 계산
                    if (m_axis_tvalid && m_axis_tready) begin
                        wb_sent_cnt_d = wb_sent_cnt_q + 1;
                        // Original update logic (kept for reference)
                        // if (m_s_dma_q == Param_S_q - 1) begin
                        //     // Reset addr
                        //     m_s_dma_d = 0;
                        //
                        //     // psram_sel advance condition
                        //     if (m_psram_sel_dma_q == `PE_COL - 1) begin
                        //         m_psram_sel_dma_d = 0;
                        //         m_block_dma_d = m_block_dma_q + 1;
                        //     end else begin
                        //         m_psram_sel_dma_d = m_psram_sel_dma_q + 1;
                        //     end
                        // end else begin
                        //     // addr increment
                        //     m_s_dma_d = m_s_dma_q + 1;
                        // end

                        // OC-first traversal with no-padding partial OC block handling.
                        if (m_psram_sel_dma_q == wb_block_cols_w - 1) begin
                            m_psram_sel_dma_d = 0;

                            if (m_block_dma_q == wb_num_block_w - 1) begin
                                m_block_dma_d = 0;
                                if (m_s_dma_q == Param_S_q - 1) begin
                                    m_s_dma_d = 0;
                                end else begin
                                    m_s_dma_d = m_s_dma_q + 1;
                                end
                            end else begin
                                m_block_dma_d = m_block_dma_q + 1;
                            end
                        end else begin
                            m_psram_sel_dma_d = m_psram_sel_dma_q + 1;
                        end
                    end

                    // Reset Register
                    ignore_psum_req_d = 1'b0;
                end       
                default: begin
                    // Default case, do nothing or reset outputs as needed
                end
            endcase
        end
    // # endregion  

    // 7) Sequential Block : _q <= f(_q, _d)
    // # region Sequential Block
        always @(posedge CLK or negedge RSTb) begin
            if (!RSTb) begin
                Base_I_calc_q <= 0;
                Base_W_calc_q <= 0;
            end else begin
                Base_I_calc_q <= Param_S_q * (State_IC_d / `PE_ROW);
                Base_W_calc_q <= State_IC_d + Param_IC_q * (State_OC_d / `PE_COL);
            end
        end
    // # endregion

    // 8) Sequential Block : *_q <= *_d
    // # region Sequential Block
        always @(posedge CLK or negedge RSTb) begin
            if (!RSTb) begin
            // 비동기 리셋(모든 Q 초기화)
                // 상태
                state_q <= `IDLE;
                state_prev <= `IDLE;
                // Decode 결과
                opvalid_q <= 1'b0;
                opcode_q <= 0;
                param_q <= 0;
                sel_q <= 0;
                addr_q <= 0;
                data_q <= 0;

                // 파라미터 / 인덱스
                Param_S_q <= 0;
                Param_OC_q <= 0;
                Param_IC_q <= 0;
                Param_TRG_q <= 0;

                State_IC_q <= 0;
                State_OC_q <= 0;
                Next_IC_q <= 0;
                Next_OC_q <= 0;
                Run_IC_q <= 0;
                Run_OC_q <= 0;

                // 카운터
                psum_init_addr_q <= 0;
                load_cnt_q <= 0;
                run_cnt_q <= 0;
                clk_cnt_q <= 0;
                run_total_cnt_q <= 0;
                set_total_cnt_q <= 0;
                load_total_cnt_q <= 0;
                dma_isram_total_cnt_q <= 0;
                dma_wsram_total_cnt_q <= 0;
                dma_psram_total_cnt_q <= 0;
                control_overhead_cnt_q <= 0;
                interface_overhead_cnt_q <= 0;
                

                // SRAM / Systolic 제어신호
                sram_input_we_q <= 0;
                sram_input_en_q <= 0;
                sram_input_addr_q <= 0;
                sram_input_din_q <= 0;

                sram_weight_we_q <= 0;
                sram_weight_en_q <= 0;
                sram_weight_addr_q <= 0;
                sram_weight_din_q <= 0;

                sram_psum_we_a_q <= 0;
                sram_psum_en_a_q <= 0;
                sram_psum_addr_a_q <= 0;
                sram_psum_din_a_q <= 0;

                sram_psum_we_b_q <= 0;
                sram_psum_en_b_q <= 0;
                sram_psum_addr_b_q <= 0;

                systolic_en_row_id_q <= 0; 
                systolic_en_w_q <= 0;
                systolic_addr_p_q <= 0;
                systolic_valid_p_q <= 0;
                systolic_valid_p_raw_q <= 0;


                // WriteBack
                Flag_Finish_Out_q <= 0;
                Valid_WB_Out_q <= 0;
                Data_WB_Out_q <= 0;  

                instr_reg_q <= 0;
                Param_BASE_WSRAM_q <= 0;
                Param_BASE_WSRAM_WH_q <= 0;

                // 
                instr_seen_q <= 1'b0;
                // DMA 관련
                sel_dma_q <= 0;
                base_addr_dma_q <= 0;
                ic_idx_q <= 0;
                s_dma_q <= 0;
                block_dma_q <= 0;
                // Bias 관련
                sram_bias_we_q <= 0;
                sram_bias_en_q <= 0;
                sram_bias_addr_q <= 0;
                sram_bias_din_q <= 0;
                bsram_addr_dma_q <= 0;
                // AXI Master 관련
                m_psram_sel_dma_q <= 0;
                wb_sent_cnt_q <= 0;
                wb_total_cnt_q <= 0;
                m_axis_tdata_buffer_data_q <= 0;
                m_axis_tdata_buffer_full_q <= 0;
                m_axis_tdata_buffer_cnt_q <= 0;
                //
                ignore_psum_active_q <= 0;
                ignore_psum_req_q <= 0;
            end else begin
                // 동기식 상태 갱신
                Flag_Finish_Out_q <= Flag_Finish_Out_d;
                Valid_WB_Out_q <= Valid_WB_Out_d;
                Data_WB_Out_q <= Data_WB_Out_d;
                sram_input_we_q <= sram_input_we_d;
                sram_input_en_q <= sram_input_en_d;
                sram_input_addr_q <= sram_input_addr_d;
                sram_input_din_q <= sram_input_din_d;
                sram_weight_we_q <= sram_weight_we_d;
                sram_weight_en_q <= sram_weight_en_d;
                sram_weight_addr_q <= sram_weight_addr_d;
                sram_weight_din_q <= sram_weight_din_d;
                sram_psum_we_a_q <= sram_psum_we_a_d;
                sram_psum_en_a_q <= sram_psum_en_a_d;
                sram_psum_addr_a_q <= sram_psum_addr_a_d;
                sram_psum_din_a_q <= sram_psum_din_a_d;
                sram_psum_we_b_q <= sram_psum_we_b_d;
                sram_psum_en_b_q <= sram_psum_en_b_d;
                sram_psum_addr_b_q <= sram_psum_addr_b_d;
                systolic_en_row_id_q <= systolic_en_row_id_d;
                systolic_en_w_q <= systolic_en_w_d;
                systolic_addr_p_q <= systolic_addr_p_d;
                systolic_valid_p_q <= systolic_valid_p_d;
                state_q <= state_d;
                opvalid_q <= opvalid_d;
                opcode_q <= opcode_d;
                param_q <= param_d;
                sel_q <= sel_d;
                addr_q <= addr_d;
                data_q <= data_d;
                Param_S_q <= Param_S_d;
                Param_OC_q <= Param_OC_d;
                Param_IC_q <= Param_IC_d;
                Param_TRG_q <= Param_TRG_d;
                psum_init_addr_q <= psum_init_addr_d;
                State_IC_q <= State_IC_d;
                State_OC_q <= State_OC_d;
                Next_IC_q <= Next_IC_d;
                Next_OC_q <= Next_OC_d;
                Run_IC_q <= Run_IC_d;
                Run_OC_q <= Run_OC_d;
                load_cnt_q <= load_cnt_d;
                run_cnt_q <= run_cnt_d;
                clk_cnt_q <= clk_cnt_d;
                run_total_cnt_q <= run_total_cnt_d;
                load_total_cnt_q <= load_total_cnt_d;
                set_total_cnt_q <= set_total_cnt_d;
                dma_isram_total_cnt_q <= dma_isram_total_cnt_d;
                dma_wsram_total_cnt_q <= dma_wsram_total_cnt_d;
                dma_psram_total_cnt_q <= dma_psram_total_cnt_d;
                control_overhead_cnt_q <= control_overhead_cnt_d;
                interface_overhead_cnt_q <= interface_overhead_cnt_d;
                systolic_valid_p_raw_q <= systolic_valid_p_raw_d;
                instr_reg_q <= instr_reg_d;

                Param_BASE_WSRAM_q <= Param_BASE_WSRAM_d;
                Param_BASE_WSRAM_WH_q <= Param_BASE_WSRAM_WH_d;
                //
                instr_seen_q <= instr_seen_d;
                //
                sel_dma_q <= sel_dma_d;
                base_addr_dma_q <= base_addr_dma_d;
                ic_idx_q <= ic_idx_d;
                s_dma_q <= s_dma_d;
                m_s_dma_q <= m_s_dma_d;
                block_dma_q <= block_dma_d;
                m_block_dma_q <= m_block_dma_d;
                //
                sram_bias_we_q <= sram_bias_we_d;
                sram_bias_en_q <= sram_bias_en_d;
                sram_bias_addr_q <= sram_bias_addr_d;
                sram_bias_din_q <= sram_bias_din_d;
                bsram_addr_dma_q <= bsram_addr_dma_d;
                //
                m_psram_sel_dma_q <= m_psram_sel_dma_d;
                wb_sent_cnt_q <= wb_sent_cnt_d;
                wb_total_cnt_q <= wb_total_cnt_d;
                m_axis_tdata_buffer_data_q <= m_axis_tdata_buffer_data_d;
                m_axis_tdata_buffer_full_q <= m_axis_tdata_buffer_full_d;
                m_axis_tdata_buffer_cnt_q <= m_axis_tdata_buffer_cnt_d;
                //
                ignore_psum_active_q <= ignore_psum_active_d;
                ignore_psum_req_q <= ignore_psum_req_d;
                //
                state_prev <= state_q;
            end
        end
    // # endregion

    // 9) Pattern Array
    // # region Pattern Array
        always @(*) begin
            for (i = 0; i < `PE_COL; i = i + 1) begin
                if ((run_cnt_q >= i) && (run_cnt_q - i < Param_S_q))
                    pattern_array[i] = run_cnt_q - i;
                else
                    pattern_array[i] = 0;
            end
        end
        always @(posedge CLK or negedge RSTb) begin
            if (!RSTb) begin
                for (i = 0; i < `PE_COL; i = i + 1)
                    pattern_array_d[i] <= 0;
            end else begin
                for (i = 0; i < `PE_COL; i = i + 1) begin
                    pattern_array_d[i] <= pattern_array[i];
                end
            end
        end
    // # endregion

    // 10) Debug Signals
    // # region Debug Signals
        assign state_out = state_q[`BIT_STATE-1:0];
        assign sram_weight_addr_out = sram_weight_addr_q;
        assign sram_weight_din_out = sram_weight_din_q;
    // # endregion

endmodule
