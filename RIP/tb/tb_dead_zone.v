`timescale 1ns/1ps

module tb_dead_zone_test;

    // 参数
    parameter integer CLK_F      = 50_000_000;
    parameter integer CTRL_F     = 1_000_000;   // 将 1ms 缩小到 50*20ns = 1us
    parameter integer WIDTH_DATA = 16;
    parameter integer DUTY_MAX   = 2500;
    parameter integer STEP_TIME  = 2;       // 将 20ms 步进降频为 2 ms

    localparam CLK_PERIOD = 20; // 50MHz 系统时钟 (周期 20ns)

    // 激励信号
    reg  clk;
    reg  rst_n;
    reg  key_dead;
    reg  signed [WIDTH_DATA-1:0] pos_arm;

    // 观测信号
    wire ctrl_tick;
    wire signed [WIDTH_DATA-1:0] duty_test;
    wire signed [WIDTH_DATA-1:0] dead_zone_val;
    wire test_done;

    // 例化
    dead_zone_test #(
        .WIDTH_DATA(WIDTH_DATA),
        .DUTY_MAX  (DUTY_MAX),
        .STEP_TIME (STEP_TIME)
    ) u_dead_zone_test (
        .clk          (clk),
        .rst_n        (rst_n),
        .ctrl_tick    (ctrl_tick),
        .key_dead     (key_dead),
        .pos_arm      (pos_arm),
        .duty_test    (duty_test),
        .dead_zone_val(dead_zone_val),
        .test_done    (test_done)
    );

    ctrl_clk # (
        .CLK_F(CLK_F),
        .CTRL_F(CTRL_F)
    ) ctrl_clk_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ctrl_tick(ctrl_tick)
    );


    // 50MHz 时钟
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 电机物理摩擦 所产生的位置变化 (预设真实死区为 260)
    localparam signed [15:0] MOTOR_PHYSICAL_DEAD_ZONE = 16'sd260;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_arm <= -16'sd15; // 赋予非零初始偏置，验证相对位移差分逻辑
        end else begin
            // 占空比突破预设物理死区后，电机转动使编码器开始累加脉冲
            if (duty_test >= MOTOR_PHYSICAL_DEAD_ZONE) begin
                pos_arm <= pos_arm + 16'sd1;
            end
        end
    end


    // 按键脉冲生成任务
    task press_key();
        begin
            @(posedge clk);
            key_dead = 1'b1;
            @(posedge clk);
            key_dead = 1'b0;
        end
    endtask

    // 激励流程
    initial begin
        rst_n    = 1'b0;
        key_dead = 1'b0;

        // 系统复位
        #(CLK_PERIOD * 5);
        @(posedge clk);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        // 启动测试：按下按键，触发死区递增扫描
        press_key();

        // 等待测试完成
        wait(test_done == 1'b1);
        #(CLK_PERIOD * 10);

        // 再次按下按键，测试复位回 IDLE 状态
        press_key();
        #(CLK_PERIOD * 20);

        $stop;
    end

endmodule