/*
LESO
*/
module leso #(
    parameter WIDTH_DATA = 32
) (
    input  wire clk,
    input  wire rst_n,
    input  wire t,  //离散化的周期间隔
    // 输入的数据
    input  wire signed [WIDTH_DATA-1:0] y,         //输入的实际角度
    input  wire signed [WIDTH_DATA-1:0] u_sum_old, //上一拍的电机实际占空比
    //输出的数据
    output reg  signed [WIDTH_DATA-1:0] z1,    //角度
    output reg  signed [WIDTH_DATA-1:0] z2,    //角速度
    output reg  signed [WIDTH_DATA-1:0] z3     //角加速度，z3/b0 = u(输出) 
);



endmodule //leso