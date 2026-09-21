/*
解码同步模块
消除亚稳态，4倍频，提取电机正反转信息
*/
module decode_sync (
    input wire clk,
    input wire rst_n,
    //输入的AB相信号线
    input wire encode_a,    
    input wire encode_b,
    //输出
    output reg  encode_pulse, // 边沿脉冲，电机转一圈产生13*20*4=1040个脉冲，在该脉冲时采集数据
    output reg  motor_dir     // 电机转向，[0]为正转，[1]为反转
);

//打三拍，前两拍消除亚稳态，第三拍用来记忆电平
reg encode_a_r1;
reg encode_a_r2;    //安全电平
reg encode_a_r3;    //历史电平
reg encode_b_r1;
reg encode_b_r2;    //安全电平
reg encode_b_r3;    //历史电平
//移位寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        encode_a_r1 <= 1'b0;
        encode_a_r2 <= 1'b0;
        encode_a_r3 <= 1'b0;
        encode_b_r1 <= 1'b0;
        encode_b_r2 <= 1'b0;
        encode_b_r3 <= 1'b0;
    end else begin
        encode_a_r1 <= encode_a;
        encode_a_r2 <= encode_a_r1;
        encode_a_r3 <= encode_a_r2;
        encode_b_r1 <= encode_b;
        encode_b_r2 <= encode_b_r1;
        encode_b_r3 <= encode_b_r2;
    end
end

// 4倍频，即采取A，B相的上升沿和下降沿
wire edge_pluse = (encode_a_r2 ^ encode_a_r3) | (encode_b_r2 ^ encode_b_r3);

// 正反转判定：仅在边沿改变的那 1 拍更新，即有边沿脉冲的那一拍更新，其余时间锁存保持前值
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        motor_dir <= 1'b0;
        encode_pulse <= 1'b0;
    end else begin
        encode_pulse <= edge_pluse;
        if (edge_pluse) begin
            // 在跳变瞬间采样：当前 a 与上一拍 b 异或
            motor_dir <= ~ (encode_a_r2 ^ encode_b_r3);
        end
    end
end

endmodule