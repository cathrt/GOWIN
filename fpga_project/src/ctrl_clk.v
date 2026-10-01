/*
1ms 节拍产生器
*/
module ctrl_clk #(
    parameter CLK_F  = 50_000_000,   // 系统时钟频率
    parameter CTRL_F = 1_000         // 控制节拍 1KHz
) (
    input  wire clk,
    input  wire rst_n,
    output wire ctrl_tick           // 控制节拍，单脉冲
);
// 自动计算控制周期
localparam integer TICK_PERIOD = CLK_F / CTRL_F;
localparam WIDTH = $clog2(TICK_PERIOD);

// 计数器产生 控制节拍
reg [WIDTH-1:0] tick_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_cnt  <= 'd0;
    end else if (tick_cnt >= TICK_PERIOD - 1) begin
        tick_cnt  <= 'd0;
    end else begin
        tick_cnt  <= tick_cnt + 1'b1;
    end
end

// 单时钟周期脉冲
assign ctrl_tick = (tick_cnt >= TICK_PERIOD - 1) ;

endmodule //adc_clk