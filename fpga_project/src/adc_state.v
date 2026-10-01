`timescale 1ns / 1ps
/*
角速度生成模块
功能描述: 垂直摆杆姿态与角速度解算模块
输入输出:
    - 输入 adc_driver 的平滑码值 adc_data_flt (Q16.0) 与更新脉冲 adc_valid
    - 接收按键脉冲 key_calib 触发 SW1 零位自整定锁存
    - 依据 tick_1ms (1kHz) 节拍完成角速度差分与一阶低通滤波
    - 输出标准 Q16.0 格式的角度状态量与角速度，供 lqr.v 直接使用
*/
module adc_state #(
    parameter integer WIDTH_DATA     = 16,        // 状态位宽 (Q16.0)
    parameter integer DEFAULT_OFFSET = 512,       // 默认零位偏置 (10位ADC中心值 0~1023)
    parameter integer LPF_SHIFT      = 2          // 角速度低通滤波系数位移量 (2: 1/4权重, 1: 1/2权重)
) (
    input  wire clk,           
    input  wire rst_n,            
    input  wire ctrl_tick,     // 1ms 控制周期脉冲

    // 输入
    input  wire [WIDTH_DATA-1:0] adc_data_flt,    // 16 拍滑动滤波后的 ADC 码值
    input  wire adc_valid,                        // ADC 数据更新脉冲 (每 80ns 触发一次)

    // 校准控制引脚
    input  wire key_calib,       // SW1 按键消抖后的单周期脉冲 (高有效)

    // 输出 Q16.0 格式
    output reg  signed [WIDTH_DATA-1:0] target_pend, // 摆杆平衡零位目标码值 (zero_offset)
    output reg  signed [WIDTH_DATA-1:0] pos_pend,    // 摆杆当前滤波角度码值
    output reg  signed [WIDTH_DATA-1:0] vel_pend,    // 摆杆平滑角速度差分量
    output reg  signed [WIDTH_DATA-1:0] angle_err,   // 摆杆当前角度偏差 (pos - offset)
    output reg  calib_done   // 零位校准完成标志，持续高脉冲
);

    // 第一部分：零位偏置校准锁存 (SW1 触发)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_pend <= DEFAULT_OFFSET; // 默认复位在 512
            calib_done  <= 1'b0;
        end else if (key_calib) begin
            // 按键按下瞬间，锁存当前 ADC 真实滤波码值作为倒立平衡零点
            target_pend <= $signed(adc_data_flt);
            calib_done  <= 1'b1;
        end
    end

    // 第二部分：实时角度追踪与偏差计算
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_pend  <= DEFAULT_OFFSET;
            angle_err <= {WIDTH_DATA{1'b0}};
        end else if (adc_valid) begin
            // 只要底层 ADC 吐出新鲜数据，立即刷新当前姿态
            pos_pend  <= $signed(adc_data_flt);
            // 角度偏差 = 当前值 - 零位偏置
            angle_err <= $signed(adc_data_flt) - target_pend;
        end
    end

    // 第三部分：1ms 节拍微分求角速度与一阶低通滤波 (IIR)
    // 公式：
    //   1. 原始微分: vel_raw = pos_pend[k] - pos_pend[k-1]
    //   2. 滤波递推: vel_pend <= vel_pend + (vel_raw - vel_pend) / 4
    reg signed [WIDTH_DATA-1:0] pos_pend_prev; // 保存上一拍 1ms 的角度值

    wire signed [WIDTH_DATA-1:0] vel_raw = pos_pend - pos_pend_prev;
    // 滤波动态误差
    wire signed [WIDTH_DATA-1:0] vel_diff = vel_raw - vel_pend;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_pend_prev <= DEFAULT_OFFSET;
            vel_pend      <= {WIDTH_DATA{1'b0}};
        end else if (ctrl_tick) begin
            // 1. 锁存前一拍的历史角度
            pos_pend_prev <= pos_pend;

            // 2. 算术右移实现一阶惯性滤波 (消除差分引起的高频抖动)
            vel_pend <= vel_pend + (vel_diff >>> LPF_SHIFT);
        end
    end

endmodule