`timescale 1ns/1ps

module decode_test;
    reg  clk;
    reg  rst_n;
    reg  encode_a;      //编码器输入A相
    reg  encode_b;      //编码器输入B相
    wire encode_pluse;  //4倍频后的脉冲，在此时采集数据
    wire motor_dir;     //电机正反转
    wire signed [31:0] cur_pos;

    parameter K_MOTOR   = 302076;
    parameter MOTOR_MAX = 1_000_000;

    decode_sync  uut1 (
    .clk(clk),
    .rst_n(rst_n),
    .encode_a(encode_a),
    .encode_b(encode_b),
    .encode_pluse(encode_pluse),
    .motor_dir(motor_dir)
  );
    decode_cnt  uut2 (
    .clk(clk),
    .rst_n(rst_n),
    .encode_pluse(encode_pluse),
    .motor_dir(motor_dir),
    .cur_pos(cur_pos)
  );
    decode_speed # (
    .K_MOTOR(K_MOTOR),
    .MOTOR_MAX(MOTOR_MAX)
  )uut3 (
    .clk(clk),
    .rst_n(rst_n),
    .encode_pluse(encode_pluse),
    .motor_dir(motor_dir),
    .cur_speed(cur_speed)
  );

  //时钟激励
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    //正转任务：A 超前 B 90度 (AB呈现周期循环: 10 -> 11 -> 01 -> 00)
    //cycle:任务执行几个周期，quarter：1/4周期时间
    task rotate_forward (input integer cycles, input  integer quarter_t);
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

    // 反转任务：B 超前 A 90度 (循环: 01 -> 11 -> 10 -> 00)
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

  //仿真激励流程 (假设输入的是 10kHz 方波，1/4周期 = 25us = 25,000ns)
    initial begin
        //初始化
        rst_n = 1'b0;
        encode_a = 1'b0;
        encode_b = 1'b0;

        //与复位同步
        #1_000;
        rst_n = 1'b1;
        #50_000;

        //正转 2 个完整脉冲周期 (应触发 2 * 4 = 8 个脉冲)
        rotate_forward(2, 25_000);
        #50_000;

        //反转 2 个完整脉冲周期 (应触发 2 * 4 = 8 个脉冲)
        rotate_backward(3, 25_000);
        #50_000;

        $stop;
    end

endmodule