`timescale 1ns / 1ps

module tb_adc;

    // 参数定义
    parameter integer WIDTH_DATA     = 16;
    parameter integer DEFAULT_OFFSET = 512;
    parameter integer LPF_SHIFT      = 2;

    // 激励信号声明
    reg        clk;
    reg        clk_adc;
    reg        rst_n;
    reg        ctrl_tick;
    reg        key_calib;
    reg  [9:0] ad_data;

    // 观测输出信号
    wire        ad_oe;
    wire        ad_clk;
    wire signed [WIDTH_DATA-1:0] target_pend;
    wire signed [WIDTH_DATA-1:0] pos_pend;
    wire signed [WIDTH_DATA-1:0] vel_pend;
    wire signed [WIDTH_DATA-1:0] angle_err;
    wire        calib_done;

    // -------------------------------------------------------------------------
    // 1. 例化待测顶层模块 (DUT)
    // -------------------------------------------------------------------------
    adc #(
        .WIDTH_DATA     (WIDTH_DATA),
        .DEFAULT_OFFSET (DEFAULT_OFFSET),
        .LPF_SHIFT      (LPF_SHIFT)
    ) dut (
        .clk          (clk),
        .clk_adc      (clk_adc),
        .rst_n        (rst_n),
        .ctrl_tick    (ctrl_tick),
        .key_calib    (key_calib),
        .ad_oe        (ad_oe),
        .ad_clk       (ad_clk),
        .ad_data      (ad_data),
        .target_pend  (target_pend),
        .pos_pend     (pos_pend),
        .vel_pend     (vel_pend),
        .angle_err    (angle_err),
        .calib_done   (calib_done)
    );

    // -------------------------------------------------------------------------
    // 2. 双时钟源生成 (严格对齐相位)
    // -------------------------------------------------------------------------
    // 主系统时钟: 50MHz (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ADC 采样时钟: 12.5MHz (周期 80ns，4 分频)
    initial begin
        clk_adc = 1'b0;
        forever #40 clk_adc = ~clk_adc;
    end

    // 控制周期节拍 ctrl_tick (仿真中缩短为每 10us 产生一次单拍脉冲，加速观察)
    initial begin
        ctrl_tick = 1'b0;
        forever begin
            #9980; // 延时 9.98us
            @(posedge clk);
            ctrl_tick = 1'b1;
            @(posedge clk);
            ctrl_tick = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 3. 3PA1030 芯片硬件行为模型仿真
    // -------------------------------------------------------------------------
    reg [9:0] ideal_pend_angle; // 摆杆物理真实角度 (理想无噪声码值)
    integer   noise_val;

    // 芯片在输出时钟上升沿采样，并在 t_OD 传播延迟后驱动数据管脚
    always @(posedge ad_clk) begin
        #8; // 模拟硬件传输延迟 t_OD ≈ 8ns
        // 叠加 ±2 的随机高频电磁噪声，模拟减速电机 PWM 干扰
        noise_val = $random % 3; 
        ad_data   <= ideal_pend_angle + noise_val;
    end

    // -------------------------------------------------------------------------
    // 4. 仿真测试主流程
    // -------------------------------------------------------------------------
    initial begin
        // 初始化状态
        rst_n            = 1'b0;
        key_calib        = 1'b0;
        ideal_pend_angle = 10'd520; // 模拟开机摆杆手扶在 520 码值附近
        ad_data          = 10'd520;

        // 系统复位 200ns
        #200;
        @(posedge clk);
        rst_n = 1'b1;
        $display("[Time: %0t ns] 系统复位释放，开始预热滑动滤波窗口...", $time);

        // 等待 ADC 预热满 16 拍并完成平滑输出
        #2000;

        // 步骤一：触发 SW1 按键标定当前零位
        @(posedge clk);
        key_calib = 1'b1;
        @(posedge clk);
        key_calib = 1'b0;
        $display("[Time: %0t ns] 按下 SW1 校准键，锁存当前零位...", $time);

        #1000;
        if (calib_done && (target_pend >= 518 && target_pend <= 522)) begin
        end else begin
            $display("[FAIL] 零位校准异常! target_pend = %0d, calib_done = %b", target_pend, calib_done);
        end

        // 步骤二：模拟摆杆向右倾斜 (产生正向角速度)
        repeat (40) begin
            #500;
            ideal_pend_angle = ideal_pend_angle + 10'd2; // 角度持续递增
        end

        // 步骤三：模拟摆杆在 600 码值处维持静止 (观察角速度归零过程)
        ideal_pend_angle = 10'd600;
        #50000; // 运行 50us 观察一阶低通滤波收敛

        $stop;
    end

endmodule