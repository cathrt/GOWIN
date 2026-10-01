`timescale 1ns/1ps
/*
测试内容： 复位信号，按键异步复位，同步释放
*/

module tb_rst_n;

    reg clk;
    reg rstn;

    wire rst_n;

    rst_n_sync  rst_n_sync_inst (
    .rstn(rstn),
    .clk(clk),
    .rst_n(rst_n)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz clock
    end

    initial begin
        rstn = 0;
        #100 
        rstn = 1;
        #100
        $stop;
    end


endmodule
