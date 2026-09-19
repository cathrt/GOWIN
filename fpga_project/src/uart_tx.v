/*
串口发送模块
1.BPS发生器，即串口发送的时序,采用115200bps
2.并行（1字节）转串行
*/
module uart_tx #(
    parameter WIDTH_BYTE = 8,
    parameter BPS   = 17'd115200,
    parameter CLK_F = 26'd50_000_000
)(
    input  wire clk,
    input  wire rst_n,
    //输入
    input  wire tx_en,          //数据开始发送标志，脉冲
    input  wire [WIDTH_BYTE-1:0] tx_data,  //数据
    //输出
    output reg  tx_done_sig,    //完成信号，脉冲
    output reg  tx_data_out     //向上位机输出的数据
);

localparam BPS_T = CLK_F / BPS;
localparam WIDTH = $clog2(BPS_T);

//BPS发生器
reg [WIDTH-1:0]cnt; //计数器
reg bps_en;         //长时间高电平的使能信号
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt <= 'd0;
    end else if(bps_en) begin
        if(cnt == BPS_T-1) begin
            cnt <= 'd0;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end else if(tx_en) begin
        cnt <= 'd0; //一旦接收到一字节数据开始发送标志，计数器清零
    end else begin
        cnt <= 'd0;
    end
end
//BPS时钟脉冲，单周期
wire bps_pluse = (cnt == BPS_T-1);   

//发送状态机
reg [3:0] state;
reg [7:0] r_tx_data;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= 4'd0;
        tx_done_sig <= 1'b0;
        tx_data_out <= 1'b1;    //常态下是1
    end else begin
        case(state)
            //空闲状态
            4'd0: begin
                tx_done_sig <= 1'b0;
                tx_data_out <= 1'b1;
                if(tx_en) begin
                    state <= state + 1'b1;  //接收到发送时能信号
                    bps_en <= 1'b1;         //开启BPS计数器
                    r_tx_data <= tx_data;   // 立即锁存待发字节
                    tx_data_out <= 1'b0;    //开始位固定为0
                end
            end
            //开始位
            4'd1: begin
                if(bps_pluse) begin
                    state <= state + 1'b1;  //接收到BPS时钟脉冲
                    tx_data_out <= r_tx_data[0];  //输出第一位数据
                end
            end
            //数据位
            4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
                if(bps_pluse) begin
                    state <= state + 1'b1;  //接收到BPS时钟脉冲
                    tx_data_out <= r_tx_data[state-1];  //输出一位数据
                end
            end
            //停止位
            4'd9: begin
                if(bps_pluse) begin
                    state <= state + 1'b1;  //接收到BPS时钟脉冲
                    tx_data_out <= 1'b1;    //停止位为1
                    tx_done_sig <= 1'b1;    //完成信号，马上回到状态0，置0，即产生一个脉冲
                end
            end
            //输出完成信号，并关闭BPS计数器
            4'd10: begin
                if(bps_pluse) begin
                    state <= 4'd0;          //接收到BPS时钟脉冲
                    bps_en <= 1'b0;         //关闭BPS计数器
                    tx_done_sig <= 1'b1;    //完成信号，马上回到状态0，置0，即产生一个脉冲
                end
            end
            default: begin
                state       <= 4'd0;
                bps_en      <= 1'b0;
                tx_data_out <= 1'b1;
            end
        endcase
    end
end

endmodule //uart_tx