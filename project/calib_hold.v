// 零点校准按键脉冲保持模块//
// 将key_pulse的20ns脉冲延长为2ms//
module calib_hold #(
    parameter integer HOLD_CYCLES = 100_000//因为角度刷新时=是1KHZ，所以校准按键脉冲要>=1MS//
    //我延长至了2MS，50MHZ保持2NS，也就是100_000个20NS//
)(
    input  wire clk,
    input  wire rst_n,

    input  wire calib_key_pulse,
    output wire calib_en
);

    localparam integer CNT_WIDTH = $clog2(HOLD_CYCLES + 1);//自动计算位宽，OvO //

    reg [CNT_WIDTH-1:0] cnt;

    // 计数器非零时，校准使能有效
    assign calib_en = (cnt != 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
        end
        else if (calib_key_pulse) begin
            cnt <= HOLD_CYCLES;
        end
        else if (cnt != 0) begin
            cnt <= cnt - 1'b1;
        end
    end

endmodule