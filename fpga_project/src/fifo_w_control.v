/*
FIFO写入模块
1. 接收 500Hz (2ms) 主采样节拍，执行 5 分频降采样（实现 10ms / 100Hz 传输周期）。
2. 在第 1 拍锁存 5 通道 32 位状态数据（角度、角速度、位置、速度、力矩），消除数据撕裂。
3. 随后以 50MHz 时钟连续 22 拍突发写入 FIFO（18 字节数据 + 4 字节 VOFA+ 帧尾）
*/
module fifo_w_control#(
    parameter WIDTH_DATA = 32,
    parameter WIDTH_BYTE = 8,
    parameter integer DECIM_N = 5,          // 500Hz / 5 = 100Hz (每 10ms 打包一次)(5分频)
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE0 = 8'h00,      // VOFA+ 协议帧尾
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE1 = 8'h00,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE2 = 8'h80,
    parameter [WIDTH_BYTE-1:0] TAIL_BYTE3 = 8'h7F
)(
    input  wire clk,
    input  wire rst_n,
    //传送的节拍,500Hz,即2ms
    input  wire angle_avtive,
    //要发送的数据
    input  wire signed [WIDTH_DATA-1:0] angle_deg,    //摆杆当前角度
    input  wire signed [WIDTH_DATA-1:0] angle_vel,    //摆杆角速度
    input  wire signed [WIDTH_DATA-1:0] cur_pos,      //水平臂位置
    input  wire signed [WIDTH_DATA-1:0] cur_speed,    //水平臂线速度
    input  wire signed [12:0] duty_signed,  //占空比数据
    //fifo写端口
    input  wire full_sig,      //满信号
    output reg  [WIDTH_BYTE-1:0]  w_data,  //写数据
    output reg  w_en            //写使能
);

localparam WIDTH_CNT = $clog2(DECIM_N);

// 5分频,降采样率，即5次数据中我们只采集第一次的数据
// 同时我们确定只在第一次2ms的时候进行采样
reg [WIDTH_CNT-1:0]cnt; // 计数，每5次循环
reg en_smaple;      // 采样使能，只在计数第一次的时候采集数据
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt <= 'd0;
        en_smaple <= 1'b0;
    end else if(angle_avtive) begin    // 在2ms之上进行计数
        if(cnt == DECIM_N - 1'b1) begin
            cnt <= 'd0;
            en_smaple <= 1'b0;
        end else if(cnt == 'd1) begin
            en_smaple <= 1'b1;  // 第一个2ms时拉高
            cnt <= cnt + 1'b1;
        end else begin
            cnt <= cnt + 1'b1;
            en_smaple <= 1'b0;
        end
    end else begin
            en_smaple <= 1'b0; // angle_active 走后立即拉低，保证其是 系统周期脉冲，杜绝en_smaple在接下来的2ms内一直保持高电平
    end
end

// 锁存传进来的数据，只在第一拍（系统时钟）的时候进行锁存
reg signed [WIDTH_DATA-1:0] r_angle_deg;
reg signed [WIDTH_DATA-1:0] r_angle_vel;
reg signed [WIDTH_DATA-1:0] r_cur_pos;
reg signed [WIDTH_DATA-1:0] r_cur_speed;
// 12位数据不支持，必须拓展为 16 位
reg signed [15:0] r_duty_signed;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_angle_deg <= 32'sd0;
        r_angle_vel <= 32'sd0;
        r_cur_pos   <= 32'sd0;
        r_cur_speed <= 16'sd0;
        r_duty_signed  <= 16'd0;
    end else if (en_smaple && !full_sig) begin
        r_angle_deg   <= angle_deg;
        r_angle_vel   <= angle_vel;
        r_cur_pos     <= cur_pos;
        r_cur_speed   <= cur_speed;
        r_duty_signed <= {{3{duty_signed[12]}}, duty_signed};
    end
end

//状态机
reg [4:0] state; // 0: 空闲; 1~16: 依次写入 16 个字节

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= 5'd0;
        w_en <= 1'b0;
        w_data <= 8'd0;
    end else begin
        case (state)
            // 空闲态：检测到采样触发且 FIFO 未满时，跳入第 1 状态
            5'd0: begin
                w_en   <= 1'b0;
                w_data <= 8'd0;
                if (en_smaple && !full_sig) begin
                    state <= 5'd1;
                end
            end

            // 1: 摆杆当前角度 (4 字节)
            5'd1: begin
                w_en   <= 1'b1;
                w_data <= r_angle_deg[7:0];
                state  <= state + 1'b1;
            end
            5'd2: begin
                w_en   <= 1'b1;
                w_data <= r_angle_deg[15:8];
                state  <= state + 1'b1;
            end
            5'd3: begin
                w_en   <= 1'b1;
                w_data <= r_angle_deg[23:16];
                state  <= state + 1'b1;
            end
            5'd4: begin
                w_en   <= 1'b1;
                w_data <= r_angle_deg[31:24];
                state  <= state + 1'b1;
            end

            // 2: 摆杆角速度 (4 字节)
            5'd5: begin
                w_en   <= 1'b1;
                w_data <= r_angle_vel[7:0];
                state  <= state + 1'b1;
            end
            5'd6: begin
                w_en   <= 1'b1;
                w_data <= r_angle_vel[15:8];
                state  <= state + 1'b1;
            end
            5'd7: begin
                w_en   <= 1'b1;
                w_data <= r_angle_vel[23:16];
                state  <= state + 1'b1;
            end
            5'd8: begin
                w_en   <= 1'b1;
                w_data <= r_angle_vel[31:24];
                state  <= state + 1'b1;
            end

            // 3: 水平臂位置 (4 字节，低位在前)
            5'd9: begin
                w_en   <= 1'b1;
                w_data <= r_cur_pos[7:0];
                state  <= state + 1'b1;
            end
            5'd10: begin
                w_en   <= 1'b1;
                w_data <= r_cur_pos[15:8];
                state  <= state + 1'b1;
            end
            5'd11: begin
                w_en   <= 1'b1;
                w_data <= r_cur_pos[23:16];
                state  <= state + 1'b1;
            end
            5'd12: begin
                w_en   <= 1'b1;
                w_data <= r_cur_pos[31:24];
                state  <= state + 1'b1;
            end

            // 4: 水平臂线速度 (4 字节)
            5'd13: begin
                w_en   <= 1'b1;
                w_data <= r_cur_speed[7:0];
                state  <= state + 1'b1;
            end
            5'd14: begin
                w_en   <= 1'b1;
                w_data <= r_cur_speed[15:8];
                state  <= state + 1'b1;
            end
            5'd15: begin
                w_en   <= 1'b1;
                w_data <= r_cur_speed[23:16];
                state  <= state + 1'b1;
            end
            5'd16: begin
                w_en   <= 1'b1;
                w_data <= r_cur_speed[31:24];
                state  <= state + 1'b1;
            end

            // CH5: 输出力矩占空比 (2 字节)
            5'd17: begin
                w_en   <= 1'b1;
                w_data <= r_duty_signed[7:0];
                state  <= state + 1'b1;
            end
            5'd18: begin
                w_en   <= 1'b1;
                w_data <= r_duty_signed[15:8];
                state  <= state + 1'b1;
            end

            // VOFA+ 协议尾帧 (4 字节)
            5'd19: begin
                w_en   <= 1'b1;
                w_data <= TAIL_BYTE0;
                state  <= state + 1'b1;
            end
            5'd20: begin
                w_en   <= 1'b1;
                w_data <= TAIL_BYTE1;
                state  <= state + 1'b1;
            end
            5'd21: begin
                w_en   <= 1'b1;
                w_data <= TAIL_BYTE2;
                state  <= state + 1'b1;
            end
            5'd22: begin
                w_en   <= 1'b1;
                w_data <= TAIL_BYTE3; // 送出最后一个尾帧字节
                state  <= 5'd0;       // 存完 16 字节，下一拍回归空闲态
            end

            default: begin
                state  <= 5'd0;
                w_en   <= 1'b0;
                w_data <= 8'd0;
            end
        endcase
    end
end

endmodule