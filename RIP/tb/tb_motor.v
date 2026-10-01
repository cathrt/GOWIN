`timescale 1ns/1ps
/*
测试内容: 
    1. 电机正反转
    2. 电机关闭
*/
module tb_motor;

    // 参数
    localparam integer CLK_F = 50_000_000;
    localparam integer PWM_F = 1_000_000;
    localparam integer DUTY_MAX = CLK_F / PWM_F;

    // 激励信号
    reg  clk;
    reg  rst_n;
    reg  signed [12:0]duty_signed;
    reg  motor_stop;

    // 观测信号
    wire ain1;
    wire ain2;
    wire pwm_out;

    // 例化
    motor # (
    .DUTY_MAX(DUTY_MAX)
  )
  motor_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .ain1(ain1),
    .ain2(ain2),
    .pwm_out(pwm_out)
  );

    // 时钟生成：50MHz 主时钟 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // 仿真流程，PWM 周期 本来是50us ，现在缩小为 1000ns(1us) ，便于观察
    initial begin

	    //初始化
        rst_n = 1'b0;
        duty_signed = 13'sd0;
        motor_stop = 1'b1;

        // 异步复位
        #100;
        @(posedge clk);
        rst_n <= 1'b1;
        #200;

        // 正转50%占空比，2500/2 = 1250
        motor_stop = 1'b0;  // 电机开启
        duty_signed = 13'sd25;    // 1250/50 = 25
        #4_000; // 保持4个周期

        // 反转50%占空比
        motor_stop = 1'b0;
        duty_signed = -13'sd25;
        #4_000;
    /*
        //正转超限
        duty_signed = 13'sd5000;
        #1_000;

        //反转超限
        duty_signed = -13'sd5000;
        #1_000;
    */
        //电机关闭
        motor_stop = 1'b1;
        #4_000;
        $stop;
    end

endmodule
