`timescale 1ns / 1ps

module tb_lqr;

    localparam integer WIDTH_DATA = 16;
    localparam integer WIDTH_K    = 32;
    localparam integer SHIFT_Q    = 16;
    localparam integer DUTY_MAX   = 2500;

    // 增益参数 (数值 <<< 16，转为定点数常量传给例化端口)
    localparam signed [WIDTH_K-1:0] K1 = 32'sd1  <<< 16;  // k1 = 1.0 (旋臂位置)
    localparam signed [WIDTH_K-1:0] K2 = 32'sd2  <<< 16;  // k2 = 2.0 (旋臂速度)
    localparam signed [WIDTH_K-1:0] K3 = 32'sd50 <<< 16;  // k3 = 50.0 (摆杆角度刚度)
    localparam signed [WIDTH_K-1:0] K4 = 32'sd5  <<< 16;  // k4 = 5.0 (摆杆角速度阻尼)

    localparam CLK_PERIOD = 20; // 50MHz 主频，周期 20ns

    reg clk;
    reg rst_n;
    reg lqr_en;
    reg ctrl_tick;

    reg signed [15:0] target_arm, pos_arm, vel_arm;
    reg signed [15:0] target_pend, pos_pend, vel_pend;

    wire signed [15:0] u_lqr;
    wire sat_pos, sat_neg;

    // 例化
    lqr #(
        .WIDTH_DATA(WIDTH_DATA),
        .WIDTH_K   (WIDTH_K),
        .SHIFT_Q   (SHIFT_Q),
        .DUTY_MAX  (DUTY_MAX),
        .k1        (K1),
        .k2        (K2),
        .k3        (K3),
        .k4        (K4)
    ) lqr_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .lqr_en     (lqr_en),
        .ctrl_tick  (ctrl_tick),
        .target_arm (target_arm),
        .pos_arm    (pos_arm),
        .vel_arm    (vel_arm),
        .target_pend(target_pend),
        .pos_pend   (pos_pend),
        .vel_pend   (vel_pend),
        .u_lqr      (u_lqr),
        .sat_pos    (sat_pos),
        .sat_neg    (sat_neg)
    );

    // 50MHz 时钟
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 1ms 的单周期节拍脉冲，等比例加速缩小到 1000ns
    initial begin
        ctrl_tick = 1'b0;
        forever begin
            repeat (49) @(posedge clk);
            ctrl_tick <= 1'b1;  // 产生 1 个时钟周期的脉冲
            @(posedge clk);
            ctrl_tick <= 1'b0;
        end
    end

    initial begin
        // 初始化
        rst_n       = 0;
        lqr_en      = 0;
        target_arm  = 0; pos_arm  = 0; vel_arm  = 0;
        target_pend = 512; pos_pend = 512; vel_pend = 0;

        // 异步复位，同步释放
        #100;
        @(posedge clk);
        rst_n <= 1;
        #200;
        
        // 开启 LQR 使能
        @(posedge clk);
        lqr_en <= 1'b1;

        // 1. 摆杆微小倾斜（偏离平衡点 5 个码字）
        // err_pend = 5，预期输出约为 k3 * 5 = 250，无饱和
        @(posedge clk);
        pos_pend <= 16'sd507;
        @(posedge ctrl_tick);          // 等待下一个节拍到来
        repeat (4) @(posedge clk);     // 延时 4 拍，等待流水线计算并锁存完成

        // 2. 摆杆正向大角度倾斜，触发正向饱和
        // err_pend = 512 - 400 = +112
        // 乘积将远超 2500，预期 u_lqr = 2500, sat_pos = 1
        @(posedge clk);
        pos_pend <= 16'sd400;
        @(posedge ctrl_tick);
        repeat (4) @(posedge clk);

        // 3. 摆杆反向大倾斜，触发反向饱和
        // err_pend = 512 - 650 = -138
        // 乘积将低于 -2500，预期 u_lqr = -2500, sat_neg = 1
        @(posedge clk);
        pos_pend <= 16'sd650;
        @(posedge ctrl_tick);
        repeat (4) @(posedge clk);

        // 4. 断开使能，验证断电保护
        @(posedge clk);
        lqr_en <= 1'b0;
        #200;
        
        $stop;
    end

endmodule