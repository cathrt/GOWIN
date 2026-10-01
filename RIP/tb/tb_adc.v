`timescale 1ns / 1ps
/*
测试内容:
    1. 是否产生 1ms 控制节拍脉冲
    2. 按键 是否能设立零点
    3. 摆杆摆动，其信号有什么变化
*/
module tb_adc;

    // 参数
    localparam integer WIDTH_DATA     = 16;
    localparam integer DEFAULT_OFFSET = 512;
    localparam integer LPF_SHIFT      = 2;
    localparam integer CLK_PERIOD     = 20;

    // 时钟激励
    reg clk;            // 50MHz 系统主频 (周期 20ns)
    reg clk_adc;        // 12.5MHz ADC 采样时钟 (周期 80ns)
    reg rst_n;

    // 控制端激励
    wire ctrl_tick;      // 1ms 控制节拍脉冲
    reg  key_calib;      // 按键单脉冲，设置零点

    // ADC 物理接口
    reg  [9:0] ad_data;  // 模拟外部 3PA1030 输出的 10 位数据
    wire ad_oe;
    wire ad_clk;

    // 观测信号
    wire signed [WIDTH_DATA-1:0] target_pend;
    wire signed [WIDTH_DATA-1:0] pos_pend;
    wire signed [WIDTH_DATA-1:0] vel_pend;
    wire signed [WIDTH_DATA-1:0] angle_err;
    wire calib_done;

    // 例化
    ctrl_clk #(
        .CLK_F (50_000_000), 
        .CTRL_F(1_000_000)        // 将 1ms 缩小到 50*20ns = 1us
    ) u_ctrl_clk (
        .clk      (clk),
        .rst_n    (rst_n),
        .ctrl_tick(ctrl_tick)
    );

    adc # (
    .WIDTH_DATA(WIDTH_DATA),
    .DEFAULT_OFFSET(DEFAULT_OFFSET),
    .LPF_SHIFT(LPF_SHIFT)
  )
  adc_inst (
    .clk(clk),
    .rst_n(rst_n),
    .ctrl_tick(ctrl_tick),
    .key_calib(key_calib),
    .ad_oe(ad_oe),
    .ad_clk(ad_clk),
    .ad_data(ad_data),
    .target_pend(target_pend),
    .pos_pend(pos_pend),
    .vel_pend(vel_pend),
    .angle_err(angle_err),
    .calib_done(calib_done)
  );

    // 时钟生成：50MHz 主时钟 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 12.5MHz ADC 专用采样时钟 (半周期 40ns)
    initial begin
        clk_adc = 0;
        forever #40 clk_adc = ~clk_adc;
    end

    // 仿真流程
    integer i;

    initial begin

        // 初始化
        rst_n = 0;
        key_calib = 0;
        ad_data = 10'd512;  // 模拟摆杆静止在 512 码值处

        // 异步复位，同步释放
        #100;
        @(posedge clk)
        rst_n <= 1;
        #200;

        // 1. 保持 512 码值不变，经历 4 个完整控制周期 (共 4000ns)，确保码值稳定
        ad_data = 10'd512;
        #4_000; // 运行 4000ns

        // 2. 按键 垂直零位校准
        // 当摆杆转到垂直向上位置 (757)，按下按键记录此时码值为目标码值
        ad_data = 10'd757; // 摆杆被扶正至 757
        #2_000;        // 等待滤波稳定

        @(posedge clk);
        key_calib <= 1'b1;  // 发送一个单周期高脉冲
        @(posedge clk);
        key_calib <= 1'b0;

        // 校准后：先充分静止等待 12 个周期 (12us)，让 512->757 的冲击彻底归零，即角速度回归0
        #12_000;

        // 3. 模拟摆杆左移，逆时针（正转） 每拍移动 10 个码值
        for (i = 757; i <= 857; i = i + 10) begin
            ad_data = i;
            #1_000; // 每拍递增 10
        end

        // 停在 857 处保持静止，观察速度平滑回落至 0
        ad_data = 10'd857;
        #10_000;    // 10个周期就可以

        // 4. 模拟摆杆右移，每拍减少 10 个码值，负速度（反转）
        for (i = 857; i >= 757; i = i - 10) begin
            ad_data = i;
            #1_000;
        end

        #5_000;

        $stop;
    end

endmodule