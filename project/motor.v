//电机驱动模块
module motor #(
	parameter CLK_F = 50_000_000, //时钟频率
	parameter PWM_F = 20_000 //PWM频率
) (
    input  wire clk,
    input  wire rst_n,
    //输入
    input  wire signed [12:0] duty_signed,  //占空比有符号数
    input  wire motor_stop,                 //电机停止转动标志位
    //输出
    output reg  ain1,                       //电机驱动A相输入1
    output reg  ain2,                       //电机驱动A相输入2
    output wire pwm_out                     //PWM波形输出
);

//PWM周期，CLK_F(50MHz) / PWM_F(20KHz)
localparam DUTY_MAX = CLK_F / PWM_F;

wire [11:0] duty_unsigned;      //占空比无符号数

//电机控制模块
wire ain1_r, ain2_r;
motor_control #(
	.DUTY_MAX(DUTY_MAX)
) motor_control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .duty_unsigned(duty_unsigned),
    .ain1(ain1_r),
    .ain2(ain2_r)
  );

//PWM波形发生器模块
wire pwm_out_r;
pwm # (
    .DUTY_MAX(DUTY_MAX)
  )
  pwm_inst (
    .clk(clk),
    .rst_n(rst_n),
	.motor_stop(motor_stop),
    .duty_unsigned(duty_unsigned),
    .pwm_out(pwm_out_r)
  );

//电机转向一共打了一拍，PWM输出打了两拍，因此，我们要让电机转向多打一拍，让他们同时输出
always @(posedge clk or negedge rst_n) begin
	if(!rst_n || motor_stop) begin
		ain1 <= 1'b0;
		ain2 <= 1'b0;
	end else begin
		ain1 <= ain1_r;
		ain2 <= ain2_r;
	end
end

assign pwm_out = motor_stop ? 1'b0 : pwm_out_r;

endmodule