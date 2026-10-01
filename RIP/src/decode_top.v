module decode_top #(
    parameter integer WIDTH_DATA = 16,
	parameter integer KEY_NUM 	 = 4,
	parameter integer CLK_F 	 = 50_000_000,
	parameter integer CTRL_F 	 = 1_000
) (
    input  wire clk,
    input  wire rst_n,

    // 输入
    input  wire encode_a,
    input  wire encode_b,
    input  wire [KEY_NUM-1:0] key_in,

    // 输出
    output wire motor_dir,  //电机转向，用于调式
    output wire signed [WIDTH_DATA-1:0] pos_arm,    // 当前水平臂位置
    output wire signed [WIDTH_DATA-1:0] vel_arm,    // 当前水平臂速度
    
    // 关闭电机
    output wire pwm_out,
    output wire ain1,
    output wire ain2
);

wire [KEY_NUM-1:0] key_pulse;
wire ctrl_tick;

// 按键模块
key # (
    .KEY_NUM(KEY_NUM)
  )
  key_inst (
    .clk(clk),
    .rst_n(rst_n),
    .key_in(key_in),
    .key_pulse(key_pulse)
  );

// 1ms节拍产生器
ctrl_clk # (
    .CLK_F(CLK_F),
    .CTRL_F(CTRL_F)
  )
  ctrl_clk_inst (
    .clk(clk),
    .rst_n(rst_n),
    .ctrl_tick(ctrl_tick)
  );

// 电机编码器模块
decode # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  decode_inst (
    .clk(clk),
    .rst_n(rst_n),
    .pos_clr(key_pulse[0]),
    .ctrl_tick(ctrl_tick),
    .encode_a(encode_a),
    .encode_b(encode_b),
    .motor_dir(motor_dir),
    .pos_arm(pos_arm),
    .vel_arm(vel_arm)
  );

// 关闭电机
assign pwm_out = 1'b0;
assign ain1 = 1'b0;
assign ain2 = 1'b0;

endmodule