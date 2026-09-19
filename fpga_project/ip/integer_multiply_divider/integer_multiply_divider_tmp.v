//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.03 (64-bit)
//IP Version: 1.1
//Part Number: GW2A-LV55PG1156C8/I7
//Device: GW2A-55
//Device Version: C
//Created Time: Sat Sep 19 15:46:50 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	gowin_divider your_instance_name(
		.clk(clk), //input clk
		.rstn(rstn), //input rstn
		.kill(kill), //input kill
		.tagI(tagI), //input [4:0] tagI
		.tagO(tagO), //output [4:0] tagO
		.req_ready(req_ready), //output req_ready
		.req_valid(req_valid), //input req_valid
		.resp_ready(resp_ready), //input resp_ready
		.resp_valid(resp_valid), //output resp_valid
		.func(func), //input [3:0] func
		.op0(op0), //input [31:0] op0
		.op1(op1), //input [31:0] op1
		.res0(res0), //output [31:0] res0
		.res1(res1) //output [31:0] res1
	);

//--------Copy end-------------------
