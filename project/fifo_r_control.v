/*
串口读取FIFO模块
读取FIFO数据并传入串口发送模块，接受顶层控制
*/
module fifo_r_control (
    input  wire clk,
    input  wire rst_n,
    //上层模块的控制信号
    input  wire uart_en,   //顶层控制串口发送的开关，持续高电平
    //FIFO数据，已经将数据进行了切片，已经包含了正负号，不能将切片成的数据转化成有符号数
    input  wire [7:0] r_data,
    output reg  r_en,
    input  wire empty_sig,
    //串口发送模块信息
    output reg  [7:0] tx_data,
    input  wire tx_done_sig,
    output reg  tx_en
);

//状态机
reg [1:0] state;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= 2'd0;
    end else begin
        case(state)
            //空闲状态，等待顶层控制串口发送的开关
            2'd0: begin
                r_en <= 1'b0;
                tx_en <= 1'b0;
                if(uart_en && !empty_sig) begin
                    state  <= state + 1'b1;
                end
            end
            //将数据传入串口发送模块，在一拍内完成
            2'd1: begin
                r_en <= 1'b1;
                tx_data <= r_data;
                tx_en <= 1'b1;
                state <= state + 1'b1;
            end
            //空闲状态，等待串口发送模块的完成信号
            2'd2: begin
                r_en <= 1'b0;
                tx_en <= 1'b0;
                if(tx_done_sig) begin
                    state <= 2'd0;
                end
            end
            default: begin
                state <= 2'd0;
                r_en  <= 1'b0;
                tx_en <= 1'b0;
            end
        endcase
    end
end

endmodule 