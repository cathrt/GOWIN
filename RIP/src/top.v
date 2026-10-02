`timescale 1ns/1ps

module top (
    input  wire clk,            // 50MHz 主时钟
    input  wire rstn,

    // 与按键接口
    input  wire [3:0] key_in,   // 4 路按键输入

    // 与 ADC 接口 
    output wire ad_clk,         // 12.5MHz 的 ADC 驱动时钟
    output wire ad_oe,          // ADC 输出使能信号 (常低)
    input  wire [9:0] ad_data,  // ADC 传出的 10 位数据

    // 与编码器接口
    input  wire encode_a,       // 编码器 A 相
    input  wire encode_b,       // 编码器 B 相

    // 与电机驱动芯片物理接口
    output wire ain1,           // 电机方向控制 1
    output wire ain2,           // 电机方向控制 2
    output wire pwm_out,        // 20kHz 电机调速 PWM 脉冲

    // 串口输出
    output wire tx_data_out,    // 串口发送管脚

    // 板载状态指示调试接口 (选接 LED)
    output wire [3:0] led       // 板载 LED 指示灯
);

    // 参数统一定义
    localparam integer WIDTH_DATA     = 16;           // 状态位宽 (Q16.0)
    localparam integer KEY_NUM        = 4;            // 按键数量
    localparam integer CLK_F          = 50_000_000;   // 主时钟频率
    localparam integer CTRL_F         = 1_000;        // 控制节拍频率 (1ms)
    localparam integer DEFAULT_OFFSET = 512;          // 默认零位偏置 (10位ADC中心值 0~1023)
    localparam integer LPF_SHIFT      = 2;            // 角速度一阶低通滤波系数位移量 (2: 1/4权重)
    localparam integer ANGLE_SWITCH   = 42;           // 起摆与 LQR 转换对应的码值 (约 15°)
    localparam integer WIDTH_K        = 32;           // 增益参数位宽 (Q16.16)
    localparam integer SHIFT_Q        = 16;           // 定点数还原右移位数
    localparam integer DUTY_MAX       = 2500;         // 20kHz PWM 最大满幅计数值

    // 串口通信相关参数
    localparam integer WIDTH_BYTE     = 8;		      // 字节位宽
    localparam integer DECIM_N        = 8;            // 8 分频，用于降低数据打包频率
    localparam  integer BPS           = 115200;       // 串口波特率
	// VOFA+ 协议帧尾
    localparam [WIDTH_BYTE-1:0] TAIL_BYTE0 = 8'h00;
    localparam [WIDTH_BYTE-1:0] TAIL_BYTE1 = 8'h00;
    localparam [WIDTH_BYTE-1:0] TAIL_BYTE2 = 8'h80;
    localparam [WIDTH_BYTE-1:0] TAIL_BYTE3 = 8'h7F;

    // 死区补偿参数，经测量为260，少取一点为240，剩下的交给增益参数
    localparam integer DEAD_ZONE      = 240;          // 电机死区补偿值，测死区时设为0
//    localparam integer STEP_TIME      = 20;           // 死区测试每 20ms 步进 1 占空比

    // 安全保护阈值参数
    localparam integer PROTECT_PEND   = 57;           // 摆杆跌倒限幅 (约 20°)
    localparam integer PROTECT_ARM    = 3120;         // 旋臂超程限幅 (3 圈)
    localparam integer PROTECT_MOTOR  = 1;            // 电机持续满幅保护时间 (1s)

    // LQR 增益参数 (Q16.16 格式)
    localparam signed [WIDTH_K-1:0] k1 = 32'sd10;      // 水平臂位置增益
    localparam signed [WIDTH_K-1:0] k2 = 32'sd10;      // 水平臂速度阻尼
    localparam signed [WIDTH_K-1:0] k3 = 32'sd10;      // 垂直摆杆角度刚度
    localparam signed [WIDTH_K-1:0] k4 = 32'sd10;      // 垂直摆杆角速度阻尼

    // 内部连线信号声明
    // 复位信号，按键异步复位，同步释放
    wire rst_n;   

    // 按键脉冲：[0] ADC校准, [1] 启动, [2] 手动急停停机
    wire [KEY_NUM-1:0] key_pulse;	//脉冲

    // 1ms 控制基准节拍
    wire ctrl_tick;	 // 脉冲

    // 垂直摆杆数据
    wire signed [WIDTH_DATA-1:0] target_pend;   // 摆杆垂直平衡零位
    wire signed [WIDTH_DATA-1:0] pos_pend;      // 实时摆杆角度
    wire signed [WIDTH_DATA-1:0] vel_pend;      // 实时摆杆角速度
    wire signed [WIDTH_DATA-1:0] angle_err;     // 动态角度偏差（调试用）
    wire calib_done;                            // 零点校准完成标志，脉冲

    // 水平臂数据
    wire signed [WIDTH_DATA-1:0] target_arm = 16'sd0; // 水平臂平衡目标位置始终为 0 点
    wire signed [WIDTH_DATA-1:0] pos_arm;       // 实时位置脉冲
    wire signed [WIDTH_DATA-1:0] vel_arm;       // 实时脉冲速度
    wire motor_dir;                             // 电机实际运转方向（调试用）

    // 主控状态
    wire lqr_en;                                // LQR 平衡使能
    wire swing_en;                              // 起摆使能
    wire pos_clr;                               // 进 LQR 时对水平臂清零单脉冲
    wire [1:0] state_out;                       // 当前状态: 00:IDLE, 01:SWING, 10:LQR, 11:STOP（调试用）

    // 安全信号
    wire stop_sig;                              // 停机标志，持续高电平
    wire [2:0] stop_code;                       // 首发故障码（调试用）

    // 算法控制量与饱和指示
    wire signed [WIDTH_DATA-1:0] u_lqr;         // LQR 计算输出
    wire sat_pos;                               // 正向满占空比标志（调试用）
    wire sat_neg;                               // 反向满占空比标志（调试用）
/*
    // 死区检测信号
    wire signed [WIDTH_DATA-1:0] duty_test;
    wire signed [WIDTH_DATA-1:0] dead_zone_val;
    wire test_done;
    
    // 电机驱动输入（死区测试模式）
    // 当前处于死区测试模式：使用 duty_test，并在测试完成瞬间封波停机
    wire signed [12:0] duty_signed = duty_test[12:0];
    // 测出死区后立即锁死电机输出，防止机械臂加速甩动  同时  保证安全保护
    wire motor_stop = test_done | stop_sig; 
*/
    // 电机驱动输入
    // 目前起摆模块尚未接入，处于 LQR 使能时送出算法输出，其余时间强制送 0
    wire signed [12:0] duty_signed = lqr_en ? u_lqr[12:0] : 16'sd0;
    // 只有在 lqr_en 或 swing_en 有效时电机才通电，其余时间强制封波停机
    wire motor_stop = !(lqr_en || swing_en);

    // 调试 LED 
    // 1. 停机保护时：led[3] 常亮代表报警，led[2:0] 完整直读 3 位故障码
    // 2. 正常工作时：led[3:2] 灭，led[1:0] 显示当前运行状态 (00:IDLE, 01:SWING, 10:LQR)
    assign led = (state_out == 2'b11) ? {1'b1, stop_code} : {2'b00, state_out};

    // 模块例化

    // 1. 复位同步模块
    rst_n_sync  rst_n_sync_inst (
    .rstn(rstn),
    .clk(clk),
    .rst_n(rst_n)
    );

    // 2. 按键消抖模块
    key #(
        .KEY_NUM(KEY_NUM)
    ) key_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .key_in   (key_in),
        .key_pulse(key_pulse)
    );

    // 3. 1ms 控制节拍生成器
    ctrl_clk #(
        .CLK_F (CLK_F),
        .CTRL_F(CTRL_F)
    ) ctrl_clk_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .ctrl_tick(ctrl_tick)
    );

    // 4. ADC 垂直摆杆模块
    adc #(
        .WIDTH_DATA    (WIDTH_DATA),
        .DEFAULT_OFFSET(DEFAULT_OFFSET),
        .LPF_SHIFT     (LPF_SHIFT)
    ) adc_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .ctrl_tick  (ctrl_tick),
        .key_calib  (key_pulse[0]),		// 按键 0 作为零点校准
        .ad_oe      (ad_oe),
        .ad_clk     (ad_clk),
        .ad_data    (ad_data),
        .target_pend(target_pend),
        .pos_pend   (pos_pend),
        .vel_pend   (vel_pend),
        .angle_err  (angle_err),
        .calib_done (calib_done)
    );

    // 5. 编码器水平臂模块
    decode #(
        .WIDTH_DATA(WIDTH_DATA)
    ) decode_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .pos_clr  (pos_clr),
        .ctrl_tick(ctrl_tick),
        .encode_a (encode_a),
        .encode_b (encode_b),
        .motor_dir(motor_dir),
        .pos_arm  (pos_arm),
        .vel_arm  (vel_arm)
    );

    // 6. 安全检测模块
    safe_motor #(
        .WIDTH_DATA    (WIDTH_DATA),
        .PROTECT_PEND  (PROTECT_PEND),
        .PROTECT_ARM   (PROTECT_ARM),
        .PROTECT_MOTOR (PROTECT_MOTOR),
        .CLK_F         (CLK_F)
    ) safe_motor_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .lqr_en     (lqr_en),
        .key_open   (key_pulse[1]),     // 按键 1 作为新一轮安全保护的开启信号
        .stop_key   (key_pulse[2]),     // 按键 2 作为手动急停
        .pos_pend   (pos_pend),
        .target_pend(target_pend),
        .pos_arm    (pos_arm),
        .sat_pos    (sat_pos),
        .sat_neg    (sat_neg),
        .stop_sig   (stop_sig),
        .stop_code  (stop_code)
    );

    // 7. 主控状态机
    control #(
        .WIDTH_DATA  (WIDTH_DATA),
        .ANGLE_SWITCH(ANGLE_SWITCH)
    ) control_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .key_open  (key_pulse[1]),       // 按键 1 作为启动开关
        .stop_sig  (stop_sig),
        .calib_done(calib_done),
        .angle_err (angle_err),
        .lqr_en    (lqr_en),
        .swing_en  (swing_en),
        .pos_clr   (pos_clr),
        .state_out (state_out)
    );

    // 8. LQR 平衡运算模块
    lqr #(
        .WIDTH_DATA(WIDTH_DATA),
        .WIDTH_K   (WIDTH_K),
        .SHIFT_Q   (SHIFT_Q),
        .DUTY_MAX  (DUTY_MAX),
        .k1        (k1),
        .k2        (k2),
        .k3        (k3),
        .k4        (k4)
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

    // 9. 电机 PWM 与方向驱动模块
    motor # (
        .DUTY_MAX(DUTY_MAX),
        .DEAD_ZONE(DEAD_ZONE)
    )motor_inst (
        .clk(clk),
        .rst_n(rst_n),
        .duty_signed(duty_signed),
        .motor_stop(motor_stop),
        .ain1(ain1),
        .ain2(ain2),
        .pwm_out(pwm_out)
    );
/*
    // 10. 死区检测模块
    dead_zone_test # (
        .WIDTH_DATA(WIDTH_DATA),
        .DUTY_MAX(DUTY_MAX),
        .STEP_TIME(STEP_TIME)
    ) dead_zone_test_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ctrl_tick(ctrl_tick),
        .key_dead(key_pulse[3]),        // 按键 4 开启死区
        .pos_arm(pos_arm),
        .duty_test(duty_test),
        .dead_zone_val(dead_zone_val),
        .test_done(test_done)
    );
*/

    // 11. 串口发送模块
    uart_tx_top # (
        .WIDTH_DATA(WIDTH_DATA),
        .WIDTH_BYTE(WIDTH_BYTE),
        .DECIM_N(DECIM_N),
        .TAIL_BYTE0(TAIL_BYTE0),
        .TAIL_BYTE1(TAIL_BYTE1),
        .TAIL_BYTE2(TAIL_BYTE2),
        .TAIL_BYTE3(TAIL_BYTE3),
        .BPS(BPS),
        .CLK_F(CLK_F)
    ) uart_tx_top_inst (
        .clk(clk),
        .rst_n(rst_n),
        .uart_en(1'b1),
        .ctrl_tick(ctrl_tick),
        .pos_pend(pos_pend),
        .vel_pend(vel_pend),
        .pos_arm(pos_arm),
        .vel_arm(vel_arm),
        .duty_signed(duty_signed),
        .tx_data_out(tx_data_out)
    );

endmodule