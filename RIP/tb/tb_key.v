`timescale 1ns / 1ps
/*
测试内容: 模拟按键抖动，检测是否输出一个高脉冲
*/
module tb_key;

    // 参数与时钟定义 
    localparam integer CLK_PERIOD = 20;

    // 激励信号
    reg  clk;
    reg  rst_n;
    reg  key_in;

	// 观测信号
    wire key_pulse;   // 消抖后输出的单周期脉冲

	// 例化
    key_debounce # (
        .CNT_MAX(10)    //将原先的20MS 缩小为 10*20ns，即10拍一直低电平即认为按键按下，防止仿真占用太多时间
    ) key_debounce_inst (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_in),
        .key_pulse(key_pulse)
    );

    // 时钟生成 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 激励流程
    initial begin
        // 初始化
        rst_n  = 1'b0;
        key_in = 1'b1;

        // 异步复位
        #100;
        @(posedge clk)
        rst_n <= 1'b1;
        #200;

        //1: 机械按下抖动，模拟一会高电平，一会低电平，共 8 拍
        key_in = 1'b0; #40;  // 低 2 拍
        key_in = 1'b1; #60;  // 高 3 拍
        key_in = 1'b0; #20;  // 低 1 拍
        key_in = 1'b1; #40;  // 高 2 拍

        //2: 稳定按下
        //cnt 从 0 数到 9，在第 10 拍 key_pulse 会产生一个完美的脉冲，
        //但实际经过了打两拍消除亚稳态，因此实际是在第 12 拍产生一个脉冲
        key_in = 1'b0;
        #500;   // 低25拍

        //3: 机械释放抖动，还是模拟抖动，共 9 拍
        key_in = 1'b1; #40; // 高 2 拍
        key_in = 1'b0; #60; // 低 3 拍
        key_in = 1'b1; #20; // 高 1 拍
        key_in = 1'b0; #40; // 低 2 拍
        key_in = 1'b1; #20; // 高 1 拍

        //4: 稳定释放 (恢复高电平保持)
        key_in = 1'b1;
        #500;

        $stop;
    end

endmodule
