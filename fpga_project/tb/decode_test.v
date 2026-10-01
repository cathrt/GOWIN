`timescale 1ns / 1ps
/*
测试内容:
    1. 正转 2 个完整周期: 验证 4 倍频脉冲产生 (2 * 4 = 8 拍) 与正转方向 (motor_dir = 0)
    2. 反转 3 个完整周期: 验证反转方向 (motor_dir = 1) 与计数向下扣减 (8 - 12 = -4)
    3. ctrl_tick 锁存: 验证当前物理累加值是否在控制节拍到达时正确更新至 pos_arm
    4. pos_clr 归零: 验证接收到清零指令后计数值是否清空
*/
module tb_decode;

    localparam integer WIDTH_DATA = 16;

    // 激励信号声明
    reg        clk;
    reg        rst_n;
    reg        ctrl_tick;       // 控制周期节拍脉冲
    reg        pos_clr;         // 起摆切平衡位置清零
    reg        encode_a;        // 编码器 A 相
    reg        encode_b;        // 编码器 B 相

    // 内部互联与观测信号
    wire       encode_pulse;    // 4 倍频边沿指示脉冲
    wire       motor_dir;       // 电机转向 (0: 正转, 1: 反转)
    wire signed [WIDTH_DATA-1:0] pos_arm; // 送往 LQR 的周期位置快照

    // -------------------------------------------------------------------------
    // 1. 例化同步与 4 倍频鉴相模块
    // -------------------------------------------------------------------------
    decode_sync u_decode_sync (
        .clk          (clk),
        .rst_n        (rst_n),
        .encode_a     (encode_a),
        .encode_b     (encode_b),
        .encode_pulse (encode_pulse),
        .motor_dir    (motor_dir)
    );

    // -------------------------------------------------------------------------
    // 2. 例化位置计数与 1ms 快照锁存模块
    // -------------------------------------------------------------------------
    decode_cnt #(
        .WIDTH_DATA   (WIDTH_DATA)
    ) u_decode_cnt (
        .clk          (clk),
        .rst_n        (rst_n),
        .pos_clr      (pos_clr),
        .ctrl_tick    (ctrl_tick),
        .encode_pulse (encode_pulse),
        .motor_dir    (motor_dir),
        .pos_arm      (pos_arm)
    );

    // -------------------------------------------------------------------------
    // 3. 时钟与控制节拍生成
    // -------------------------------------------------------------------------
    // 50MHz 主时钟 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // 控制节拍脉冲: 仿真中设为每 10us (10,000ns) 发出一次单拍高脉冲
    initial begin
        ctrl_tick = 1'b0;
        forever begin
            #9980;
            @(posedge clk);
            ctrl_tick = 1'b1;
            @(posedge clk);
            ctrl_tick = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 4. 正交信号生成任务 (Tasks)
    // -------------------------------------------------------------------------
    // 正转任务: A 超前 B 90度 (循环: 10 -> 11 -> 01 -> 00)
    task rotate_forward(input integer cycles, input integer quarter_t);
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                encode_a = 1'b1; encode_b = 1'b0; #quarter_t;
                encode_a = 1'b1; encode_b = 1'b1; #quarter_t;
                encode_a = 1'b0; encode_b = 1'b1; #quarter_t;
                encode_a = 1'b0; encode_b = 1'b0; #quarter_t;
            end
        end
    endtask

    // 反转任务: B 超前 A 90度 (循环: 01 -> 11 -> 10 -> 00)
    task rotate_backward(input integer cycles, input integer quarter_t);
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                encode_a = 1'b0; encode_b = 1'b1; #quarter_t;
                encode_a = 1'b1; encode_b = 1'b1; #quarter_t;
                encode_a = 1'b1; encode_b = 1'b0; #quarter_t;
                encode_a = 1'b0; encode_b = 1'b0; #quarter_t;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 5. 仿真流程
    // -------------------------------------------------------------------------
    initial begin
        // 初始电平
        rst_n    = 1'b0;
        pos_clr  = 1'b0;
        encode_a = 1'b0;
        encode_b = 1'b0;

        // 异步复位 1us
        #1000;
        @(posedge clk);
        rst_n = 1'b1;
        #20000; // 等待稳定

        // 阶段一：正转 2 个完整脉冲周期 (quarter_t = 25us, 1个周期触发 4 个脉冲，共 8 脉冲)
        rotate_forward(2, 25000);
        #30000;

        // 阶段二：反转 3 个完整脉冲周期 (产生 12 个反向脉冲)
        rotate_backward(3, 25000);
        #30000;

        // 阶段三：测试位置清零脉冲 pos_clr
        @(posedge clk);
        pos_clr = 1'b1;
        @(posedge clk);
        pos_clr = 1'b0;
        #30000;

        $stop;
    end

endmodule