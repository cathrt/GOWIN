`timescale 1ns / 1ps
/*
四状态旋转倒立摆 LQR 控制器
公式：
    u = -K * x 
      = K1*(target_arm - pos_arm)   - K2*vel_arm 
      + K3*(target_pend - pos_pend) - K4*vel_pend
1. 我们的垂直摆杆输入的角度因为是浮点数，所以要放大2^16倍；我们的参数可能也是浮点数，因此也要放大2^16倍；因此我们最后需要缩小2^32倍，即右移32位
2. 我们的水平摆杆输入的是位置（1代表2Π/1040），因此我们的参数要*2Π/1040 在放大2^16倍，与垂直摆杆一致，最终输出右移16位
*/
module lqr #(
    parameter WIDTH_DATA = 16,          // 数据总位宽
    // Q格式
    parameter ARM_Q  = 0,           // 水平臂输入：编码器计数（整数）
    parameter PEND_Q = 16,          // 垂直摆输入：Q16
    parameter ARM_K_Q  = 16,        // 水平增益：Q16（已含 2π/1040 换算）
    parameter PEND_K_Q = 16,         // 垂直增益：Q16
    // LQR 状态反馈增益系数 (定点化表示 = 实际物理浮点数 * 2^16)
    parameter signed [WIDTH_DATA-1:0] K1 = 32'sd65536,   // 水平臂位置增益 (k1)
    parameter signed [WIDTH_DATA-1:0] K2 = 32'sd32768,   // 水平臂速度阻尼增益 (k2)
    parameter signed [WIDTH_DATA-1:0] K3 = 32'sd327680,  // 垂直摆杆角度刚度增益 (k3)
    parameter signed [WIDTH_DATA-1:0] K4 = 32'sd65536    // 垂直摆杆角速度阻尼增益 (k4)
) (
    input  wire clk,
    input  wire rst_n,
    input  wire lqr_en,     //lqr开启脉冲，持续高电平
    // 水平摆臂状态输入 (来自编码器计数及T法测速)
    input  wire signed [WIDTH_DATA-1:0] target_arm,      // 水平臂目标位置 0，即回中点
    input  wire signed [WIDTH_DATA-1:0] pos_arm,         // 水平臂当前测量位置，即角度
    input  wire signed [WIDTH_DATA-1:0] vel_arm,         // 水平臂当前角速度
    // 垂直摆杆状态输入 (来自 LESO )
    input  wire signed [WIDTH_DATA-1:0] target_pend,     // 垂直摆杆目标角度
    input  wire signed [WIDTH_DATA-1:0] pos_pend,        // 垂直摆杆滤波角度，即 LESO 输出的 z1
    input  wire signed [WIDTH_DATA-1:0] vel_pend,        // 垂直摆杆估计角速度，即 LESO 输出的 z2
    // 输出
    output reg  signed [WIDTH_DATA-1:0] u_lqr,           // 输出 LQR 基础控制量 (定点数)
    output reg  sat_pos,    // 正向饱和标志
    output reg  sat_neg     // 反向饱和标志
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
    reg signed [MULT_WIDTH-1:0] mult_arm_p, mult_arm_d;
    reg signed [MULT_WIDTH-1:0] mult_pend_p, mult_pend_d;
    reg en_s1;  // 经过1拍的使能信号
    // 将其放入流水中，使能信号一起跟着流水，不需要复位信号
    always @(posedge clk) begin
        mult_arm_p  <= K1 * err_arm;
        mult_arm_d  <= K2 * vel_arm;
        mult_pend_p <= K3 * err_pend;
        mult_pend_d <= K4 * vel_pend;
        en_s1 <= lqr_en;
    end

    // 水平垂直按自己的Q格式进行移位
    wire signed [MULT_WIDTH-1:0] sum_arm  = (mult_arm_p - mult_arm_d) >>> (ARM_Q + ARM_K_Q);
    wire signed [MULT_WIDTH-1:0] sum_pend = (mult_pend_p - mult_pend_d) >>> (PEND_Q + PEND_K_Q);

    //
    wire signed [MULT_WIDTH-1:0] sum = sum_arm + sum_pend;

    // 输出寄存器化与饱和截断保护
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u_lqr <= {WIDTH_DATA{1'b0}};
            sat_pos <= 1'b0;
            sat_neg <= 1'b0;
        end else if(en_s1) begin
            // 防溢出饱和限幅，超出 32 位表示范围时强行钳位在极限值
            if (sum > MAX_POS) begin
                u_lqr <= MAX_POS;
                sat_pos <= 1'b1;
                sat_neg <= 1'b0;
            end else if (sum < MIN_NEG) begin
                u_lqr <= MIN_NEG;
                sat_pos <= 1'b0;
                sat_neg <= 1'b1;
            end else begin
                u_lqr <= sum[WIDTH_DATA-1:0];
                sat_pos <= 1'b0;
                sat_neg <= 1'b0;
            end
        end else if(!en_s1) begin
            u_lqr <= {WIDTH_DATA{1'b0}};
            sat_pos <= 1'b0;
            sat_neg <= 1'b0;
        end
    end

endmodule