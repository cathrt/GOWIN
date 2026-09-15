/*
双环PID控制器
1. 垂直摆杆角度PID控制
2. 水平摆杆位置PID控制
*/

module pid #(
    //垂直摆杆参数
    parameter Kp_angle = 100,
    parameter Ki_angle = 10,
    parameter Kd_angle = 100,
    //水平摆杆参数，包含了角度 360/1040度，同时放大了256倍 
    parameter Kp_pos = 100,
    parameter Ki_pos = 10,
    parameter Kd_pos = 100
) (
    input  wire clk,
    input  wire rst_n,
    //PID控制信号
    input  wire pid_en,
    //PID数据处理周期，用离散信号代替连续处理
    input  wire angle_active,
    //垂直摆杆角度信息
    input  wire [16:0] angle_deg,
    input  wire [16:0] angle_vel,
    //水平摆杆位置信息
    input  wire [16:0] cur_pos,     //当前电机转动信息，1 代表 360/1040 度
    input  wire [16:0] cur_speed,   //当前实际速度
    //PID输出信号
    output wire [13:0] pid_data
);




endmodule