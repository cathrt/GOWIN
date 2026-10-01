`timescale 1ns/1ps
/*
测试内容：
    1. 4个状态切换是否顺利
    2. 水平臂位置清零信号是否在 LQR 第一周期
*/
module tb_control;
    
    // 参数
    parameter integer CLK_PERIOD   = 20;
    parameter integer WIDTH_DATA   = 16;
    parameter integer ANGLE_SWITCH = 42;    // 约 15度 对应的码值

    // 激励信号
    reg  clk;
    reg  rst_n;
    reg  key_open;      // 开始工作信号，脉冲
    reg  stop_sig;      // 停机信号，持续高电平
    reg  calib_done;    // 零点设立完成信号，脉冲
    reg  signed [WIDTH_DATA-1:0] pos_pend;

    // 观测信号
    wire lqr_en;            // 持续高电平
    wire swing_en;          // 持续高电平
    wire pos_clr;           // 脉冲
    wire [1:0] state_out;

    // 例化
    control # (
    .WIDTH_DATA(WIDTH_DATA),
    .ANGLE_SWITCH(ANGLE_SWITCH)
  )
  control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .key_open(key_open),
    .stop_sig(stop_sig),
    .calib_done(calib_done),
    .pos_pend(pos_pend),
    .lqr_en(lqr_en),
    .swing_en(swing_en),
    .pos_clr(pos_clr),
    .state_out(state_out)
  );

    // 时钟生成：50MHz 主时钟 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 激励流程
    initial begin
        
        // 初始化
        rst_n = 1'b0;
        key_open = 1'b0;
        stop_sig = 1'b0;
        calib_done = 1'b0;
        pos_pend = 16'sd100;

        // 异步复位
        #100;
        @(posedge clk)
        rst_n <= 1'b1;
        #200;

        // 1. 完成零点校准
        @(posedge clk)
        calib_done <= 1'b1;
        @(posedge clk)
        calib_done <= 1'b0;
        #100;

        // 2. 开启工作，进入 起摆状态
        @(posedge clk)
        key_open <= 1'b1;
        @(posedge clk)
        key_open <= 1'b0;
        #1_000;

        // 3. 进入 平衡状态
        @(posedge clk)
        pos_pend <= 16'sd11;
        #1_000;

        // 4. 停机保护
        @(posedge clk)
        stop_sig <= 1'b1;
        #1_000;

        // 5. 回到空闲状态
        @(posedge clk)
        stop_sig <= 1'b0;
        @(posedge clk)
        key_open <= 1'b1;
        @(posedge clk)
        key_open <= 1'b0;
        #1_000;

        $stop;

    end

endmodule
