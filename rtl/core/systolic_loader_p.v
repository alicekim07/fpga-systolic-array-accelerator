`timescale 1ns / 1ps
`include "./param.v"

module systolic_loader_p(
    input CLK,
    input RSTb,
    // Get Psum data from systolic
    input [`PE_COL-1:0] Valid_P_Out,
    input [`PE_COL*`BIT_ADDR-1:0] Addr_P_Out,
    input [`PE_COL*`BIT_PSUM-1:0] Psum_Out,

    // For SRAM(Psum) Writing (A Port)
    output reg [`PE_COL-1:0] sram_psum_we_a, // SRAM Write Enable
    output reg [`PE_COL-1:0] sram_psum_en_a, // SRAM Enable
    output reg [`PE_COL*`BIT_ADDR-1:0] sram_psum_addr_a, // Address to write
    output reg [`PE_COL*`BIT_PSUM-1:0] sram_psum_din_a // Data to write
    );

    // Loop Variable
    integer i;

    always @(posedge CLK) begin
        for (i = 0; i < `PE_COL; i = i + 1) begin
            if (Valid_P_Out[i] == 1) begin
                // $display("[Psum Write] Bank : %0d, Addr : %0d, Psum : %0d", i, Addr_P_Out[i*`BIT_ADDR+:`BIT_ADDR], Psum_Out[i*`BIT_PSUM+:`BIT_PSUM]);
                sram_psum_we_a[i] <= 1;
                sram_psum_en_a[i] <= 1;
                sram_psum_addr_a[i*`BIT_ADDR+:`BIT_ADDR] <= Addr_P_Out[i*`BIT_ADDR+:`BIT_ADDR];
                sram_psum_din_a[i*`BIT_PSUM+:`BIT_PSUM] <= Psum_Out[i*`BIT_PSUM+:`BIT_PSUM];
            end
            else begin
                sram_psum_we_a[i] <= 0;
                sram_psum_en_a[i] <= 0;
                sram_psum_addr_a[i*`BIT_ADDR+:`BIT_ADDR] <= 0;
                sram_psum_din_a[i*`BIT_PSUM+:`BIT_PSUM] <= 0;
            end
        end
    end

endmodule