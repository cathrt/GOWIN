//编码器解码模块
module decode #(
	parameter WIDTH_DATA = 16 // 状态位宽 (Q16.0 格式)
) (
      input  wire clk,
      input  wire rst_n,
	  // 控制端
	  input  wire pos_clr,    // 在从起摆转向平衡时清零计数
	  input  wire ctrl_tick,  // 控制环路周期节拍脉冲
      // 输入
      input  wire encode_a,
      input  wire encode_b,
      // 输出
      output wire motor_dir,
      output wire signed [WIDTH_DATA-1:0] pos_arm,
	  output wire signed [WIDTH_DATA-1:0] vel_arm
  );

  wire encode_pulse; 	// 边沿脉冲，电机转一圈产生13*20*4=1040个脉冲

  // 解码同步模块
  decode_sync  decode_sync_inst (
      .clk(clk),
      .rst_n(rst_n),
      .encode_a(encode_a),
      .encode_b(encode_b),
      .encode_pulse(encode_pulse),
      .motor_dir(motor_dir)
    );

  // 位置计数器模块
  decode_cnt # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  decode_cnt_inst (
    .clk(clk),
    .rst_n(rst_n),
    .pos_clr(pos_clr),
    .ctrl_tick(ctrl_tick),
    .encode_pulse(encode_pulse),
    .motor_dir(motor_dir),
    .pos_arm(pos_arm)
  );

  // 角速度模块
  decode_vel # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  decode_speed_inst (
    .clk(clk),
    .rst_n(rst_n),
    .encode_pulse(encode_pulse),
    .motor_dir(motor_dir),
    .vel_arm(vel_arm)
  );

  endmodule