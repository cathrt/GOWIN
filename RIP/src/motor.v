`timescale 1ns/1ps
/*
电机驱动模块
功能：
    1. 将输入的占空比和转向信号转换为PWM波形和电机驱动信号
    2. 死区补偿，确保电机在低速时仍能稳定运行
*/
module motor #(
	parameter integer DUTY_MAX  = 2500,
    parameter integer DEAD_ZONE = 
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

// 死区补偿
    reg [12:0] duty_actual;     // 死区补偿后的实际占空比

    // 死区补偿
    always @(*) begin
        if (duty_signed >0) begin
            // 正转补偿：越过死区并限幅
            if (duty_signed + DEAD_ZONE >= DUTY_MAX) begin
                duty_actual = DUTY_MAX;
            end else begin
                duty_actual = duty_signed + DEAD_ZONE;
            end
        end else if(duty_signed < 0) begin
            // 反转补偿：越过死区并限幅
            if (-duty_signed + DEAD_ZONE >= DUTY_MAX) begin
                duty_actual = DUTY_MAX;
            end else begin
                duty_actual = -duty_signed + DEAD_ZONE;
            end
        end else begin
            duty_actual = 0;
        end
    end

    // 内部连线
    wire motor_dir;                 // 电机转向，0正转，1反转
    wire [11:0] duty_unsigned;      // 占空比无符号数

    //电机控制模块
    motor_control # (
        .DUTY_MAX(DUTY_MAX)
    ) motor_control_inst (
        .clk(clk),
        .rst_n(rst_n),
        .duty_signed(duty_actual),
        .motor_stop(motor_stop),
        .duty_unsigned(duty_unsigned),
        .motor_dir(motor_dir)
    );

    //PWM波形发生器模块
    pwm # (
        .DUTY_MAX(DUTY_MAX)
    ) pwm_inst (
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