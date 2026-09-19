/*
PID处理数据周期为2ms，一共要发送的数据为96位，16字节，采用115200bps
若采用9600bps，发送16个字节需要约10ms的时间，这会导致数据撕裂
采用115200bps，发送16个字节需要约 1ms的时间，完全可以
*/
module uart_tx_top#(
	parameter WIDTH_DATA = 32,
	parameter WIDTH_BYTE = 8,
    parameter integer DECIM_N     = 5,          // 500Hz / 5 = 100Hz (每 10ms 打包一次)
    parameter [7:0]   TAIL_BYTE0  = 8'h00,      // VOFA+ 协议帧尾
    parameter [7:0]   TAIL_BYTE1  = 8'h00,
    parameter [7:0]   TAIL_BYTE2  = 8'h80,
    parameter [7:0]   TAIL_BYTE3  = 8'h7F,
    parameter integer BPS         = 115200,     // 串口波特率
    parameter integer CLK_F       = 50_000_000  // 系统主频 50MHz
) (
    input  wire clk,
    input  wire rst_n,
    // 上位机传输开关与控制节拍
    input  wire               uart_en,          // 遥测总开关 (1: 允许发送; 0: 静默)
    input  wire               angle_avtive,     // 500Hz 控制主节拍脉冲 (2ms)
    // 倒立摆实时状态量 (补码原生数据)
    input  wire signed [16:0] angle_deg,        // 摆杆当前角度
    input  wire signed [16:0] angle_vel,        // 摆杆角速度
    input  wire signed [31:0] cur_pos,          // 水平臂位置
    input  wire signed [15:0] cur_speed,        // 水平臂线速度
    input  wire signed [12:0] duty_signed,      // 占空比力矩
    // 物理层引脚
    output wire               tx_data_out       // FPGA 物理串口发送管脚
);
/*
//我们按5分频进行打包数据
localparam  integer DECIM_N     = 5;          //采样周期的5分频，即2*5=10MS
localparam  [7:0]   TAIL_BYTE0  = 8'h00;      // VOFA+ 协议帧尾
localparam  [7:0]   TAIL_BYTE1  = 8'h00;
localparam  [7:0]   TAIL_BYTE2  = 8'h80;
localparam  [7:0]   TAIL_BYTE3  = 8'h7F;
//串口
localparam  BPS   = 17'd115200;
localparam  CLK_F = 26'd50_000_000;
*/

  // FIFO 写侧连线
  wire [7:0] w_data;
  wire       w_en;
  wire       full_sig;
  // FIFO 读侧连线
  wire [7:0] r_data;
  wire       r_en;
  wire       empty_sig;
  // 串口发送器握手连线
  wire [7:0] tx_data;
  wire       tx_en;
  wire       tx_done_sig;

fifo_w_control # (
    .WIDTH_DATA(WIDTH_DATA),
    .WIDTH_BYTE(WIDTH_BYTE),
    .DECIM_N(DECIM_N),
    .TAIL_BYTE0(TAIL_BYTE0),
    .TAIL_BYTE1(TAIL_BYTE1),
    .TAIL_BYTE2(TAIL_BYTE2),
    .TAIL_BYTE3(TAIL_BYTE3)
  )
  fifo_w_control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .angle_avtive(angle_avtive),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .cur_pos(cur_pos),
    .cur_speed(cur_speed),
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

fifo_r_control  fifo_r_control_inst (
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

  uart_tx # (
    .BPS(BPS),
    .CLK_F(CLK_F)
  )
  uart_tx_inst (
    .clk(clk),
    .rst_n(rst_n),
    .tx_en(tx_en),
    .tx_data(tx_data),
    .tx_done_sig(tx_done_sig),
    .tx_data_out(tx_data_out)
  );

endmodule