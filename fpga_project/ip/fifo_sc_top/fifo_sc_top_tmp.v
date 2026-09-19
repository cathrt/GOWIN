//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.03 (64-bit)
//IP Version: 1.1
//Part Number: GW2A-LV55PG1156C8/I7
//Device: GW2A-55
//Device Version: C
//Created Time: Sat Sep 19 14:35:32 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	fifo_sc your_instance_name(
		.Data(Data), //input [7:0] Data
		.Clk(Clk), //input Clk
		.WrEn(WrEn), //input WrEn
		.RdEn(RdEn), //input RdEn
		.Reset(Reset), //input Reset
		.Q(Q), //output [7:0] Q
		.Empty(Empty), //output Empty
		.Full(Full) //output Full
	);

//--------Copy end-------------------
