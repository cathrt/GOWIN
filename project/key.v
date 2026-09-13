module key (
    input  wire clk,
    input  wire rst_n,
    input  wire [3:0] key_in,   //按键输入，[]
    output reg  [3:0] key_pluse //按键输出的脉冲
);

    key_debounce  key_debounce_inst1 (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_in[0]),
        .key_pulse(key_pulse[0])
    );

    key_debounce  key_debounce_inst2 (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_in[1]),
        .key_pulse(key_pulse[1])
    );
    
    key_debounce  key_debounce_inst3 (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_in[2]),
        .key_pulse(key_pulse[2])
    );

    key_debounce  key_debounce_inst4 (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_in[3]),
        .key_pulse(key_pulse[4])
    );

endmodule