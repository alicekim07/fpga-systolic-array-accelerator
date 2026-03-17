module sram_dual_behavior (
    input clka, clkb,
    input [7:0] addra, addrb,
    input [23:0] dina, dinb,
    output reg [23:0] douta, doutb,
    input ena, enb,
    input wea, web
    // output [23:0] debug_mem_0, debug_mem_1, debug_mem_2, debug_mem_3,
    // output [23:0] debug_mem_4, debug_mem_5, debug_mem_6, debug_mem_7
);

// assign debug_mem_0 = memory_cell[0];
// assign debug_mem_1 = memory_cell[1];
// assign debug_mem_2 = memory_cell[2];
// assign debug_mem_3 = memory_cell[3];

// assign debug_mem_4 = memory_cell[4];
// assign debug_mem_5 = memory_cell[5];
// assign debug_mem_6 = memory_cell[6];
// assign debug_mem_7 = memory_cell[7];

reg [23:0] memory_cell [255:0];

always @(posedge clka) begin
    if (ena) begin
        if (wea) begin
            memory_cell[addra] <= dina;
        end else begin
            douta <= memory_cell[addra];
        end
    end else if (enb) begin
        if (web) begin
            memory_cell[addrb] <= dinb;
        end else begin
            doutb <= memory_cell[addrb];
        end
    end
end

endmodule