`timescale 1ns/1ps
/*
测试内容：串口数据和时序是否正确
*/
module tb_uart_tx;

    // 参数
    localparam integer WIDTH_BYTE  = 8;
    localparam integer BPS         = 1_000_000;         // 原本是115200，缩小成1_000_000
    localparam  integer CLK_F      = 50_000_000;
    localparam  integer CLK_PERIOD = 20;                // 时钟周期，单位ns

    // 测试信号
    reg  clk;
    reg  rst_n;
    reg  tx_en;
    reg  [WIDTH_BYTE-1:0] tx_data;      // 输入的一字节数据

    // 观测信号
    wire tx_data_out;  // 串口发送的数据输出
    wire tx_done_sig;                   // 发送完成信号

    // 例化
    uart_tx # (
        .WIDTH_BYTE(WIDTH_BYTE),
        .BPS(BPS),
        .CLK_F(CLK_F)
    ) uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_en(tx_en),
        .tx_data(tx_data),
        .tx_done_sig(tx_done_sig),
        .tx_data_out(tx_data_out)
    );

    // 时钟信号生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk; 
    end

    // 激励流程
    initial begin
        // 初始化
        rst_n = 0;
        tx_en = 0;
        tx_data = 8'b0;

        // 异步复位，同步释放
        #100;
        @(posedge clk)
        rst_n = 1;
        #200;

        // 发送一个测试数据
        @(posedge clk);
        tx_data <= 8'b1010_1010;
        // 使能发送，一个脉冲
        tx_en   <= 1'b1;
        @(posedge clk);
        tx_en   <= 1'b0;

        // 等待10个周期，看看有没有发送完成信号，10*20ns*50 = 10_000ns
        #10_000; 

        #100;
        $stop;
    end

endmodule


