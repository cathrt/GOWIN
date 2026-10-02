`timescale 1ns/1ps
/*
安全检测模块
保护：
    （全流程）
    1. 按键停机
    2. 水平臂超程保护：防止水平臂向一个方向转动太多，导致连接的线被拧断
    （仅在 LQR 中保护）
    3. 电机持续饱和保护：防止电机长时间满占空比输出，产生堵转电流，导致电机线圈瞬间发烫，并在几十毫秒内击穿驱动板上的 H 桥 MOS 管
    4. 垂直摆杆超幅保护：防止摆杆一旦被甩出线性区时，LQR 失效，电机会在桌面上以极高的转速反复抽打，极易崩碎
*/
module safe_motor #(
    parameter integer WIDTH_DATA    = 16,
    parameter integer PROTECT_PEND  = 57,           // 垂直摆臂超限 20°，其码值约为 57
    parameter integer PROTECT_ARM   = 3120,         // 水平臂超限 3 圈
    parameter integer PROTECT_MOTOR = 1,            // 电机满占空比转动 1s
    parameter integer CLK_F         = 50_000_000    // 系统时钟
) (
    input  wire clk,
    input  wire rst_n,

    // LQR 使能标志，用于判断此时处于全流程 还是LQR 模块
    input  wire lqr_en,

    // 按键输入保护
    input  wire stop_key,   // 脉冲
    input  wire key_open,   // 开启工作，用于开启新一轮的安全保护

    // 垂直摆杆保护
    input  wire signed [WIDTH_DATA-1:0] pos_pend,
    input  wire signed [WIDTH_DATA-1:0] target_pend,

    //水平臂保护
    input  wire signed [WIDTH_DATA-1:0] pos_arm,

    // 电机保护
    input  wire sat_pos,    // 持续高电平
    input  wire sat_neg,

    // 输出
    output reg  stop_sig,           // 电机停止标志，持续高电平
    output reg  [2:0] stop_code     // 故障编码，用于调试
);

    localparam CNT_MAX = CLK_F * PROTECT_MOTOR;
    localparam WIDTH = $clog2(CNT_MAX);

    // 进行编码
    localparam integer NORMAL = 3'b000;     // 正常
    localparam integer KEY    = 3'b001;     
    localparam integer PEND   = 3'b010; 
    localparam integer ARM    = 3'b011;
    localparam integer MOTOR  = 3'b100;

    // 垂直摆杆保护
    wire signed [WIDTH_DATA-1:0] err_pend = pos_pend - target_pend;
    wire stop_pend =lqr_en && ((err_pend >= PROTECT_PEND) || err_pend <= -PROTECT_PEND);

    // 水平臂保护
    wire stop_arm = (pos_arm >= PROTECT_ARM) || (pos_arm <= -PROTECT_ARM);

    // 电机保护
    reg stop_motor;         // 电机保护开关
    reg [WIDTH-1:0] cnt;    // 计数器用于计时 1s
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= {WIDTH{1'b0}};
            stop_motor <= 1'b0;
        end else if (!lqr_en) begin
            // 不在 LQR 里
            cnt <= {WIDTH{1'b0}};
            stop_motor <= 1'b0;
        end else if(lqr_en && (sat_pos || sat_neg)) begin
            // 只在 LQR 且 满占空比 时计数加保护
            if (cnt >= CNT_MAX-1) begin
                stop_motor <= 1'b1;     // 计满 1s，持续拉高停机电平，不清零计数，只在解决完问题后清零计数
            end else begin
                cnt <= cnt + 1'b1;
                stop_motor <= 1'b0;
            end
        end else begin
            // 只要退出满占空比，立即归零复位
            cnt <= {WIDTH{1'b0}};
            stop_motor <= 1'b0;
        end
    end

    // 只要有任意一路异常，立即生成停机信号
    wire stop = stop_key || stop_arm || stop_pend || stop_motor;

    // 输出寄存器化，并对保护进行编码对应
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            stop_code <= 3'd0;
            stop_sig <= 1'b0;
        end else begin
            // 实时停机信号：发生时为 1，解除后为 0
            stop_sig <= stop;

            // 故障码：无异常时保持 NORMAL；发生异常时锁存首个触发源，不被后续连带故障覆盖
            // 如果按键打开，说明用户希望开启新一轮的安全保护，将故障码重置为正常
            if (key_open && !stop) begin
                stop_code <= NORMAL;
            end else if (stop_code == NORMAL) begin
                // 在正常时检测是否有故障发生
                if (stop_key)        stop_code <= KEY;
                else if (stop_arm)   stop_code <= ARM;
                else if (stop_pend)  stop_code <= PEND;
                else if (stop_motor) stop_code <= MOTOR;
            end
        end
    end

endmodule


