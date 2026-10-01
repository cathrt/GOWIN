`timescale 1ns/1ps
/*
ADC 驱动时钟生成模块
功能：将主时钟 4分频成 12.5MHz 时钟
*/
module adc_clk (
    input  wire clk,
    input  wire rst_n,
    output wire clk_adc
);

reg [1:0] cnt;
// 每个时钟上升沿改变一次，[1]位两个上升沿变化一次
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt <= 2'b00;
    else
        cnt <= cnt + 1'b1;
end

// cnt 的变化规律: 00 -> 01 -> 10 -> 11
// cnt[1] 的电平:   0  ->  0  ->  1  ->  1 (完美 4分频方波)
assign clk_adc = cnt[1];

endmodule

