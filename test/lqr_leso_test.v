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

注意：
    - 真实 2ms 节拍在 100MHz 下 = 200000 拍，仿真会很慢
    - 用 TICK_CYCLES 参数控制节拍，仿真阶段设小一点（如 100）
    - 上板前用真实值（200000）跑一次
*/
module lqr_leso_test;

    // ============================================================
    // 参数
    // ============================================================
    localparam CLK_PERIOD   = 10;         // 100 MHz
    localparam TICK_CYCLES  = 200;        // 仿真加速：真实 2ms 用 200000

    // ============================================================
    // 信号
    // ============================================================
    reg  clk, rst_n;
    reg  lqr_en;
    reg  signed [31:0] target_arm, target_pend;
    reg  signed [31:0] angle_deg;
    reg  signed [31:0] cur_pos;
    reg  signed [31:0] cur_speed;

    wire signed [12:0] u_duty;
    wire               sat_pos, sat_neg;

    reg  angle_active;

    // ============================================================
    // 时钟
    // ============================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ============================================================
    // 2ms 节拍生成
    // ============================================================
    reg [31:0] tick_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt     <= 0;
            angle_active <= 1'b0;
        end else if (tick_cnt == TICK_CYCLES - 1) begin
            tick_cnt     <= 0;
            angle_active <= 1'b1;
        end else begin
            tick_cnt     <= tick_cnt + 1;
            angle_active <= 1'b0;
        end
    end

    // ============================================================
    // DUT
    // ============================================================
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

    // ============================================================
    // 测试序列
    // ============================================================
    // Q16 参考值
    localparam Q16_0p1 = 32'sd6554;      // 0.1 × 65536
    localparam Q16_0p5 = 32'sd32768;     // 0.5 × 65536
    localparam Q16_1p0 = 32'sd65536;     // 1.0 × 65536
    localparam Q16_2p0 = 32'sd131072;    // 2.0 × 65536

    integer i;

    initial begin
        // 初始化
        rst_n       = 1'b0;
        lqr_en      = 1'b0;
        target_arm  = 32'sd0;
        target_pend = 32'sd0;
        angle_deg   = 32'sd0;
        cur_pos     = 32'sd0;
        cur_speed   = 32'sd0;

        // VCD 波形
        $dumpfile("tb_lqr_leso.vcd");
        $dumpvars(0, tb_lqr_leso);

        // ============================================
        // 场景 1：复位
        // ============================================
        $display("\n===== 场景 1: 复位 =====");
        #1000;
        rst_n = 1'b1;
        #500;

        // ============================================
        // 场景 2：静止（输入全 0，lqr_en=0）
        // ============================================
        $display("\n===== 场景 2: 静止, lqr_en=0 =====");
        #(CLK_PERIOD * TICK_CYCLES * 5);

        // ============================================
        // 场景 3：使能 LQR，输入仍全 0
        // ============================================
        $display("\n===== 场景 3: 使能 LQR, 输入全 0 =====");
        lqr_en = 1'b1;
        #(CLK_PERIOD * TICK_CYCLES * 10);

        // ============================================
        // 场景 4：垂直摆角度偏差 +1.0 rad
        //   预期：u_duty 变负（把摆杆拉回）
        // ============================================
        $display("\n===== 场景 4: 垂直摆 +1.0 rad 偏差 =====");
        angle_deg = Q16_1p0;
        #(CLK_PERIOD * TICK_CYCLES * 20);
        angle_deg = 32'sd0;
        #(CLK_PERIOD * TICK_CYCLES * 10);

        // ============================================
        // 场景 5：水平臂位置偏差 +100 计数
        //   预期：u_duty 变负
        // ============================================
        $display("\n===== 场景 5: 水平臂 +100 计数偏差 =====");
        cur_pos = 32'sd100;
        #(CLK_PERIOD * TICK_CYCLES * 20);
        cur_pos = 32'sd0;
        #(CLK_PERIOD * TICK_CYCLES * 10);

        // ============================================
        // 场景 6：水平臂速度扰动
        // ============================================
        $display("\n===== 场景 6: 水平臂速度 +50 =====");
        cur_speed = 32'sd50;
        #(CLK_PERIOD * TICK_CYCLES * 20);
        cur_speed = 32'sd0;
        #(CLK_PERIOD * TICK_CYCLES * 10);

        // ============================================
        // 场景 7：大输入触发饱和
        // ============================================
        $display("\n===== 场景 7: 大幅偏差触发饱和 =====");
        angle_deg = Q16_2p0;    // 2 rad 偏差
        cur_pos   = 32'sd5000;
        #(CLK_PERIOD * TICK_CYCLES * 30);
        angle_deg = 32'sd0;
        cur_pos   = 32'sd0;
        #(CLK_PERIOD * TICK_CYCLES * 10);

        // ============================================
        // 场景 8：关闭使能
        // ============================================
        $display("\n===== 场景 8: lqr_en=0 输出归零 =====");
        lqr_en = 1'b0;
        #(CLK_PERIOD * TICK_CYCLES * 10);

        // ============================================
        // 结束
        // ============================================
        $display("\n===== 仿真结束 =====");
        #1000;
        $finish;
    end

    // ============================================================
    // 超时保护
    // ============================================================
    initial begin
        #(CLK_PERIOD * TICK_CYCLES * 200);
        $display("\n[WARN] 仿真超时，强制结束");
        $finish;
    end

endmodule