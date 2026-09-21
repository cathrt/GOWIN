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
    output wire ain1,                       //电机驱动A相输入1
    output wire ain2,                       //电机驱动A相输入2
    output wire pwm_out                     //PWM波形输出
);

//PWM周期，CLK_F(50MHz) / PWM_F(20KHz)
localparam DUTY_MAX = CLK_F / PWM_F;

//电机控制模块
wire motor_dir;                 // 电机转向，0正转，1反转
wire [11:0] duty_unsigned;      // 占空比无符号数
motor_control # (
    .DUTY_MAX(DUTY_MAX)
  )
  motor_control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .duty_unsigned(duty_unsigned),
    .motor_dir(motor_dir)
  );

//PWM波形发生器模块
pwm # (
    .DUTY_MAX(DUTY_MAX)
  )
  pwm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_unsigned(duty_unsigned),
    .motor_stop(motor_stop),
    .motor_dir(motor_dir),
    .pwm_out(pwm_out),
    .ain1(ain1),
    .ain2(ain2)
  );



endmodule