/*
PID处理数据周期为2ms，一共要发送的数据为96位，16字节，采用115200bps
若采用9600bps，发送16个字节需要约10ms的时间，这会导致数据撕裂
采用115200bps，发送16个字节需要约 1ms的时间，完全可以
*/
module uart_tx_top#(
	parameter integer WIDTH_DATA  = 16,		// 状态数据位宽
	parameter integer WIDTH_BYTE  = 8,		// 字节位宽
    parameter integer DECIM_N     = 8,      // 8 分频，用于降低数据打包频率

	// VOFA+ 协议帧尾
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE0 = 8'h00,      
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE1 = 8'h00,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE2 = 8'h80,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE3 = 8'h7F,

	// 串口通信参数
    parameter integer BPS   = 115200,     	// 串口波特率
    parameter integer CLK_F = 50_000_000  	// 系统主频 50MHz
) (
    input  wire clk,
    input  wire rst_n,

    // 控制端
	input  wire uart_en,            // 串口发送开关 
    input  wire ctrl_tick,			// 控制节拍，1ms
    
	// 倒立摆实时状态量 
    input  wire signed [WIDTH_DATA-1:0] pos_pend,       // 摆杆当前角度
    input  wire signed [WIDTH_DATA-1:0] vel_pend,       // 摆杆角速度
    input  wire signed [WIDTH_DATA-1:0] pos_arm,        // 水平臂位置
    input  wire signed [WIDTH_DATA-1:0] vel_arm,        // 水平臂线速度
    input  wire signed [12:0] duty_signed,      		// 占空比力矩

    // 物理层引脚
    output wire tx_data_out       // 串口发送管脚
);

	// FIFO 写侧连线
	wire [7:0] w_data;
	wire w_en;
	wire full_sig;

	// FIFO 读侧连线
	wire [7:0] r_data;
	wire r_en;
	wire empty_sig;

	// 串口发送器握手连线
	wire [7:0] tx_data;		// 串口要发送数据
	wire tx_en;				// 串口发送使能
	wire tx_done_sig;		// 串口发送完成标志

	tx_fifo_w # (
		.WIDTH_DATA(WIDTH_DATA),
		.WIDTH_BYTE(WIDTH_BYTE),
		.DECIM_N(DECIM_N),
		.TAIL_BYTE0 (TAIL_BYTE0),
        .TAIL_BYTE1 (TAIL_BYTE1),
        .TAIL_BYTE2 (TAIL_BYTE2),
        .TAIL_BYTE3 (TAIL_BYTE3)
	) tx_fifo_w_inst (
		.clk(clk),
		.rst_n(rst_n),
		.ctrl_tick(ctrl_tick),
		.pos_pend(pos_pend),
		.vel_pend(vel_pend),
		.pos_arm(pos_arm),
		.vel_arm(vel_arm),
		.duty_signed(duty_signed),
		.full_sig(full_sig),
		.w_data(w_data),
		.w_en(w_en)
	);

	fifo_sc u_fifo (
		.Data        (w_data),      // input  [7:0]  写入数据
		.Reset       (~rst_n),      // input        注意：高云复位默认高有效，低电平复位需取反
		.Clk         (clk),         // input        50MHz 系统时钟
		.WrEn        (w_en),        // input        写使能 (高有效)
		.RdEn        (r_en),        // input        读使能 (高有效)
		.Q           (r_data),      // output [7:0]  读出数据
		.Empty       (empty_sig),   // output       FIFO 空指示
		.Full        (full_sig)     // output       FIFO 满指示
	);

	tx_fifo_r # (
		.WIDTH_BYTE(WIDTH_BYTE)
	) tx_fifo_r_inst (
		.clk(clk),
		.rst_n(rst_n),
		.uart_en(uart_en),
		.r_data(r_data),
		.r_en(r_en),
		.empty_sig(empty_sig),
		.tx_data(tx_data),
		.tx_done_sig(tx_done_sig),
		.tx_en(tx_en)
	);

	// 串口发送器
	uart_tx # (
		.WIDTH_BYTE(WIDTH_BYTE),
		.BPS(BPS),
		.CLK_F(CLK_F)
	)uart_tx_inst (
		.clk(clk),
		.rst_n(rst_n),
		.tx_en(tx_en),
		.tx_data(tx_data),
		.tx_done_sig(tx_done_sig),
		.tx_data_out(tx_data_out)
	);

endmodule