/*
按键阵列顶层封装模块
采用 generate 循环例化，消除手写重复连线与索引笔误
*/
module key #(
    parameter integer KEY_NUM = 4 // 支持任意按键路数扩展
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [KEY_NUM-1:0]   key_in,    // 外部按键引脚
    output wire [KEY_NUM-1:0]   key_pulse  // 对应按键脉冲
);

    genvar i;
    generate
        for (i = 0; i < KEY_NUM; i = i + 1) begin : gen_key_debounce
            key_debounce u_key_debounce (
                .clk       (clk),
                .rst_n     (rst_n),
                .key_in    (key_in[i]),
                .key_pulse (key_pulse[i])
            );
        end
    endgenerate

endmodule