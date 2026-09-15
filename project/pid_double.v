module pid_double #(
    // 垂直摆杆角度环参数 (纯 PD，KI 恒为 0)
    parameter signed [15:0] KP_ANGLE = 16'sd1200,
    parameter signed [15:0] KD_ANGLE = 16'sd350,
    // 水平旋转臂位置环参数 (微弱 PID)
    parameter signed [15:0] KP_POS   = 16'sd50,
    parameter signed [15:0] KI_POS   = 16'sd2,
    parameter signed [15:0] KD_POS   = 16'sd80,
    parameter signed [31:0] MAX_I_POS = 32'sd2000,
    parameter signed [31:0] MIN_I_POS = -32'sd2000
) (
    input  wire clk,
    input  wire rst_n,
    //输入使能
    input  wire pid_en,
    //输入控制节拍
    input  wire angle_active, // 500Hz 控制主节拍 (2ms)
    // 垂直摆杆状态
    input  wire signed [16:0] angle_deg,
    input  wire signed [16:0] angle_vel,
    // 水平旋转臂状态
    input  wire signed [31:0] cur_pos,
    input  wire signed [15:0] cur_speed,
    // 最终输出到电机的占空比
    output wire signed [12:0] pid_data
);

// 1. 垂直摆杆角度环 (主控内环，高权限，纯 PD)
wire signed [12:0] pid_angle_out;

pid # (
    .Kp(KP_ANGLE),
    .Ki(16'sd0),
    .Kd(KD_ANGLE),
    .MAX_OUT(13'sd2000),  //占据最大 80% 动态推力
    .MIN_OUT(-13'sd2000),
    .MAX_I(32'sd0),       // Ki=0 时不启用积分，直接给 0
    .MIN_I(32'sd0)
  )
  pid_inst_angle (
    .clk(clk),
    .rst_n(rst_n),
    .pid_en(pid_en),
    .angle_active(angle_active),
    .target(32'sd0),
    .cur({{15{angle_deg[16]}},angle_deg}),
    .diff({{15{angle_vel[16]}}, angle_vel}),
    .pid_data(pid_angle_out)
  );

// 2. 水平旋转臂位置环 (从属外环，低权限，弱补偿)
wire signed [12:0] pid_pos_out;

pid # (
    .Kp(KP_POS),
    .Ki(KI_POS),
    .Kd(KD_POS),
    .MAX_OUT(13'sd500),  //占据最大 20% 动态推力
    .MIN_OUT(-13'sd500),
    .MAX_I(MAX_I_POS),  //积分限幅
    .MIN_I(MIN_I_POS)
  )
  pid_inst_pos (
    .clk(clk),
    .rst_n(rst_n),
    .pid_en(pid_en),
    .angle_active(angle_active),
    .target(32'sd0),
    .cur(cur_pos),
    .diff({{16{cur_speed[15]}}, cur_speed}),
    .pid_data(pid_pos_out)
  );
// 3. 合并输出
wire signed [13:0] total_sum = pid_angle_out + pid_pos_out; //相加可能会产生进位
// 4. 限幅
assign pid_data = (total_sum >  14'sd2500) ?  13'sd2500 : (total_sum < -14'sd2500) ? -13'sd2500 : total_sum[12:0];

endmodule
