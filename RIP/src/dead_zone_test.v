`timescale 1ns/1ps
/*
死区检测模块
功能：通过阶梯递增占空比，自动探测电机克服静摩擦力的临界死区
*/
module dead_zone_test #(
    parameter integer WIDTH_DATA = 16,
    parameter integer DUTY_MAX   = 2500,        // 20kHz PWM 满幅计数值
    parameter integer STEP_TIME  = 20           // 步进间隔：20 个 1ms (即每 20ms 加 1 占空比，消除机械惯性滞后)
) (
    input  wire clk,
    input  wire rst_n,
    
    // 输入
    input  wire ctrl_tick,                      // 1ms 采样使能脉冲
    input  wire key_dead,                       // 按键启动/复位测试脉冲
    input  wire signed [WIDTH_DATA-1:0] pos_arm,// 水平臂当前编码器位置

    // 输出
    output reg  signed [WIDTH_DATA-1:0] duty_test,     // 供给电机驱动的 PWM 测试输出
    output reg  signed [WIDTH_DATA-1:0] dead_zone_val, // 测得的死区绝对值
    output reg  test_done                              // 测试完成标志
);

    // 状态机定义
    localparam STATE_IDLE = 2'd0;
    localparam STATE_SCAN = 2'd1;
    localparam STATE_DONE = 2'd2;

    reg [1:0] state;
    reg signed [WIDTH_DATA-1:0] pos_start; // 记录测试起点位置
    reg [7:0] step_cnt;                    // 步进降频计数器

    // 差分位移计算
    wire signed [WIDTH_DATA-1:0] pos_diff = pos_arm - pos_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= STATE_IDLE;
            duty_test     <= 'd0;
            dead_zone_val <= 'd0;
            test_done     <= 1'b0;
            pos_start     <= 'd0;
            step_cnt      <= 8'd0;
        end else begin
            case (state)
                // 0: 空闲等待启动
                STATE_IDLE: begin
                    test_done <= 1'b0;
                    duty_test <= 'd0;
                    step_cnt  <= 8'd0;
                    if (key_dead) begin
                        pos_start <= pos_arm; // 锁存当前起始位置
                        state     <= STATE_SCAN;
                    end
                end

                // 1: 阶梯递增扫描死区
                STATE_SCAN: begin
                    // 判定起步条件：编码器有效位移超过 3 个码值（绝对值 >= 3）
                    if ((pos_diff >= 16'sd3) || (pos_diff <= -16'sd3)) begin
                        dead_zone_val <= duty_test; // 成功捕获死区阈值！
                        duty_test     <= 'd0;       // 立即封波断电，防止机械臂加速甩动
                        test_done     <= 1'b1;
                        state         <= STATE_DONE;
                    end 
                    // 在 1ms 脉冲节拍下执行阶梯爬升
                    else if (ctrl_tick) begin
                        if (step_cnt >= STEP_TIME - 1) begin
                            step_cnt <= 8'd0;
                            // 满量程未起转保护
                            if (duty_test >= DUTY_MAX) begin
                                duty_test <= 'd0;
                                state     <= STATE_DONE;
                            end else begin
                                duty_test <= duty_test + 16'sd1; // 每 20ms 平稳加 1
                            end
                        end else begin
                            step_cnt <= step_cnt + 1'b1;
                        end
                    end
                end

                // 2: 测试完成并锁定结果
                STATE_DONE: begin
                    duty_test <= 'd0;
                    // 再次按下按键复位回到待命状态
                    if (key_dead) begin
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule