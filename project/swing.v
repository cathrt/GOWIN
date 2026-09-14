/*
起摆模块
1. 2ms 控制节拍驱动的三段式 FSM，基于[上/下半周]×[顺/逆时针] 4 象限做功。
2. 下半周顺推蓄能(+DUTY_SWING)，上半周微推托举(+DUTY_BOOST)。
*/
module swing (
    input  wire clk,
    input  wire rst_n,
    //输入使能
    input  wire swing_en,
    //输入的角度信息
    input  wire angle_active,
    input  wire signed [15:0] angle_deg,
    input  wire signed [15:0] angle_vel,
    //输出
    output reg  signed [15:0] swing_data
);

//4个状态
localparam S_LOWER_CW  = 2'b00;  //下半周顺时针 (|θ| >  90°, vel < 0)，电机正转
localparam S_LOWER_CCW = 2'b01;  //下半周逆时针 (|θ| >  90°, vel > 0)，电机反转
localparam S_UPPER_CW  = 2'b10;  //上半周顺时针 (|θ| <= 90°, vel < 0)，电机反转
localparam S_UPPER_CCW = 2'b11;  //上半周逆时针 (|θ| <= 90°, vel > 0)，电机正转

// 占空比推力幅值 (带符号 16-bit 定点表示)
localparam signed [15:0] DUTY_SWING = 16'sd300; // 下半周大推力 (30.0%)
localparam signed [15:0] DUTY_BOOST = 16'sd180; // 上半周轻托力 (18.0%)

//状态判定，4选1MUX
wire [15:0] abs_angle = (angle_deg > 0) ? angle_deg : -angle_deg; //绝对值
// 1: 下半周, 0: 上半周
wire half_angle = (abs_angle > 16'd9000); //绝对值大于90°
// 1: 顺时针，0: 逆时针
wire half_dir = (angle_vel <= 0); //角速度小于等于0，顺时针
wire [1:0] state_sel = {half_angle, half_dir};

reg [1:0]state_cur;  //当前状态
reg [1:0]state_next; //下一个状态

//状态切换，只有在angle_active有效时（每2ms更新一次），才切换状态
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_cur <= S_LOWER_CW;
    end else if(angle_active && swing_en) begin
        state_cur <= state_next;
    end   
end

//状态转移
always @(*) begin
    //平常下，维持不变
    state_next = state_cur;
    //接收到状态切换条件，切换状态
    case (state_sel)
            2'b11:   state_next = S_LOWER_CW;  // 下半周(1) + 顺时针(1)
            2'b10:   state_next = S_LOWER_CCW; // 下半周(1) + 逆时针(0)
            2'b01:   state_next = S_UPPER_CW;  // 上半周(0) + 顺时针(1)
            2'b00:   state_next = S_UPPER_CCW; // 上半周(0) + 逆时针(0)
            default: state_next = S_LOWER_CW;
    endcase
end

//输出寄存器化
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        swing_data <= 16'sd0;
    end else if (angle_active && swing_en) begin
        case (state_next)
            S_LOWER_CW:  swing_data <= +DUTY_SWING; // 电机正转大推力 (产生向左惯性力)
            S_LOWER_CCW: swing_data <= -DUTY_SWING; // 电机反转大推力 (产生向右惯性力)
            S_UPPER_CW:  swing_data <= -DUTY_BOOST; // 电机反转轻托举 (产生向右惯性力)
            S_UPPER_CCW: swing_data <= +DUTY_BOOST; // 电机正转轻托举 (产生向左惯性力)
            default:     swing_data <= 16'sd0;
        endcase
    end else if(!swing_en) begin
        // 安全保护：使能一旦撤销（切换PID或急停），推力立即强行归零
        swing_data <= 16'sd0;
    end
end


endmodule