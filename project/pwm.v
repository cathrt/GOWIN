/*
PWM波形发生器模块
1. 将输入的占空比值转换为PWM波形（2值化）输出
    PWM输出频率为20KHz
2. 将电机转向与PWM输出同步
*/
module pwm #(
    //PWM周期内最大的系统脉冲数，CLK_F(50MHz) / PWM_F(20KHz)
    parameter  DUTY_MAX = 2500
) (
        input  wire clk,
        input  wire rst_n,
        //输入
        input  wire [11:0] duty_unsigned, //无符号占空比
        input  wire motor_stop, //电机停止信号
        //输出
        output reg   pwm_out       //PWM波形输出
    );

    //PWM周期基准计数器
    reg [11:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 12'd0;
        end else if (cnt < DUTY_MAX - 1) begin
            cnt <= cnt + 1'b1; //计数器加1
        end else begin
            cnt <= 12'd0; //计数器清零
        end
    end

    //影子寄存器，仅在每个 PWM 周期的起始点（cnt == 0）同步载入新占空比
    //确保在该PWM周期内，按固定不变的占空比进行输出
    reg [11:0] duty_shadow;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty_shadow <= 12'd0;
        end else if (cnt == 12'd0) begin
            duty_shadow <= duty_unsigned;
        end
    end

    //输出端口寄存器化，根据当前计数器值和占空比值，输出PWM波形
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n | motor_stop) begin
            pwm_out <= 1'b0;
        end else if (cnt < duty_shadow) begin
            pwm_out <= 1'b1; //计数器小于占空比，输出高电平
        end else begin
            pwm_out <= 1'b0; //计数器大于等于占空比，输出低电平
        end
    end

    endmodule