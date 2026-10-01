`timescale 1ns/1ps
/*
主控模块
功能：
    1. 协调4个状态
状态：IDLE，LQR，SWING，STOP
*/
module control #(
    parameter integer WIDTH_DATA   = 16,   // 状态位宽
    parameter integer ANGLE_SWITCH = 42    // 约 15度 对应的码值
) (
    input  wire clk,
    input  wire rst_n,

    // 输入
    input  wire key_open,       // 开启工作，结束空闲等待，脉冲
    input  wire stop_sig,       // 停机保护信号，持续高电平
    input  wire calib_done,     // 零点设立完成标志，脉冲
    input  wire signed [WIDTH_DATA-1:0] angle_err,   // 当前垂直摆杆角度

    // 控制信号输出
    output reg  lqr_en,         // 持续高电平
    output reg  swing_en,       // 持续高电平
    output reg  pos_clr,        // 水平臂位置清零信号，脉冲
    output reg  [1:0] state_out // 导出当前状态，用于 LED 观测
);

// 4个状态
localparam integer IDLE  = 2'b00;   // 空闲等待
localparam integer SWING = 2'b01;   // 起摆
localparam integer LQR   = 2'b10;   // LQR平衡
localparam integer STOP  = 2'b11;   // 突变停止

// 起摆 LQR平衡 切换区间
localparam signed [WIDTH_DATA-1:0] SWITCH_POSITIVE =  ANGLE_SWITCH;
localparam signed [WIDTH_DATA-1:0] SWITCH_NEGATIVE = -ANGLE_SWITCH;

// 状态机流程
reg [1:0] state_cur;    // 当前状态
reg [1:0] state_next;   // 下一个状态

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state_cur <= IDLE;
    end else begin
        state_cur <= state_next;
    end
end

// 设立零点完成标志锁存器
// 接收单周期脉冲，并将其锁存为 1 ，后续再次按下按键，只会刷新成 1 并改变零点值
// 后续状态机不能直接使用 calib_done, 因为我们是先设立零点后开启工作，此时零点完成标志已经变成了0，无法使用
reg calib_flag;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        calib_flag <= 1'b0;      // 上电初态：未确立零点
    end else if (calib_done) begin
        calib_flag <= 1'b1;      // 捕获到校准脉冲，立即标记已有零点
    end
end

// 状态切换逻辑
always @(*) begin
    state_next = state_cur; // 默认维持当前状态

    // 全局保护优先：只要在运行中 (SWING 或 LQR) 收到告警信号，立刻无条件切入停机
    if (stop_sig && (state_cur == SWING || state_cur == LQR)) begin
        state_next = STOP;
    end else begin
        case (state_cur)
            // 空闲状态：零点校准完毕且按下启动按键，才进入起摆
            IDLE: begin
                if (calib_flag && key_open) begin
                    state_next = SWING;
                end
            end

            // 起摆状态：摆杆摆入倒立小角度窗口内，转交 LQR 算法接管
            SWING: begin
                if (angle_err >= SWITCH_NEGATIVE && angle_err <= SWITCH_POSITIVE) begin
                    state_next = LQR;
                end
            end

            // 平衡状态：正常保持，若失稳跌倒或超程，切入 STOP
            LQR: begin
                state_next = LQR;
            end

            // 停机保护状态：满足故障解除 (!stop_sig) 且 人工再次按键，才重置回 IDLE
            STOP: begin
                if (!stop_sig && key_open) begin
                    state_next = IDLE;
                end
            end
            default: state_next = IDLE;
        endcase
    end
end

// 进入 LQR 的第一个周期时，产生 pos_clr(单周期脉冲)
// 此时 state_next 为 LQR，而 state_cur 还不是 LQR，说明是第一次进入 LQR 状态
wire enter_lqr_pulse = (state_next == LQR) && (state_cur != LQR);

// 输出寄存器化
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lqr_en    <= 1'b0;
        swing_en  <= 1'b0;
        pos_clr   <= 1'b0;
        state_out <= IDLE;
    end else begin
        state_out <= state_next;
        pos_clr   <= enter_lqr_pulse; // 仅在进入 LQR 的第 1 个时钟周期拉高 20ns
        case (state_next) // 状态一切换，输出就改变 
            IDLE: begin
                lqr_en   <= 1'b0;
                swing_en <= 1'b0;
            end

            SWING: begin
                lqr_en   <= 1'b0;
                swing_en <= 1'b1; // 仅开启起摆驱动
            end

            LQR: begin
                lqr_en   <= 1'b1; // 仅开启 LQR 算法
                swing_en <= 1'b0;
            end

            STOP: begin
                lqr_en   <= 1'b0; // 电机双关断，切断所有驱动输出
                swing_en <= 1'b0;
            end

            default: begin
                lqr_en   <= 1'b0;
                swing_en <= 1'b0;
            end
        endcase
    end
end

endmodule //control