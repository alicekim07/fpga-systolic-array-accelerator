// ISA (v1)
// OPVALID(1) / OPCODE(3) / SEL(4)+ADDR(16) or PARAM(20) / DATA(8): total(32)

`define PE_ROW  8
`define PE_COL  4

`define BIT_ROW_ID  3

`define OPVALID 1'b1

`define BIT_OPCODE  3
`define OPCODE_NOP      `BIT_OPCODE'd0 // No operations
`define OPCODE_PARAM    `BIT_OPCODE'd1 // Store parameter in NPU core
`define OPCODE_LDSRAM   `BIT_OPCODE'd2 // Load data from external host and store data in SRAM
`define OPCODE_IGNORE_PSUM_BIT `BIT_OPCODE'd3 // Ignore the psum bit when outputting data
`define OPCODE_EX       `BIT_OPCODE'd4 // Execute matrix multiplication
`define OPCODE_WBPSRAM  `BIT_OPCODE'd5 // Opcode Write Back Psum SRAM, Writeback output data to external host
`define OPCODE_WBPARAM  `BIT_OPCODE'd6 // For debugging purpose, Writeback parameter to external host
`define OPCODE_WRITESRAM_DMA `BIT_OPCODE'd7 // Write data from SRAM to external host via DMA


// param
`define BIT_PARAM     20
`define BIT_SEL       4
`define BIT_ADDR      16
`define BIT_DP_ADDR   8
`define BIT_SP_ADDR   6
`define BIT_VALID     1
`define BIT_INPUT_DMA 64

`define PARAM_S       `BIT_PARAM'd0
`define PARAM_S_WH    `BIT_PARAM'd1
`define PARAM_IC      `BIT_PARAM'd2
`define PARAM_IC_WH   `BIT_PARAM'd3
`define PARAM_OC      `BIT_PARAM'd4
`define PARAM_OC_WH   `BIT_PARAM'd5
`define PARAM_TRG     `BIT_PARAM'd6
`define PARAM_BASE_WSRAM    `BIT_PARAM'd7
`define PARAM_BASE_WSRAM_WH `BIT_PARAM'd8
`define PARAM_CLK_TOTAL_CNT     `BIT_PARAM'd9
`define PARAM_RUN_TOTAL_CNT     `BIT_PARAM'd10
`define PARAM_SET_TOTAL_CNT     `BIT_PARAM'd11
`define PARAM_LOAD_TOTAL_CNT    `BIT_PARAM'd12
`define PARAM_DMA_ISRAM_TOTAL_CNT `BIT_PARAM'd13
`define PARAM_DMA_WSRAM_TOTAL_CNT `BIT_PARAM'd14
`define PARAM_DMA_PSRAM_TOTAL_CNT `BIT_PARAM'd15
`define PARAM_CONTROL_OVERHEAD_TOTAL_CNT   `BIT_PARAM'd16
`define PARAM_INTERFACE_OVERHEAD_TOTAL_CNT   `BIT_PARAM'd17

// data
`define BIT_DATA      8
`define BIT_PSUM      24
`define TRG_ISRAM     `BIT_DATA'd0
`define TRG_WSRAM     `BIT_DATA'd1
`define TRG_PSRAM     `BIT_DATA'd2
`define TRG_BSRAM     `BIT_DATA'd3

`define BIT_INSTR     (1+`BIT_OPCODE+`BIT_PARAM+`BIT_DATA)
`define BIT_STATE     5

// Declare the state values 
`define IDLE               5'b00000 // 0
`define FETCH              5'b00001 // 1
`define STABLIZE           5'b00010 // 2
`define DECODE             5'b00011 // 3
`define EXECUTE            5'b00100 // 4
`define PARAM_SET          5'b00101 // 5
`define WRITE_SRAM         5'b00110 // 6
`define READ_SRAM          5'b00111 // 7
`define SET                5'b01000 // 8
`define PRELOAD            5'b01001 // 9
`define LOAD               5'b01010 // A
`define RUN                5'b01011 // B
`define WRITE_BACK         5'b01100 // C
`define WRITE_BACK_READY   5'b01101 // D
`define WRITE_BACK_OUTPUT  5'b01110 // E
`define WRITE_BACK_PARAM   5'b01111 // F
`define INSTR_CLEAR        5'b10000 // 10
`define WRITE_SRAM_DMA     5'b10001 // 11
`define WRITE_BACK_STREAM_DMA 5'b10010 // 12
`define IGNORE_PSUM_BIT_SET    5'b10011 // 13

`define DEBUG_MODE     1'b1