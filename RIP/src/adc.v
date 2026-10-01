`timescale 1ns / 1ps
// ADC 顶层模块
module adc #(
    parameter integer WIDTH_DATA     = 16,        // 状态位宽，位置 Q16.0, 速度 Q8.8
    parameter integer DEFAULT_OFFSET = 512,       // 默认零位偏置 (10位ADC中心值 0~1023)
    parameter integer LPF_SHIFT      = 2          // 角速度一阶低通滤波系数位移量 (2: 1/4权重)
) (
    input  wire clk,                  // 50MHz 主系统时钟
    input  wire rst_n,

    // 控制端
    input  wire ctrl_tick,             // 控制环路周期节拍脉冲 (如 1ms 脉冲)
    input  wire key_calib,             // SW1 按键消抖后的单周期脉冲 (高有效)

    // 3PA1030 芯片外部硬件物理引脚
    output wire ad_oe,                 // 3PA1030 三态输出使能 (常低 1'b0)
    output wire ad_clk,                // 驱动外部 3PA1030 芯片的时钟引脚
    input  wire [9:0]  ad_data,        // 外部 10 位并行数据输入管脚

    // 输出 Q16.0 格式
    output wire signed [WIDTH_DATA-1:0] target_pend, // 摆杆垂直平衡零位码值
    output wire signed [WIDTH_DATA-1:0] pos_pend,    // 摆杆当前角度
    output wire signed [WIDTH_DATA-1:0] vel_pend,    // 摆杆平滑角速度
    output wire signed [WIDTH_DATA-1:0] angle_err,   // 摆杆角度动态偏差，检测用
    output wire calib_done   						 // 零位校准完成标志，单脉冲
);
	wire clk_adc;
	assign ad_oe = 1'b0;			// 一直常低，即一直开启
	assign ad_clk = clk_adc;		// ADC 的12.5MHz 时钟输出
	
  // ADC 时钟生成模块
	adc_clk  adc_clk_inst (
    .clk(clk),
    .rst_n(rst_n),
    .clk_adc(clk_adc)
  );


    wire [WIDTH_DATA-1:0] adc_data_flt; // ADC 采样滤波后的数据
    wire adc_valid;        				// ADC 采样有效标志

    // ADC 采样驱动模块
    adc_driver  adc_driver_inst (
    .clk(clk),
    .clk_adc(clk_adc),
    .rst_n(rst_n),
    .ad_data(ad_data),
    .adc_data_flt(adc_data_flt),
    .adc_valid(adc_valid)
  );

    // ADC 姿态解析模块
    adc_state # (
    .WIDTH_DATA(WIDTH_DATA),
    .DEFAULT_OFFSET(DEFAULT_OFFSET),
    .LPF_SHIFT(LPF_SHIFT)
  )
	adc_state_inst (
    .clk(clk),
    .rst_n(rst_n),
    .ctrl_tick(ctrl_tick),
    .adc_data_flt(adc_data_flt),
    .adc_valid(adc_valid),
    .key_calib(key_calib),
    .target_pend(target_pend),
    .pos_pend(pos_pend),
    .vel_pend(vel_pend),
    .angle_err(angle_err),
    .calib_done(calib_done)
  );

   

endmodule