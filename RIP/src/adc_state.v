`timescale 1ns/1ps
/*
角速度生成模块
功能描述: 垂直摆杆姿态与角速度解算
输入输出:
    - 输入 adc_driver 的平滑码值 adc_data_flt (Q16.0) 与更新脉冲 adc_valid
    - 接收按键脉冲 key_calib 触发 SW1 零位自整定锁存
    - 依据 tick_1ms (1kHz) 节拍完成角速度差分与一阶低通滤波
    - 输出标准 Q16.0 格式的角度状态量与角速度，供 lqr.v 直接使用
*/
module adc_state #(
    parameter integer WIDTH_DATA     = 16,        // 状态位宽，位置 Q16.0, 速度 Q8.8
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
    output reg  signed [WIDTH_DATA-1:0] pos_pend,    // 摆杆当前角度码值
    output wire signed [WIDTH_DATA-1:0] vel_pend,    // 摆杆平滑角速度
    output wire signed [WIDTH_DATA-1:0] angle_err,   // 摆杆当前角度偏差 (pos - offset)
    output reg  calib_done   // 零位校准完成标志，单脉冲
);

    // 1. 零位偏置校准锁存 (SW1 触发)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_pend <= DEFAULT_OFFSET; // 默认复位在 零点
            calib_done  <= 1'b0;
        end else if (key_calib) begin
            // 按键按下瞬间，锁存当前 ADC 真实滤波码值作为倒立平衡零点
            target_pend <= $signed(adc_data_flt);
            calib_done  <= 1'b1;
        end else begin
            calib_done  <= 1'b0; // 自动清零，形成标准单周期高脉冲
        end
    end

    // 2. 内部保持高速跟踪
    reg signed [WIDTH_DATA-1:0] cur_pos_pend;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_pos_pend <= DEFAULT_OFFSET;
        end else if (adc_valid) begin
            // 每接收到一个数据进行更新
            cur_pos_pend <= $signed(adc_data_flt);
        end
    end

    // 3. 1ms 控制节拍锁存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_pend <= DEFAULT_OFFSET;
        end else if (ctrl_tick) begin
            pos_pend <= cur_pos_pend; // 只在 1ms 起始点锁存数据
        end
    end

    // 4. 计算角度偏差：当前 - 目标
    assign angle_err = pos_pend - target_pend;

    // Q16.8 定点滤波解算 (消灭死区)
    localparam integer FRAC_BITS = 8;     // 保留 8 位小数精度
    localparam integer ACC_WIDTH = WIDTH_DATA + FRAC_BITS; // 24 位总累加位宽

    // 5. 1ms 节拍微分求角速度与一阶低通滤波 (IIR)
    // 公式：
    //   原始微分: vel_raw = pos_pend[k] - pos_pend[k-1]
    //   滤波递推: vel_pend <= vel_pend + (vel_raw - vel_pend) / 4
    reg  signed [WIDTH_DATA-1:0] pos_pend_prev; // 保存前一拍 1ms 的位置
    reg  signed [ACC_WIDTH-1:0]  vel_acc;       // Q16.8 内部高精度速度累加器

    // 瞬时微分差值 (整数)
    wire signed [WIDTH_DATA-1:0] vel_raw = pos_pend - pos_pend_prev;

    // 扩展为 Q16.8 格式 (等效于乘以 256)
    wire signed [ACC_WIDTH-1:0]  vel_raw_q8 = {vel_raw, {FRAC_BITS{1'b0}}};

    // 高精度差分误差
    wire signed [ACC_WIDTH-1:0]  diff_q8 = vel_raw_q8 - vel_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_pend_prev <= DEFAULT_OFFSET;
            vel_acc       <= {ACC_WIDTH{1'b0}};
        end else if (ctrl_tick) begin
            // 1. 锁存前一拍历史角度
            pos_pend_prev <= pos_pend;

            // 2. Q16.8 高精度累加更新 (小数位吸收微小增量，彻底消灭死区)
            vel_acc <= vel_acc + (diff_q8 >>> LPF_SHIFT);
        end
    end

    // 6. 输出 Q8.8 数据，高位全为0
    assign vel_pend = vel_acc[15:0];

endmodule