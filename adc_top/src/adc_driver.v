/*
ADC数据采集模块
功能: 
    1. 在 clk_adc 下降沿锁存 10 位并行输入数据 ad_data
    2. 滑动平均滤波器，消除 传进来的ADC数据 的高频毛刺（clk_adc）域
    3. Toggle 脉冲同步器，将滤波数据安全无损送入 clk (50MHz) 域
*/
module adc_driver #(
    parameter integer WIDTH_DATA = 16   // 状态位宽 Q16.0
) (
    input  wire clk,             // 系统主控时钟 (50MHz)
    input  wire clk_adc,         // ADC 采样时钟 (来自顶层 PLL 12.5MHz)
    input  wire rst_n,

    // 数据输入 (来自 ADC 硬件引脚)
    input  wire [9:0]  ad_data,         // ADC 10 位并行数据总线

    // 滤波输出(clk)域
    output reg  [WIDTH_DATA-1:0] adc_data_flt,    // 滤波平滑码值 (0 ~ 1023, Q16.0)
    output reg  adc_valid        // 50MHz 单周期数据更新使能脉冲
);

//

// 从时钟上升沿到达，到输出引脚电平完全稳定，所需要的传播延迟时间 大约是 10ns，因此我们在下降沿采样
// 锁存ADC传进来的10位数据，在 clk_adc 下降沿采样，确保ADC内部输出数据稳定
reg [9:0] ad_data_r1;       // 该数据采集在clk_adc域

always @(negedge clk_adc or negedge rst_n) begin
    if (!rst_n)
        ad_data_r1 <= 10'd0;
    else
        ad_data_r1 <= ad_data;
end

// 16 拍滑动平均滤波器 (运行在 clk_adc 域)
// 递推公式：Sum[k] = Sum[k-1] + Din - Dout
reg [9:0]  filter_window [0:15];    // 16 级移位寄存器组（滑动窗口），用于存放 16 组数据
reg [13:0] filter_sum;              // 16组数据之和，最大 1023 * 16 = 16368，需 14 位
// 填充计数器（流水线预热）：5 位计数器，刚上电复位时，窗口里全是 0，需要数满 16 拍把窗口填满，防止初始阶段输出不真实的平均值
reg [4:0]  fill_cnt;                
reg [WIDTH_DATA-1:0] adc_flt_adc_domain;      // 滤波后的数据输出，Q16.0
reg update_toggle;                  // 电平翻转指示器：每当算出一个全新的滤波值，就翻转一次
integer i;
always @(posedge clk_adc or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 16; i = i + 1) begin
            filter_window[i] <= 10'd0;
        end
        filter_sum         <= 14'd0;
        fill_cnt           <= 5'd0;
        adc_flt_adc_domain <= {WIDTH_DATA{1'b0}};
        update_toggle      <= 1'b0;
    end else begin
        filter_window[0] <= ad_data_r1;     // 将新数据存进窗口0
        //移位寄存器，存储 16组数据
        for (i = 0; i < 15; i = i + 1) begin
            filter_window[i+1] <= filter_window[i];
        end
        //递推公式计算，
        filter_sum <= filter_sum + ad_data_r1 - filter_window[15];

        if (fill_cnt < 5'd16) begin
            fill_cnt <= fill_cnt + 1'b1;
        end else begin
            // 除以 16，右移 4 位得到 10 位平均值，并自动按 16 位宽度扩展
            adc_flt_adc_domain <= (filter_sum + ad_data_r1 - filter_window[15]) >> 4;
            update_toggle      <= ~update_toggle;
        end
    end
end

// CDC 跨时钟域脉冲同步 (12.5MHz -> 50MHz)
reg [2:0] toggle_sync;always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        toggle_sync  <= 3'b000;
        adc_data_flt <= {WIDTH_DATA{1'b0}};
        adc_valid    <= 1'b0;
    end else begin
        toggle_sync <= {toggle_sync[1:0], update_toggle};

        if (toggle_sync[2] ^ toggle_sync[1]) begin
            adc_data_flt <= adc_flt_adc_domain;
            adc_valid <= 1'b1;
        end else begin
            adc_valid <= 1'b0;
        end
    end
end

endmodule