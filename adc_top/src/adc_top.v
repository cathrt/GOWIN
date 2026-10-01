module adc_top #(
    parameter integer CLK_F  = 50_000_000,
    parameter integer CTRL_F = 1_000,
    parameter integer KEY_NUM = 4,
    parameter integer WIDTH_DATA     = 16,       // 3PA1030 为 10 位数据
    parameter integer DEFAULT_OFFSET = 757,      // 摆杆垂直朝下初始零位标定值
    parameter integer LPF_SHIFT      = 3         // 低通滤波平滑系数 (2^3 = 8 阶滑动滤波)
)(
    // 基础硬件引脚
    input  wire clk,
    input  wire rst_n,
    input  wire [3:0]key_in,      // 角度零点校准按键 [0]

    // 3PA1030 芯片物理接口 (与 CST 绑定)
    input  wire [9:0] ad_data,        // ADC 并行 10 位数据输入 (D0~D9)
    output wire                  ad_clk,         // 输出给 ADC 芯片的采样时钟
    output wire                  ad_oe,          // ADC 输出使能 (通常接 0 低电平有效)

    // 状态与姿态观测输出 (供后续 LQR/PID 控制器读取或 GAO 抓取波形)
    output wire calib_done,     // 零位校准完成标志
    output wire signed [WIDTH_DATA-1:0] target_pend,    // 摆杆垂直平衡零位码值
    output wire signed [WIDTH_DATA-1:0] pos_pend,       // 滤波后摆杆实时位置/角度
    output wire signed [WIDTH_DATA-1:0] vel_pend,       // 摆杆实时角速度 (微分)
    output wire signed [WIDTH_DATA-1:0] angle_err,       // 角度偏差 (pos_pend - target_pend)
    
    //关闭电机
    output wire pwm_out,
    output wire ain1,
    output wire ain2
);

wire [3:0] key_pulse;
wire clk_adc;
wire clk_sys;
wire ctrl_tick;

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

//ADC时钟
Gowin_rPLL Gowin_rPLL_inst(
        .clkout(clk_sys), //output clkout
        .clkoutd(clk_adc), //output clkoutd
        .clkin(clk) //input clkin
    );
//ADC模块
adc # (
    .WIDTH_DATA(WIDTH_DATA),
    .DEFAULT_OFFSET(DEFAULT_OFFSET),
    .LPF_SHIFT(LPF_SHIFT)
  )
  adc_inst (
    .clk(clk_sys),
    .clk_adc(clk_adc),
    .rst_n(rst_n),
    .ctrl_tick(ctrl_tick),
    .key_calib(key_pulse[0]),
    .ad_oe(ad_oe),
    .ad_clk(ad_clk),
    .ad_data(ad_data),
    .target_pend(target_pend),
    .pos_pend(pos_pend),
    .vel_pend(vel_pend),
    .angle_err(angle_err),
    .calib_done(calib_done)
  );

// 关闭电机
assign pwm_out = 1'b0;
assign ain1 = 1'b0;
assign ain2 = 1'b0;

endmodule