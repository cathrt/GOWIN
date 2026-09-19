`timescale 1ns / 1ps
/*
LQR + LESO 联合仿真 Testbench

测试场景：
    1. 复位验证
    2. 静止（输入全 0）
    3. 垂直摆角度偏差（摆杆偏 1.0 rad）
    4. 水平臂位置偏差（编码器偏 100 计数）
    5. 水平臂速度扰动
    6. 饱和测试（给大输入）
    7. 使能关断

*/
module lqr_leso_test;

    localparam CLK_PERIOD = 20;         // 50 MHz
    localparam CNT_MAX    = 2_000;      // 仿真加速：真实 2ms 用 2_000 来代替
    localparam WIDTH_DATA = 32;

    // 信号
    reg  clk, rst_n;
    reg  lqr_en;
    wire angle_active;
    reg  signed [31:0] target_arm, target_pend;
    reg  signed [31:0] angle_deg;
    reg  signed [31:0] cur_pos;
    reg  signed [31:0] cur_speed;

    wire signed [12:0] u_duty;
    wire sat_pos, sat_neg;

    // 时钟
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // angle_active 2ms 节拍生成，我们用2_000代替2ms
    reg [WIDTH_DATA-1:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 0;
        end else if(cnt == CNT_MAX) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
    assign angle_active = (cnt == CNT_MAX);

    lqr_leso dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .angle_active (angle_active),
        .lqr_en       (lqr_en),
        .target_arm   (target_arm),
        .target_pend  (target_pend),
        .angle_deg    (angle_deg),
        .cur_pos      (cur_pos),
        .cur_speed    (cur_speed),
        .u_duty       (u_duty),
        .sat_pos      (sat_pos),
        .sat_neg      (sat_neg)
    );

    // ============================================================
    // 波形打印：每个 2ms 节拍打印一次
    // ============================================================
    always @(posedge clk) begin
        if (angle_active) begin
            $display("[t=%0t] angle=%d cur_pos=%d cur_speed=%d | u_duty=%d sat=(%b,%b) | lqr_en=%b",
                     $time, angle_deg, cur_pos, cur_speed,
                     u_duty, sat_pos, sat_neg, lqr_en);
        end
    end

    localparam Q16_10DEG = 32'sd11439;    // 10° 弧度值 (0.1745 rad * 65536)
    localparam Q16_LARGE = 32'sd655360;   // 大角度扰动 (10 rad * 65536)

    initial begin
        // 信号初始化
        rst_n       = 1'b0;
        lqr_en      = 1'b0;
        target_arm  = 32'sd0;
        target_pend = 32'sd0;
        angle_deg   = 32'sd0;
        cur_pos     = 32'sd0;
        cur_speed   = 32'sd0;

        // 场景 1：复位
        $display("\n===== 场景 1: 复位 =====");
        #200;
        @(negedge clk) rst_n = 1'b1;
        #200;

        // 场景 2：静止 (输入全 0，未使能)
        $display("\n===== 场景 2: 静止 (lqr_en=0) =====");
        repeat(2) @(posedge angle_active);

        // 场景 3：使能 LQR，输入仍全 0
        $display("\n===== 场景 3: 使能 LQR (输入全 0) =====");
        @(negedge clk) lqr_en = 1'b1;
        repeat(2) @(posedge angle_active);

        // 场景 4：垂直摆杆偏移 10° (正角度)
        // 预期动作：算法输出负推力尝试拉回摆杆
        $display("\n===== 场景 4: 垂直摆杆 10° 偏差 =====");
        @(negedge clk) angle_deg = Q16_10DEG;
        repeat(5) @(posedge angle_active);
        @(negedge clk) angle_deg = 32'sd0;
        repeat(2) @(posedge angle_active);

        // 场景 5：水平臂位置偏差 +100 计数
        // 预期动作：算法产生反向推力让水平臂回中
        $display("\n===== 场景 5: 水平臂 +100 脉冲偏差 =====");
        @(negedge clk) cur_pos = 32'sd100;
        repeat(5) @(posedge angle_active);
        @(negedge clk) cur_pos = 32'sd0;
        repeat(2) @(posedge angle_active);

        // 场景 6：水平臂速度扰动 +50
        $display("\n===== 场景 6: 水平臂速度 +50 扰动 =====");
        @(negedge clk) cur_speed = 32'sd50;
        repeat(5) @(posedge angle_active);
        @(negedge clk) cur_speed = 32'sd0;
        repeat(2) @(posedge angle_active);

        // 场景 7：大幅偏差触发饱和限幅 (±2500)
        $display("\n===== 场景 7: 大幅偏差触发饱和 =====");
        @(negedge clk) begin
            angle_deg = Q16_LARGE;
            cur_pos   = 32'sd5000;
        end
        repeat(5) @(posedge angle_active);
        @(negedge clk) begin
            angle_deg = 32'sd0;
            cur_pos   = 32'sd0;
        end
        repeat(2) @(posedge angle_active);

        // 场景 8：关断使能，推力强制归零
        $display("\n===== 场景 8: lqr_en=0 急停输出归零 =====");
        @(negedge clk) lqr_en = 1'b0;
        repeat(2) @(posedge angle_active);

        // 结束
        $display("\n===== 仿真结束 =====");
        #500;
        $stop;
    end

    // 超时看门狗保护
    initial begin
        #(CLK_PERIOD * CNT_MAX * 50); // 允许最大跑 50 个控制周期
        $display("\n[WARN] 仿真超时，强制结束");
        $finish;
    end

endmodule