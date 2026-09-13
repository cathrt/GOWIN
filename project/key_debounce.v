module key_debounce (
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,     // 外部异步按键引脚 (按下为低电平)
    output reg  key_pulse   // 单时钟周期有效脉冲
);

    // 计算计数值与寄存器位宽
    localparam integer CLK_FREQ = 50_000_000;   //系统时钟
    localparam integer DELAY_MS = 20;           //机械延时20MS
    localparam integer CNT_MAX  = (CLK_FREQ / 1000) * DELAY_MS; 
    localparam integer WIDTH    = $clog2(CNT_MAX);

    // 1. 打三拍：前两级消除亚稳态，第三级用于捕捉跳变沿
    reg key_r0, key_r1, key_r2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_r0 <= 1'b1;
            key_r1 <= 1'b1;
            key_r2 <= 1'b1;
        end else begin
            key_r0 <= key_in;
            key_r1 <= key_r0;
            key_r2 <= key_r1;
        end
    end

    // 2. 边沿检测：按键产生任何跳变（上升沿或下降沿）均输出单拍脉冲
    wire edge_change = (key_r1 ^ key_r2);

    // 3. 滤波计数器：只要有机械抖动边沿就强行复位重置
    reg [WIDTH-1:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {WIDTH{1'b0}};
        end else if (edge_change) begin
            cnt <= {WIDTH{1'b0}};               // 检测到抖动跳变，清零重计
        end else if (cnt < CNT_MAX - 1'b1) begin
            cnt <= cnt + 1'b1;                  // 维持稳定电平时持续累加
        end
    end

    // 4. 输出逻辑：在稳定计数满 20ms 的瞬间，若确认为稳定低电平，吐出 1 拍脉冲
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_pulse <= 1'b0;
        end else if (cnt == CNT_MAX - 2'd2 && key_r2 == 1'b0) begin
            key_pulse <= 1'b1;                  // 精确输出 1 拍
        end else begin
            key_pulse <= 1'b0;
        end
    end

endmodule