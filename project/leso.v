/*
LESO
*/
module leso #(
    parameter WIDTH_DATA = 32,
    parameter Q_SHIFT    = 16,

    // 定点化观测器参数 (默认以 Ts=2ms, wo=60 rad/s, b0=100 预设)
    parameter signed [WIDTH_DATA-1:0] PARAM_TS_GAIN = 32'sd66,
    parameter signed [WIDTH_DATA-1:0] PARAM_L1      = 32'sd11796,
    parameter signed [WIDTH_DATA-1:0] PARAM_L2      = 32'sd707789,
    parameter signed [WIDTH_DATA-1:0] PARAM_L3      = 32'sd14155776,
    parameter signed [WIDTH_DATA-1:0] PARAM_B0      = 32'sd6554
) (
    input  wire clk,        
    input  wire rst_n,
    input  wire angle_active,      //输入周期节拍，2ms  
    // 输入信号
    input  wire signed [WIDTH_DATA-1:0] y_meas,     // 摆杆实际角度
    input  wire signed [WIDTH_DATA-1:0] u_sum_old,  // 当前作用于电机的控制输入，即占空比
    // 输出信号
    output reg  signed [WIDTH_DATA-1:0] z1_pos,     // 状态估计 1：滤波后的摆杆角度 
    output reg  signed [WIDTH_DATA-1:0] z2_vel,     // 状态估计 2：重构的摆杆角速度 
    output reg  signed [WIDTH_DATA-1:0] z3_dist     // 状态估计 3：总阻力
);

    // 乘法器结果位宽 32位 + 32位 = 64位
    localparam MULT_WIDTH = WIDTH_DATA + WIDTH_DATA;

    // 观测误差计算 （估计值-实际值）
    wire signed [WIDTH_DATA-1:0] err = z1_reg - y_meas;

    // 中间值计算
    wire signed [MULT_WIDTH-1:0] mul_err_l1 = err * PARAM_L1;
    wire signed [MULT_WIDTH-1:0] mul_err_l2 = err * PARAM_L2;
    wire signed [MULT_WIDTH-1:0] mul_err_l3 = err * PARAM_L3;
    wire signed [MULT_WIDTH-1:0] mul_b0 = u_sum_old * PARAM_B0;
    wire signed [MULT_WIDTH-1:0] mul_ts_z2 = z2_reg * PARAM_TS_GAIN;
    wire signed [MULT_WIDTH-1:0] mul_ts_z3 = z3_reg * PARAM_TS_GAIN;

    // 状态递推与定点还原 (算术右移 16 位)
    reg signed [WIDTH_DATA-1:0] z1_reg;
    reg signed [WIDTH_DATA-1:0] z2_reg;
    reg signed [WIDTH_DATA-1:0] z3_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z1_reg  <= {WIDTH_DATA{1'b0}};
            z2_reg  <= {WIDTH_DATA{1'b0}};
            z3_reg  <= {WIDTH_DATA{1'b0}};
            z1_pos  <= {WIDTH_DATA{1'b0}};
            z2_vel  <= {WIDTH_DATA{1'b0}};
            z3_dist <= {WIDTH_DATA{1'b0}};
        end else if (angle_active) begin
            // z1 递推：z1[k+1] = z1[k] + Ts * z2[k] - L1 * e
            z1_reg  <= z1_reg + (mul_ts_z2 >>> Q_SHIFT) - (mul_err_l1 >>> Q_SHIFT);

            // z2 递推：z2[k+1] = z2[k] + Ts * z3[k] - L2 * e + B0 * u
            z2_reg  <= z2_reg + (mul_ts_z3 >>> Q_SHIFT) - (mul_err_l2 >>> Q_SHIFT) + (mul_b0 >>> Q_SHIFT);

            // z3 递推：z3[k+1] = z3[k] - L3 * e
            z3_reg  <= z3_reg - (mul_err_l3 >>> Q_SHIFT);

            // 寄存打拍同步输出
            z1_pos  <= z1_reg;
            z2_vel  <= z2_reg;
            z3_dist <= z3_reg;
        end
    end

endmodule