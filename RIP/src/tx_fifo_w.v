/*
FIFO写入模块
1. 接收 控制节拍，执行 8 分频降采样。
2. 在第 1 拍锁存 5 通道 16 位状态数据（角度、角速度、位置、速度、力矩），消除数据撕裂。
3. 随后连续写入 FIFO（10 字节数据 + 4 字节 VOFA+ 帧尾）
*/
module tx_fifo_w #(
    parameter integer WIDTH_DATA = 16,      // 状态数据位宽 (Q16.0)
    parameter integer WIDTH_BYTE = 8,
    parameter integer DECIM_N    = 8,       // 8分频：每 8 个 1ms (8ms) 打包一次
    
    // VOFA+ 协议帧尾字节
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE0 = 8'h00,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE1 = 8'h00,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE2 = 8'h80,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE3 = 8'h7F
)(
    input  wire clk,
    input  wire rst_n,

    // 控制端
    input  wire ctrl_tick,                 // 控制节拍，1ms

    // 要发送的数据
    input  wire signed [WIDTH_DATA-1:0] pos_pend,   // 垂直摆杆当前角度
    input  wire signed [WIDTH_DATA-1:0] vel_pend,   // 垂直摆杆角速度
    input  wire signed [WIDTH_DATA-1:0] pos_arm,    // 水平臂当前位置
    input  wire signed [WIDTH_DATA-1:0] vel_arm,    // 水平臂当前线速度
    input  wire signed [12:0] duty_signed,          //占空比数据

    // fifo写端口
    input  wire full_sig,                   //满信号
    output reg  [WIDTH_BYTE-1:0]  w_data,   //写数据
    output reg  w_en                        //写使能
);

    localparam WIDTH_CNT = $clog2(DECIM_N);

    // 8 分频, 降采样率，即 8 次数据中我们只采集第一次的数据
    // 同时我们确定只在第一次2ms的时候进行采样
    reg [WIDTH_CNT-1:0]cnt;     // 计数，每8次循环
    reg en_sample;              // 采样使能，只在计数第一次的时候采集数据
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 'd0;
            en_sample <= 1'b0;
        end else if(ctrl_tick) begin    // 在 1ms 之上进行计数
            if(cnt == DECIM_N - 1'b1) begin
                cnt <= 'd0;
                en_sample <= 1'b0;
            end else if(cnt == 'd1) begin
                en_sample <= 1'b1;  // 第一个2ms时拉高
                cnt <= cnt + 1'b1;
            end else begin
                cnt <= cnt + 1'b1;
                en_sample <= 1'b0;
            end
        end else begin
                en_sample <= 1'b0; // 系统周期脉冲
        end
    end

    // 5 通道数据 16 位符号位扩展锁存器
    reg signed [15:0] r_pos_pend;
    reg signed [15:0] r_vel_pend;
    reg signed [15:0] r_pos_arm;
    reg signed [15:0] r_vel_arm;
    reg signed [15:0] r_duty_signed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_pos_pend    <= 16'sd0;
            r_vel_pend    <= 16'sd0;
            r_pos_arm     <= 16'sd0;
            r_vel_arm     <= 16'sd0;
            r_duty_signed <= 16'sd0;
        end else if (en_sample && !full_sig) begin
            r_pos_pend    <= pos_pend;
            r_vel_pend    <= vel_pend;
            r_pos_arm     <= pos_arm;
            r_vel_arm     <= vel_arm;
            r_duty_signed <= {{3{duty_signed[12]}}, duty_signed}; // 13 位符号扩展为 16 位
        end
    end

    // 14 字节 (5通道 × 2字节 + 4字节帧尾)
    reg [3:0] state; // 0: 空闲; 1~14: 连续写入 14 字节

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state  <= 4'd0;
            w_en   <= 1'b0;
            w_data <= 8'd0;
        end else begin
            case (state)
                // 空闲状态：检测到采样使能且 FIFO 未满时启动
                4'd0: begin
                    w_en   <= 1'b0;
                    w_data <= 8'd0;
                    if (en_sample && !full_sig) begin
                        state <= 4'd1;
                    end
                end

                // 1: 摆杆当前角度 (2 字节，低位在前)
                4'd1: begin w_en <= 1'b1; w_data <= r_pos_pend[7:0];   state <= state + 1'b1; end
                4'd2: begin w_en <= 1'b1; w_data <= r_pos_pend[15:8];  state <= state + 1'b1; end

                // 2: 摆杆角速度 (2 字节)
                4'd3: begin w_en <= 1'b1; w_data <= r_vel_pend[7:0];   state <= state + 1'b1; end
                4'd4: begin w_en <= 1'b1; w_data <= r_vel_pend[15:8];  state <= state + 1'b1; end

                // 3: 水平臂位置 (2 字节)
                4'd5: begin w_en <= 1'b1; w_data <= r_pos_arm[7:0];    state <= state + 1'b1; end
                4'd6: begin w_en <= 1'b1; w_data <= r_pos_arm[15:8];   state <= state + 1'b1; end

                // 4: 水平臂速度 (2 字节)
                4'd7: begin w_en <= 1'b1; w_data <= r_vel_arm[7:0];    state <= state + 1'b1; end
                4'd8: begin w_en <= 1'b1; w_data <= r_vel_arm[15:8];   state <= state + 1'b1; end

                // 5: 输出占空比 (2 字节)
                4'd9:  begin w_en <= 1'b1; w_data <= r_duty_signed[7:0];  state <= state + 1'b1; end
                4'd10: begin w_en <= 1'b1; w_data <= r_duty_signed[15:8]; state <= state + 1'b1; end

                // VOFA+ 帧尾 (4 字节: 00 00 80 7F)
                4'd11: begin w_en <= 1'b1; w_data <= TAIL_BYTE0; state <= state + 1'b1; end
                4'd12: begin w_en <= 1'b1; w_data <= TAIL_BYTE1; state <= state + 1'b1; end
                4'd13: begin w_en <= 1'b1; w_data <= TAIL_BYTE2; state <= state + 1'b1; end
                4'd14: begin
                    w_en   <= 1'b1;
                    w_data <= TAIL_BYTE3; // 送出第 14 字节
                    state  <= 4'd0;       // 写入完毕，回归空闲态
                end

                default: begin
                    state  <= 4'd0;
                    w_en   <= 1'b0;
                    w_data <= 8'd0;
                end
            endcase
        end
    end

endmodule