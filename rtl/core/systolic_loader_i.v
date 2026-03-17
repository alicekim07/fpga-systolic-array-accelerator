`timescale 1ns / 1ps
`include "param.v"

module systolic_loader_i(
    input CLK,
    input [`PE_ROW*`BIT_DATA-1:0] i_Data_I_In,
    output [`PE_ROW*`BIT_DATA-1:0] o_Data_I_In
    );


reg [`BIT_DATA-1:0] FIFO_1[0:0];
reg [`BIT_DATA-1:0] FIFO_2[1:0];
reg [`BIT_DATA-1:0] FIFO_3[2:0];
reg [`BIT_DATA-1:0] FIFO_4[3:0];
reg [`BIT_DATA-1:0] FIFO_5[4:0];
reg [`BIT_DATA-1:0] FIFO_6[5:0];
reg [`BIT_DATA-1:0] FIFO_7[6:0];

// Level 0
assign  o_Data_I_In[0*`BIT_DATA+:`BIT_DATA] = i_Data_I_In[0*`BIT_DATA+:`BIT_DATA];
assign  o_Data_I_In[1*`BIT_DATA+:`BIT_DATA] = FIFO_1[0];
assign  o_Data_I_In[2*`BIT_DATA+:`BIT_DATA] = FIFO_2[0];
assign  o_Data_I_In[3*`BIT_DATA+:`BIT_DATA] = FIFO_3[0];
assign  o_Data_I_In[4*`BIT_DATA+:`BIT_DATA] = FIFO_4[0];
assign  o_Data_I_In[5*`BIT_DATA+:`BIT_DATA] = FIFO_5[0];
assign  o_Data_I_In[6*`BIT_DATA+:`BIT_DATA] = FIFO_6[0];
assign  o_Data_I_In[7*`BIT_DATA+:`BIT_DATA] = FIFO_7[0];

// Level 1
always @(posedge CLK) begin
    FIFO_1[0] <= i_Data_I_In[1*`BIT_DATA+:`BIT_DATA];
    FIFO_2[0] <= FIFO_2[1];
    FIFO_3[0] <= FIFO_3[1];
    FIFO_4[0] <= FIFO_4[1];
    FIFO_5[0] <= FIFO_5[1];
    FIFO_6[0] <= FIFO_6[1];
    FIFO_7[0] <= FIFO_7[1];
end

// Level 2
always @(posedge CLK) begin
    FIFO_2[1] <= i_Data_I_In[2*`BIT_DATA+:`BIT_DATA];
    FIFO_3[1] <= FIFO_3[2];
    FIFO_4[1] <= FIFO_4[2];
    FIFO_5[1] <= FIFO_5[2];
    FIFO_6[1] <= FIFO_6[2];
    FIFO_7[1] <= FIFO_7[2];
end

// Level 3
always @(posedge CLK) begin
    FIFO_3[2] <= i_Data_I_In[3*`BIT_DATA+:`BIT_DATA];
    FIFO_4[2] <= FIFO_4[3];
    FIFO_5[2] <= FIFO_5[3];
    FIFO_6[2] <= FIFO_6[3];
    FIFO_7[2] <= FIFO_7[3];
end

// Level 4
always @(posedge CLK) begin
    FIFO_4[3] <= i_Data_I_In[4*`BIT_DATA+:`BIT_DATA];
    FIFO_5[3] <= FIFO_5[4];
    FIFO_6[3] <= FIFO_6[4];
    FIFO_7[3] <= FIFO_7[4];
end

// Level 5
always @(posedge CLK) begin
    FIFO_5[4] <= i_Data_I_In[5*`BIT_DATA+:`BIT_DATA];
    FIFO_6[4] <= FIFO_6[5];
    FIFO_7[4] <= FIFO_7[5];
end

// Level 6
always @(posedge CLK) begin
    FIFO_6[5] <= i_Data_I_In[6*`BIT_DATA+:`BIT_DATA];
    FIFO_7[5] <= FIFO_7[6];
end

// Level 7
always @(posedge CLK) begin
    FIFO_7[6] <= i_Data_I_In[7*`BIT_DATA+:`BIT_DATA];
end

endmodule