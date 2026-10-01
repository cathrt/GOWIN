`timescale 1ns / 1ps
/*
测试内容:
    1. 是否 4倍频
    2. 正转 2 个完整周期 
    3. 反转 3 个完整周期
    4. ctrl_tick 是否锁存数据 更新至 pos_arm
    5. pos_clr 是否归零
*/
module tb_decode;

    // 参数
    localparam integer WIDTH_DATA = 16;
    localparam integer CLK_PERIOD = 20;

    // 激励信号
    reg clk;
    reg rst_n;
    reg ctrl_tick;       // 控制周期节拍脉冲
    reg pos_clr;         // 起摆切平衡位置清零
    reg encode_a;        // 编码器 A 相
    reg encode_b;        // 编码器 B 相

    // 观测信号
    wire encode_pulse;    // 4 倍频边沿指示脉冲
    wire motor_dir;       // 电机转向 (0: 正转, 1: 反转)
    wire signed [WIDTH_DATA-1:0] pos_arm; 
    wire signed [WIDTH_DATA-1:0] cur_pos; 

    // 例化
    decode_sync u_decode_sync (
        .clk          (clk),
        .rst_n        (rst_n),
        .encode_a     (encode_a),
        .encode_b     (encode_b),
        .encode_pulse (encode_pulse),
        .motor_dir    (motor_dir)
    );

    decode_cnt # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  decode_cnt_inst (
    .clk(clk),
    .rst_n(rst_n),
    .pos_clr(pos_clr),
    .ctrl_tick(ctrl_tick),
    .encode_pulse(encode_pulse),
    .motor_dir(motor_dir),
    .cur_pos(cur_pos),
    .pos_arm(pos_arm)
  );

    // 时钟生成：50MHz 主时钟 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 控制节拍脉冲: 仿真中设为每 100ns 发出一次单拍高脉冲
    initial begin
        ctrl_tick = 1'b0;
        forever begin
            #80;   // 留下20ns产生一个高脉冲
            // 与主时钟对齐
            @(posedge clk);
            ctrl_tick <= 1'b1;
            @(posedge clk);
            ctrl_tick <= 1'b0;
        end
    end

    // 正反转 信号生成任务
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

    // 仿真流程
    initial begin
        // 初始电平
        rst_n    = 1'b0;
        pos_clr  = 1'b0;
        encode_a = 1'b0;
        encode_b = 1'b0;

        // 异步复位，同步释放
        #100;
        @(posedge clk);
        rst_n <= 1'b1;
        #200;

        // 1. 正转 2 个完整脉冲周期 (quarter_t = 400ns, 1个周期触发 4 个脉冲，共 8 脉冲)
        rotate_forward(2, 400);
        #1000;

        // 2. 反转 3 个完整脉冲周期 (产生 12 个反向脉冲)
        rotate_backward(3, 400);
        #1000;

        // 3. 测试清零脉冲 pos_clr
        @(posedge clk);
        pos_clr <= 1'b1;
        @(posedge clk);
        pos_clr <= 1'b0;
        #1000;

        $stop;
    end

endmodule