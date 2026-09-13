module swing (
    input  wire clk,
    input  wire rst_n,
    //输入使能
    input  wire swing_en,
    //输入的角度信息
    input  wire angle_active,
    input  wire signed [15:0] angle_deg,
    input  wire signed [15:0] angle_vel,
    //输出
    output reg  signed [15:0] swing_data
);



endmodule