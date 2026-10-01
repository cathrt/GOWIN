`timescale 1ns / 1ps
/*
四状态旋转倒立摆 LQR 控制器
公式：
    u = -K * x 
      = K1*(target_arm - pos_arm)   - K2*vel_arm 
      + K3*(target_pend - pos_pend) - K4*vel_pend
    我们的 K_ARM 吸收了 360/1040 度 和 占空比与实际电压的比例 2500/12
          K_PEND 吸收了 345/1024 度 和 占空比与实际电压的比例 2500/12
*/
module lqr #(
    parameter integer WIDTH_DATA = 16,              // 状态输入位宽 (Q16.0)
    parameter integer WIDTH_K    = 32,              // 增益参数位宽 (Q16.16)
    parameter integer SHIFT_Q    = 16,              // 定点数还原右移位数 (Q16.16 -> 纯整数)
    parameter integer PWM_PERIOD   = 2500           // 20kHz PWM 最大满幅计数值
) (
    input  wire clk, 
    input  wire rst_n,
    input  wire lqr_en,     // LQR 运行使能 (高电平开启)

    // 水平臂状态输入, Q16.0
    input  wire signed [WIDTH_DATA-1:0] target_arm,  // 水平臂目标位置 (通常为 0)
    input  wire signed [WIDTH_DATA-1:0] pos_arm,     // 水平臂实时脉冲
    input  wire signed [WIDTH_DATA-1:0] vel_arm,     // 水平臂脉冲速度

    // 垂直摆杆状态输入, Q16.0
    input  wire signed [WIDTH_DATA-1:0] target_pend, // 垂直摆杆目标角度偏置 (zero_offset)
    input  wire signed [WIDTH_DATA-1:0] pos_pend,    // 垂直摆杆实时码值
    input  wire signed [WIDTH_DATA-1:0] vel_pend,    // 垂直摆杆角速度码值

    // LQR 增益输入 (Q16.16)
    input  wire signed [WIDTH_K-1:0]    k1,          // 水平臂位置增益
    input  wire signed [WIDTH_K-1:0]    k2,          // 水平臂速度阻尼
    input  wire signed [WIDTH_K-1:0]    k3,          // 垂直摆杆角度刚度
    input  wire signed [WIDTH_K-1:0]    k4,          // 垂直摆杆角速度阻尼

    // 控制输出
    output reg  signed [WIDTH_DATA-1:0] u_lqr,       // 输出到 PWM 模块的带符号计数值
    output reg  sat_pos,                             // 正向饱和标志
    output reg  sat_neg                              // 反向饱和标志
);
    // 内部自动推导带符号的正负极限参数
    localparam signed [WIDTH_DATA-1:0] PWM_MAX =  PWM_PERIOD;
    localparam signed [WIDTH_DATA-1:0] PWM_MIN = -PWM_PERIOD;

    // 16位状态 * 32位增益 = 48位乘积位宽
    localparam integer MULT_WIDTH = WIDTH_DATA + WIDTH_K; 

    // 计算状态偏差
    wire signed [WIDTH_DATA-1:0] err_arm  = target_arm  - pos_arm;
    wire signed [WIDTH_DATA-1:0] err_pend = target_pend - pos_pend;

     // 第一级流水线：完成 4 路并行乘法
    reg signed [MULT_WIDTH-1:0] mult_arm_p;
    reg signed [MULT_WIDTH-1:0] mult_arm_d;
    reg signed [MULT_WIDTH-1:0] mult_pend_p;
    reg signed [MULT_WIDTH-1:0] mult_pend_d;
    reg en_r1;  // 使能信号，要跟着流水线一起打拍，与下一级流水使能同步

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_arm_p  <= {MULT_WIDTH{1'b0}};
            mult_arm_d  <= {MULT_WIDTH{1'b0}};
            mult_pend_p <= {MULT_WIDTH{1'b0}};
            mult_pend_d <= {MULT_WIDTH{1'b0}};
            en_r1 <= 1'b0;
        end else begin
            en_r1 <= lqr_en;    // 使能信号跟着一起打一拍
            if (lqr_en) begin
                mult_arm_p  <= k1 * err_arm;
                mult_arm_d  <= k2 * vel_arm;
                mult_pend_p <= k3 * err_pend;
                // 速度 Q8.8 将其右移 8 位，化成Q16.0
                mult_pend_d <= (k4 * $signed(vel_pend)) >>> 8;
            end else begin
                mult_arm_p  <= {MULT_WIDTH{1'b0}};
                mult_arm_d  <= {MULT_WIDTH{1'b0}};
                mult_pend_p <= {MULT_WIDTH{1'b0}};
                mult_pend_d <= {MULT_WIDTH{1'b0}};
            end
        end
    end

    // 第二级流水线：4 路乘累加、算术移位还原与饱和限幅
    // 累加 4 路分量，预留 2 位防加法溢出
    wire signed [MULT_WIDTH+1:0] sum_acc = (mult_arm_p - mult_arm_d) + (mult_pend_p - mult_pend_d);

    // 算术右移 16 位：精确剥除 Q16.16 的小数部分，还原为物理 PWM 计数值
    wire signed [MULT_WIDTH+1:0] sum_scaled = sum_acc >>> SHIFT_Q;

    // 饱和限幅 与 输出寄存器化
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_lqr   <= {WIDTH_DATA{1'b0}};
            sat_pos <= 1'b0;
            sat_neg <= 1'b0;
        end else if (en_r1) begin
            // PWM 的 20kHz 计数值满量程 [-2500, +2500] 进行限幅
            if (sum_scaled > PWM_MAX) begin 
                u_lqr   <= PWM_MAX;     // 正向超量程
                sat_pos <= 1'b1;
                sat_neg <= 1'b0;
            end else if (sum_scaled < PWM_MIN) begin
                u_lqr   <= PWM_MIN;     // 反向超量程
                sat_pos <= 1'b0;
                sat_neg <= 1'b1;
            end else begin
                // 正常输出
                u_lqr   <= sum_scaled[WIDTH_DATA-1:0];
                sat_pos <= 1'b0;
                sat_neg <= 1'b0;
            end
        end else begin
            // 没接收到使能信号，保持初态
            u_lqr   <= {WIDTH_DATA{1'b0}};
            sat_pos <= 1'b0;
            sat_neg <= 1'b0;
        end
    end

endmodule