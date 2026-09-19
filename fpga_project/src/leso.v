/*
LESO
*/
module leso #(
    parameter WIDTH_DATA = 32,
    parameter Q_SHIFT    = 16,  // 所有数据按Q16格式

    // 定点化观测器参数 (默认以 Ts=2ms, wo=60 rad/s, b0=100 预设), Q16
    parameter signed [WIDTH_DATA-1:0] PARAM_TS = 32'sd131,         //T
    parameter signed [WIDTH_DATA-1:0] PARAM_L1 = 32'sd23593,       //β1*T
    parameter signed [WIDTH_DATA-1:0] PARAM_L2 = 32'sd1415578,      //β2*T
    parameter signed [WIDTH_DATA-1:0] PARAM_L3 = 32'sd28311552,    //β3*T
    parameter signed [WIDTH_DATA-1:0] PARAM_B0 = 32'sd13107         //b0*T
) (
    input  wire clk,        
    input  wire rst_n,
    input  wire angle_active,      //输入周期节拍，2ms  
    // 输入信号
    input  wire signed [WIDTH_DATA-1:0] y_meas,     // 摆杆实际角度，Q16
    input  wire signed [WIDTH_DATA-1:0] u_sum_old,  // 当前作用于电机的控制输入，即占空比，Q0
    // 输出信号
    output reg  signed [WIDTH_DATA-1:0] z1_pos,     // 状态估计 1：滤波后的摆杆角度，Q16 
    output reg  signed [WIDTH_DATA-1:0] z2_vel,     // 状态估计 2：重构的摆杆角速度, Q16
    output reg  signed [WIDTH_DATA-1:0] z3_dist     // 状态估计 3：总阻力，Q16
);

    // 乘法器结果位宽 32位 + 32位 = 64位
    localparam MULT_WIDTH = WIDTH_DATA + WIDTH_DATA;

    // 3个状态，处于时序逻辑中，天然具有延迟一拍的特性
    reg signed [WIDTH_DATA-1:0] z1_reg;
    reg signed [WIDTH_DATA-1:0] z2_reg;
    reg signed [WIDTH_DATA-1:0] z3_reg;

    // 观测误差计算 （估计值-实际值）,Q32
    wire signed [WIDTH_DATA-1:0] err = z1_reg - y_meas;

    // 中间值计算，寄存器化，防止其数据通路太长
    reg signed [MULT_WIDTH-1:0] mul_err_l1, mul_err_l2, mul_err_l3;
    reg signed [MULT_WIDTH-1:0] mul_b0, mul_ts_z2, mul_ts_z3;
    reg angle_active_s1;       // 控制信号也要打一拍同步
    always @(posedge clk) begin
        mul_err_l1      <= err       * PARAM_L1;   // β1*T*e，Q32
        mul_err_l2      <= err       * PARAM_L2;   // β2*T*e，Q32
        mul_err_l3      <= err       * PARAM_L3;   // β3*T*e，Q32
        mul_b0          <= u_sum_old * PARAM_B0;   // T*e, Q16（Q0 × Q16）
        mul_ts_z2       <= z2_reg    * PARAM_TS;   // T*z2，Q32
        mul_ts_z3       <= z3_reg    * PARAM_TS;   // T*z3，Q32
        angle_active_s1 <= angle_active;
    end

	 // 显式截断为 32 位中间量 (防止在后续进行移位时，默认使用64位加法器，浪费资源)
	 wire signed [WIDTH_DATA-1:0] term_ts_z2  = mul_ts_z2  >>> Q_SHIFT;
    wire signed [WIDTH_DATA-1:0] term_ts_z3  = mul_ts_z3  >>> Q_SHIFT;
    wire signed [WIDTH_DATA-1:0] term_err_l1 = mul_err_l1 >>> Q_SHIFT;
    wire signed [WIDTH_DATA-1:0] term_err_l2 = mul_err_l2 >>> Q_SHIFT;
    wire signed [WIDTH_DATA-1:0] term_err_l3 = mul_err_l3 >>> Q_SHIFT;
    wire signed [WIDTH_DATA-1:0] term_b0     = mul_b0[WIDTH_DATA-1:0];	//截断为32位
	 
    // 状态递推与定点还原 (算术右移 16 位)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z1_reg  <= {WIDTH_DATA{1'b0}};
            z2_reg  <= {WIDTH_DATA{1'b0}};
            z3_reg  <= {WIDTH_DATA{1'b0}};
            z1_pos  <= {WIDTH_DATA{1'b0}};
            z2_vel  <= {WIDTH_DATA{1'b0}};
            z3_dist <= {WIDTH_DATA{1'b0}};
        end else if (angle_active_s1) begin
            // z1 递推：z1[k+1] = z1[k] + Ts * z2[k] - L1 * e
            z1_reg  <= z1_reg + term_ts_z2 - term_err_l1;

            // z2 递推：z2[k+1] = z2[k] + Ts * z3[k] - L2 * e + B0 * u
            z2_reg  <= z2_reg + term_ts_z3 - term_err_l2 + term_b0;  // mul_b0是Q16，不需要移位了

            // z3 递推：z3[k+1] = z3[k] - L3 * e
            z3_reg  <= z3_reg - term_err_l3;

            // 寄存打拍同步输出
            z1_pos  <= z1_reg;
            z2_vel  <= z2_reg;
            z3_dist <= z3_reg;
        end
    end

endmodule