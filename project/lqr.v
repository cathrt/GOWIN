`timescale 1ns / 1ps
/*
四状态旋转倒立摆 LQR 控制器
公式：
    u = -K * x 
      = K1*(target_arm - pos_arm)   - K2*vel_arm 
      + K3*(target_pend - pos_pend) - K4*vel_pend
*/
module lqr_4state #(
    parameter WIDTH_DATA = 32,          // 数据总位宽
    parameter Q_SHIFT    = 16,          // 定点数 Q12，即放大
    // LQR 状态反馈增益系数 (定点化表示 = 实际物理浮点数 * 2^Q_SHIFT)
    parameter signed [WIDTH_DATA-1:0] K1 = 32'sd65536,   // 水平臂位置增益 (k1)
    parameter signed [WIDTH_DATA-1:0] K2 = 32'sd32768,   // 水平臂速度阻尼增益 (k2)
    parameter signed [WIDTH_DATA-1:0] K3 = 32'sd327680,  // 垂直摆杆角度刚度增益 (k3)
    parameter signed [WIDTH_DATA-1:0] K4 = 32'sd65536    // 垂直摆杆角速度阻尼增益 (k4)
) (
    input  wire clk,
    input  wire rst_n,
    // 水平摆臂状态输入 (来自编码器计数及T法测速)
    input  wire signed [WIDTH_DATA-1:0] target_arm,      // 水平臂目标位置 0，即回中点
    input  wire signed [WIDTH_DATA-1:0] pos_arm,         // 水平臂当前测量位置，即角度
    input  wire signed [WIDTH_DATA-1:0] vel_arm,         // 水平臂当前角速度
    // 垂直摆杆状态输入 (来自 LESO )
    input  wire signed [WIDTH_DATA-1:0] target_pend,     // 垂直摆杆目标角度
    input  wire signed [WIDTH_DATA-1:0] pos_pend,        // 垂直摆杆滤波角度，即 LESO 输出的 z1
    input  wire signed [WIDTH_DATA-1:0] vel_pend,        // 垂直摆杆估计角速度，即 LESO 输出的 z2
    // 输出
    output reg  signed [WIDTH_DATA-1:0] u_lqr            // 输出 LQR 基础控制量 (定点数)
);
    // 乘法器结果位宽 32位 + 32位 = 64位
    localparam MULT_WIDTH = WIDTH_DATA + WIDTH_DATA; 

    // 32 位有符号数的最大与最小值，用于饱和限幅，防止符号翻转导致电机反转
    localparam signed [WIDTH_DATA-1:0] MAX_POS = {1'b0, {(WIDTH_DATA-1){1'b1}}};  // 最高位为0，其余位为1
    localparam signed [WIDTH_DATA-1:0] MIN_NEG = {1'b1, {(WIDTH_DATA-1){1'b0}}};  // 最高位为1，其余位为0

    // 状态误差计算 (目标值 - 测量值)
    wire signed [WIDTH_DATA-1:0] err_arm  = target_arm  - pos_arm;   // 水平臂偏差
    wire signed [WIDTH_DATA-1:0] err_pend = target_pend - pos_pend;  // 垂直摆杆偏差

    // 各状态分量计算，即PD计算
    wire signed [MULT_WIDTH-1:0] mult_arm_p  = K1 * err_arm;
    wire signed [MULT_WIDTH-1:0] mult_arm_d  = K2 * vel_arm;
    wire signed [MULT_WIDTH-1:0] mult_pend_p = K3 * err_pend;
    wire signed [MULT_WIDTH-1:0] mult_pend_d = K4 * vel_pend;

    // 多状态相加
    wire signed [MULT_WIDTH-1:0] sum_raw = (mult_arm_p - mult_arm_d) + (mult_pend_p - mult_pend_d);

    // 定点数比例还原，即右移 Q_SHIFT 位
    wire signed [MULT_WIDTH-1:0] sum_shifted = sum_raw >>> Q_SHIFT;

    // 输出寄存器化与饱和截断保护
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_lqr <= {WIDTH_DATA{1'b0}};
        end else begin
            // 防溢出饱和限幅，超出 32 位表示范围时强行钳位在极限值
            if (sum_shifted > MAX_POS) begin
                u_lqr <= MAX_POS;
            end else if (sum_shifted < MIN_NEG) begin
                u_lqr <= MIN_NEG;
            end else begin
                u_lqr <= sum_shifted[WIDTH_DATA-1:0];
            end
        end
    end

endmodule