`timescale 1ns/1ps

module motor_test;
    reg  clk;
    reg  rst_n;
    reg  signed [15:0]duty_signed;
    reg  motor_stop;
    wire ain1;
    wire ain2;
    wire pwm_out;

    motor  uut (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .ain1(ain1),
    .ain2(ain2),
    .pwm_out(pwm_out)
  );

    //时钟激励
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    //复位激励
    initial begin
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
    end

    //测试激励，PWM 周期 本来是 50us( 50_000ns )，现在缩小为 1000ns ，便于观察
    initial begin

	    //初始化
        duty_signed = 16'sd0;
        motor_stop = 1'b1;

        //等待复位信号
        #100;

        //正转50%占空比
        motor_stop = 1'b0;  //电机开启
        duty_signed = 16'sd1250;
        #1_000;

        //反转50%占空比
        motor_stop = 1'b0;
        duty_signed = -16'sd1250;
        #1_000;

        //正转超限
        duty_signed = 16'sd5000;
        #1_000;

        //反转超限
        duty_signed = -16'sd5000;
        #1_000;

        //电机关闭
        motor_stop = 1'b1;
        #1_000;
        $stop;
    end

endmodule
