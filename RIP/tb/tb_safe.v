`timescale 1ns/1ps
/*
测试内容：
    1. 按键停机
    2. 水平臂超限
    3. 垂直摆杆偏差过大
    4. 电机持续满占空比 超1s
*/
module tb_safe;

    // 参数
    parameter integer WIDTH_DATA    = 16;
    parameter integer PROTECT_PEND  = 57;           // 垂直摆臂超限 20°，其码值约为 57
    parameter integer PROTECT_ARM   = 3120;         // 水平臂超限 3 圈
    parameter integer PROTECT_MOTOR = 1;            // 电机满占空比转动 1s
    parameter integer CLK_F         = 100;          // 系统时钟，因为 1s 时间太长，我们用 2us 来代替
    parameter integer CLK_PERIOD    = 20;

    // 激励信号
    reg  clk;
    reg  rst_n;
    reg  lqr_en;        // 持续高电平
    reg  stop_key;      // 脉冲
    reg  signed [WIDTH_DATA-1:0] pos_pend;
    reg  signed [WIDTH_DATA-1:0] target_pend;
    reg  signed [WIDTH_DATA-1:0] pos_arm;
    reg  sat_pos;       // 持续高电平
    reg  sat_neg;

    // 观测信号
    wire stop_sig;
    wire [2:0] stop_code;

    // 例化
    safe_motor # (
    .WIDTH_DATA(WIDTH_DATA),
    .PROTECT_PEND(PROTECT_PEND),
    .PROTECT_ARM(PROTECT_ARM),
    .PROTECT_MOTOR(PROTECT_MOTOR),
    .CLK_F(CLK_F)
  )
  safe_motor_inst (
    .clk(clk),
    .rst_n(rst_n),
    .lqr_en(lqr_en),
    .stop_key(stop_key),
    .pos_pend(pos_pend),
    .target_pend(target_pend),
    .pos_arm(pos_arm),
    .sat_pos(sat_pos),
    .sat_neg(sat_neg),
    .stop_sig(stop_sig),
    .stop_code(stop_code)
  );

    // 时钟生成：50MHz 主时钟 (周期 20ns)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 激励流程
    initial begin
        rst_n = 1'b0;
        lqr_en = 1'b0;
        stop_key = 1'b0;
        pos_pend = 16'sd575;
        target_pend = 16'sd600;
        pos_arm = 1040;
        sat_pos = 1'b0;
        sat_neg = 1'b0;

        // 异步复位，同步释放
        #100;
        @(posedge clk)
        rst_n <= 1;
        #200;

        // 1. 按键停机
        @(posedge clk)
        stop_key <= 1'b1;
        @(posedge clk)
        stop_key <= 1'b0;
        #200;

        // 2. 水平臂超程保护
        @(posedge clk);
        pos_arm <= 16'sd3200; // 模拟旋臂甩出 3 圈
        #200;
        @(posedge clk);
        pos_arm <= 16'sd100;  // 转回安全区域
        #200;

        // 3. 垂直摆杆
        // （1）起摆态 (lqr_en = 0)，摆杆大角度晃动，stop_sig = 0
        @(posedge clk);
        pos_pend <= 16'sd500; // 远超 57
        #200;

        // （2）平衡态 (lqr_en = 1)，摆杆脱出平衡区，stop_sig = 1
        @(posedge clk);
        lqr_en <= 1'b1;
        #200;
        @(posedge clk);
        pos_pend <= 16'sd600;   // 恢复垂直小角度
        #200;

        // 4. 电机保护
        // （1）短时满占空比，计数器自动清零
        @(posedge clk);
        sat_pos <= 1'b1;
        repeat(50) @(posedge clk); // 仅持续 50 拍 (< 100)
        @(posedge clk);
        sat_pos <= 1'b0;          // 退出饱和
        #200;

        // （2）持续满幅超时，持续超过 100 拍
        @(posedge clk);
        sat_neg <= 1'b1;
        repeat(120) @(posedge clk); // 持续 120 拍
        @(posedge clk);
        sat_neg <= 1'b0;
        lqr_en  <= 1'b0;
        #500;

        $stop;


    end



endmodule
