`timescale 1ns/1ns

module pwm_test;

    reg         clk;
    reg         rst_n;
    reg  [11:0] duty_unsigned;
    wire        pwm_out;

    parameter integer F_PWM = 20_000;
    parameter integer CLK_SYSTEM = 50_000_000;
    // 例化 PWM 模块
    pwm #(
        .F_PWM(F_PWM),
        .CLK_SYSTEM(CLK_SYSTEM)
    ) uut (
        .clk           (clk),
        .rst_n         (rst_n),
        .duty_unsigned (duty_unsigned),
        .pwm_out       (pwm_out)
    );

    // 时钟生成：50 MHz 周期 20ns
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk; 
    end

    // 测试激励流程，PWM周期 本来是 50us( 50_000ns )，现在缩小为 1000ns ，便于观察
    initial begin
        // 1. 初始化信号
        rst_n         = 1'b0;
        duty_unsigned = 12'd0;

        // 复位 1000ns 后释放
        #100;
        rst_n = 1'b1;

        // 2. 测试 0% 占空比 (验证复位释放后输出仍保持纯低电平)
        #1_000;

        // 3. 测试 25% 占空比 (625 / 2500)
        duty_unsigned = 12'd625;
        #1_000;

        // 4. 测试 50% 占空比 (1250 / 2500)
        duty_unsigned = 12'd1250;
        #1_000;

        // 5. 测试 75% 占空比 (1875 / 2500)
        duty_unsigned = 12'd1875;
        #1_000;

        // 6. 测试 100% 满偏占空比 (2500 / 2500)
        duty_unsigned = 12'd2500;
        #1_000; // 修正：留足 100us (2个周期)，完整观察纯直流高电平

        // 仿真结束
        $stop;
    end

endmodule