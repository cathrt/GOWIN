/*
复位按键：异步复位，同步释放
*/
module rst_n_sync(
    input  wire rstn,
    input  wire clk,
    output wire rst_n
);
// 打两拍，消除亚稳态
reg rst_n_r1;
reg rst_n_r2;   // 安全电平
always @(posedge clk or negedge rstn) begin
    if(!rstn) begin 
        // 异步有效，进行复位，我们的复位还是异步的，只是释放的时候同步了
        // 不需要进行20ms延迟，因为按键抖动好多次 只是在重复 进行 复位，没有意义，不需要延迟
        rst_n_r1 <= 1'b0;
        rst_n_r2 <= 1'b0;
    end else begin
        // 一旦接收到时钟上升沿，恢复高电平，不再复位
        // 如果 异步复位 与 时钟上升沿 同时出现，我们先进行异步复位
        // 延迟了一拍，消除了亚稳态
        rst_n_r1 <= 1'b1;
        rst_n_r2 <= rst_n_r1;
    end
end

assign rst_n = rst_n_r2;

endmodule
