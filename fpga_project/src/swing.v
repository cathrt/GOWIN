/*
起摆模块
1. 纯组合译码 + 单拍寄存器输出
2. 基于 [上/下半周] × [顺/逆时针] 4 选 1 直接查表赋值
3. 占空比范围为 -2500 ~ 2500
*/
module swing #(
    parameter WIDTH_DATA = 16
) (
    input  wire clk,
    input  wire rst_n,
    //输入使能
    input  wire swing_en,
    //输入的角度信息(ADC 纯码值格式)
    input  wire angle_active,
    input  wire signed [WIDTH_DATA-1:0] angle_deg,
    input  wire signed [WIDTH_DATA-1:0] angle_vel,
    //输出
    output reg  signed [12:0] swing_data //后续PWM只需要12位+1位符号
);

//4个状态
localparam S_UPPER_CCW = 2'b00;  // 上半周(0) + 逆时针(0)，电机正转轻托
localparam S_UPPER_CW  = 2'b01;  // 上半周(0) + 顺时针(1)，电机反转轻托
localparam S_LOWER_CCW = 2'b10;  // 下半周(1) + 逆时针(0)，电机反转大推
localparam S_LOWER_CW  = 2'b11;  // 下半周(1) + 顺时针(1)，电机正转大推

// 占空比推力幅值，带符号
localparam signed [12:0] DUTY_SWING = 13'sd750; // 下半周大推力  30% 占空比 = 2500 * 0.3  = 750 
localparam signed [12:0] DUTY_BOOST = 13'sd450; // 上半周轻托力  18% 占空比 = 2500 * 0.18 = 450 

//状态判定，4选1MUX
wire [WIDTH_DATA-1:0] abs_angle = (angle_deg > 0) ? angle_deg : -angle_deg; //绝对值

// 1: 下半周, 0: 上半周。90度对应的 ADC 偏差码值阈值：(1024 / 345度) * 90度 ≈ 267
wire half_angle = (abs_angle > 16'd267); 

// 1: 顺时针, 0: 逆时针
wire half_dir = (angle_vel <= 0); //角速度小于等于0，顺时针

//组合起来
wire [1:0] state_sel = {half_angle, half_dir};

//输出寄存器化
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        swing_data <= 13'sd0;
    end else if (angle_active && swing_en) begin
        case (state_sel)
            S_LOWER_CW:  swing_data <= +DUTY_SWING; // 电机正转大推力 (产生向左惯性力)
            S_LOWER_CCW: swing_data <= -DUTY_SWING; // 电机反转大推力 (产生向右惯性力)
            S_UPPER_CW:  swing_data <= -DUTY_BOOST; // 电机反转轻托举 (产生向右惯性力)
            S_UPPER_CCW: swing_data <= +DUTY_BOOST; // 电机正转轻托举 (产生向左惯性力)
            default:     swing_data <= 13'sd0;
        endcase
    end else if(!swing_en) begin
        // 安全保护：使能一旦撤销（切换PID或急停），推力立即强行归零
        swing_data <= 13'sd0;
    end
end


endmodule