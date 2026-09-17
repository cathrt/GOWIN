/*
LQR 公式：u = kp*e + kd*w
其RTL和PD一样
*/
module lqr #(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_GAIN = 16,   // 观测器增益位宽 (16位)
    parameter Q_SHIFT    = 12,   // Q12 定点移位量
    //参数
    parameter signed [WIDTH_GAIN-1:0] K1 = 16'sd100,
    parameter signed [WIDTH_GAIN:0] K2 = 16'sd100
) (
    input  wire clk,
    input  wire rst_n,
    //输入的数据
    input  wire signed [WIDTH_DATA-1:0] target,  //目标信息
    input  wire signed [WIDTH_DATA-1:0] z1_in,     //当前角度
    input  wire signed [WIDTH_DATA-1:0] z2_in,    //角速度
    //输出的数据
    output reg  signed [WIDTH_DATA-1:0] u_lqr //输出占空比，代表力的大小
);

localparam MULT_WIDTH = WIDTH_DATA + WIDTH_GAIN;

// 误差计算
wire signed [WIDTH_DATA-1:0] err = target - z1_in;

//比例项
wire signed [MULT_WIDTH-1:0] lqr_p = K1 * err;

//微分项
wire signed [MULT_WIDTH-1:0] lqr_d = K2 * z2_in;

//求和输出，右移8位，即除以256
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        u_lqr <= {WIDTH_DATA{1'b0}};
    end else begin
        u_lqr = (lqr_p - lqr_d) >>> Q_SHIFT;
    end
end

endmodule