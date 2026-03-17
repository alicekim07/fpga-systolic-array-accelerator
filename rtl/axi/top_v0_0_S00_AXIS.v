
`timescale 1 ns / 1 ps

	module top_v1_0_S00_AXIS #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here
            // Controller Connection
            input wire stream_ready,
            output wire stream_valid,
            output wire [C_S_AXIS_TDATA_WIDTH-1:0] stream_data,
            output wire stream_last,
		// User ports ends
		// Do not modify the ports beyond this line

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Byte qualifier
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);

	// Add user logic here
        // Connect AXI Stream signals to controller signals
        assign S_AXIS_TREADY = stream_ready;
        assign stream_valid = S_AXIS_TVALID;
        assign stream_data = S_AXIS_TDATA;
        assign stream_last = S_AXIS_TLAST;
	// User logic ends

	endmodule
