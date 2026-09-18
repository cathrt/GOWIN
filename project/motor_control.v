/*
电机控制模块
1.控制电机的正转、反转和停止，
2.将占空比有符号数转换为无符号数，
3.输出限幅，范围为-2500~2500
*/
module motor_control #(
    //最大占空比，即T_PWM，即PWM周期内有多少系统时钟上升沿
    parameter [11:0] DUTY_MAX = 12'd2500
) (
        input  wire clk,
        input  wire rst_n,
        //输入
        input  wire signed [12:0] duty_signed,  //占空比有符号数
        input  wire motor_stop,                 //电机停止转动标志位
        //输出
        output reg  [11:0] duty_unsigned,       //占空比无符号数
        output reg  ain1,                       //电机驱动A相输入1
        output reg  ain2                        //电机驱动A相输入2
    );

    //求绝对值，转化为无符号数：正数取原码，负数取补码（反码+1）
    wire [12:0] abs_duty = ( duty_signed[12] == 1'b0) ? duty_signed : ~duty_signed + 1'b1;

    //输出端口寄存器化
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || motor_stop) begin
            duty_unsigned <= 12'd0;
            ain1 <= 1'b0;
            ain2 <= 1'b0;
        end else begin
            //限幅，范围为-2500~2500
            duty_unsigned <= (abs_duty > DUTY_MAX) ? DUTY_MAX : abs_duty[11:0]; 
            //控制正反转
            if (duty_signed[12] == 1'b0) begin  //正转
                ain1 <= 1'b1;   //A相输入1高电平
                ain2 <= 1'b0;   //A相输入2低电平
            end else begin                      //反转
                ain1 <= 1'b0;   //A相输入1低电平
                ain2 <= 1'b1;   //A相输入2高电平
            end
        end
    end

    endmodule