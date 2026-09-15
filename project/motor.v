//电机驱动模块
module motor(
    input  wire clk,
    input  wire rst_n,
    //输入
    input  wire signed [13:0] duty_signed, //占空比有符号数
    input  wire motor_stop,         //电机停止转动标志位
    //输出
    output wire ain1,               //电机驱动A相输入1
    output wire ain2,               //电机驱动A相输入2
    output wire pwm_out             //PWM波形输出
);

wire [11:0] duty_unsigned; //占空比无符号数

//电机控制模块
motor_control motor_control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .duty_unsigned(duty_unsigned),
    .ain1(ain1),
    .ain2(ain2)
  );

//PWM波形发生器模块
pwm pwm_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_unsigned(duty_unsigned),
    .pwm_out(pwm_out)
  );

endmodule