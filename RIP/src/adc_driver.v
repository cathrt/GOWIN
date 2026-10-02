`timescale 1ns/1ps
/*
ADC数据采集模块
功能: 
    1. 在 clk_adc 下降沿锁存 10 位并行输入数据 ad_data
    2. 滑动平均滤波器，消除 传进来的ADC数据 的高频毛刺（clk_adc）域
*/
module adc_driver #(
    parameter integer WIDTH_DATA = 16   // 状态位宽 Q16.0
) (
    input  wire clk,             // 系统主控时钟 (50MHz)
    input  wire clk_adc,         // ADC 采样时钟 ( 12.5MHz 分频器)
    input  wire rst_n,

    // 数据输入 (来自 ADC 硬件引脚)
    input  wire [9:0]  ad_data,                   // ADC 10 位并行数据总线

    // 滤波输出
    output reg  [WIDTH_DATA-1:0] adc_data_flt,    // 滤波平滑码值 (0 ~ 1023, Q16.0)
    output reg  adc_valid                         // 50MHz 单周期数据更新使能脉冲
);

    // 从时钟上升沿到达，到输出引脚电平完全稳定，所需要的传播延迟时间 大约是 10ns，因此我们在下降沿采样
    // 产生下降沿，采用打两拍
    reg clk_adc_r1;     // 当前拍的值
    reg clk_adc_r2;     // 上一拍的值
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clk_adc_r1 <= 1'b0;
            clk_adc_r2 <= 1'b0;
        end else begin
            clk_adc_r1 <= clk_adc;
            clk_adc_r2 <= clk_adc_r1;
        end
    end
    wire clk_adc_neg = (!clk_adc_r1) && clk_adc_r2;     // 下降沿采样脉冲

    // 锁存ADC传进来的10位数据，在 clk_adc 下降沿采样，确保ADC内部输出数据稳定
    reg [9:0] ad_data_r1;   
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ad_data_r1 <= 10'd0;
        end else if(clk_adc_neg) begin
            ad_data_r1 <= ad_data;
        end
    end

    // 16 拍滑动平均滤波器
    // 递推公式：Sum[k] = Sum[k-1] + Din - Dout
    reg [9:0]  filter_window [0:15];            // 16 级移位寄存器组（滑动窗口），用于存放 16 组数据
    reg [13:0] filter_sum;                      // 16组数据之和，最大 1023 * 16 = 16368，需 14 位
    // 填充计数器（流水线预热）：5 位计数器，刚上电复位时，窗口里全是 0，需要数满 16 拍把窗口填满，防止初始阶段输出不真实的平均值
    reg [4:0]  fill_cnt;                
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                filter_window[i] <= 10'd0;
            end
            filter_sum <= 14'd0;
            fill_cnt <= 5'd0;
            adc_data_flt <= {WIDTH_DATA{1'b0}};
            adc_valid <= 1'b0;
        end else if(clk_adc_neg) begin

            filter_window[0] <= ad_data_r1;     // 将新数据存进窗口0
            //移位寄存器，存储 16组数据
            for (i = 0; i < 15; i = i + 1) begin
                filter_window[i+1] <= filter_window[i];
            end
            //递推公式计算
            filter_sum <= filter_sum + ad_data_r1 - filter_window[15];

            if (fill_cnt < 5'd16) begin
                fill_cnt <= fill_cnt + 1'b1;
                adc_valid <= 1'b0;
            end else begin
                // 除以 16，右移 4 位得到 10 位平均值，并自动按 16 位宽度扩展
                adc_data_flt <= (filter_sum + ad_data_r1 - filter_window[15]) >> 4;
                adc_valid <= 1'b1;       // 算完新数据，输出单周期 脉冲
            end
        end else begin
            adc_valid <= 1'b0;           // 单周期脉冲，下一拍立刻自动拉低
        end
    end

endmodule