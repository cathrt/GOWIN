`timescale 1ns/1ps

module uart_test;

    reg clk;
    reg rst_n;
    //控制信号激励
    reg angle_active;
    reg uart_en;
    //数据激励
    reg signed [15:0] angle_deg;
    reg signed [15:0] angle_vel;
    reg signed [31:0] cur_pos;
    reg signed [15:0] cur_speed;
    reg signed [15:0] duty_signed;
    //输出
    wire tx_data_out;

    //时钟激励
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    uart_tx_top # (
    .DECIM_N(DECIM_N),
    .TAIL_BYTE0(TAIL_BYTE0),
    .TAIL_BYTE1(TAIL_BYTE1),
    .TAIL_BYTE2(TAIL_BYTE2),
    .TAIL_BYTE3(TAIL_BYTE3),
    .BPS(BPS),
    .CLK_F(CLK_F)
  ) uut (
    .clk(clk),
    .rst_n(rst_n),
    .uart_en(uart_en),
    .angle_avtive(angle_avtive),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .cur_pos(cur_pos),
    .cur_speed(cur_speed),
    .duty_signed(duty_signed),
    .tx_data_out(tx_data_out)
  );

    //激励
    initial begin
        //初始化
        rst_n = 1'b0;
        uart_en = 1'b0;
        angle_active = 1'b0;
        angle_deg = 15'sd0;
        angle_vel = 15'sd0;
        cur_pos = 32'sd0;
        cur_speed = 15'sd0;
        duty_signed = 15'sd0;
        //复位激励
        #1_000 rst_n = 1'b1;
        #1_000;
        //打开上位机使能
        uart_en = 1'b1;

        //下降沿注入激励，上升沿让硬件采样，防止上升沿时 即注入激励，又采集数据，所产生的竞争冒险
        // 模拟倒立摆连续运行 12 个控制周期 (共 24ms)
        for (tick_cnt = 1; tick_cnt <= 12; tick_cnt = tick_cnt + 1) begin
            // 每一个 2ms 更新一次物理姿态参数
            @(negedge clk);
            angle_deg    <= -16'd500  + tick_cnt * 10;   // 负数补码测试: 0xFE0C
            angle_vel    <= 16'd1200  + tick_cnt * 5;    // 0x04B0
            cur_pos      <= 32'd65538 + tick_cnt * 100;  // 0x00010002
            cur_speed    <= -16'd20   + tick_cnt;        // 0xFFEC
            duty_signed  <= 16'd750;                     // 0x02EE

            // 产生严格持续 1 拍 (20ns) 的 500Hz 控制节拍
            angle_avtive <= 1'b1;
            @(negedge clk);
            angle_avtive <= 1'b0;

            // 保持 2ms (2_000_000ns - 20ns)，上面已经经过了一个时钟周期
            #1999980;
        end

        // 延迟2ms，留出“波形观察余量（Tail Margin）”
        #2000000;
        $display("[INFO] Simulation Finished Successfully.");
        $stop;
    end

    //设立一个虚拟接收串口数据的窗口
    localparam BPS_T = 8680; // 115200bps 单位时间约为 8680.5ns
    reg [7:0] rx_byte;  //一字节数据
    integer byte_idx;   //位编号

    initial begin
        forever begin
            // 检测起始位下降沿
            @(negedge uart_txd);
            #(BPS_T / 2); // 延时到起始位中心点

            if (uart_txd == 1'b0) begin
                #(BPS_T); // 跳到数据位第 0 位中心点

                // 依次采集 8 位数据
                for (byte_idx = 0; byte_idx < 8; byte_idx = byte_idx + 1) begin
                    rx_byte[byte_idx] = uart_txd;
                    #(BPS_T);
                end

                // 此时处于停止位中心
                $display("[UART RX] Time: %10t ps | Recv Byte: 0x%02X (%3d)", $time, rx_byte, rx_byte);
            end
        end
    end
    
endmodule //uart_test
