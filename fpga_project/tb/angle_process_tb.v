`timescale 1ns/1ps;
module angle_process_tb;

  // Parameters
  localparam integer ADC_WIDTH = 10;
  localparam integer ANGLE_WIDTH = 32;
  localparam integer SYS_CLK_FREQ_HZ = 50_000_000;
  localparam integer CONTROL_FREQ_HZ = 1000;
  localparam integer ANGLE_RANGE_DEG = 345;
  localparam integer ADC_FULL_SCALE = 1023;
  localparam integer ANGLE_SCALE = 256;
  localparam integer ANGLE_SIGN = 1;
  localparam integer ANGLE_ZERO_DEFAULT = 1023;

  //Ports
  reg  clk;
  reg  rst_n;
  reg [ADC_WIDTH-1:0] angle_filtered;
  reg  angle_active_in;
  reg  angle_otr_in;
  reg  calib_en;
  wire angle_active;
  wire [ANGLE_WIDTH-1:0] angle_deg;
  wire [ANGLE_WIDTH-1:0] angle_vel;
  wire angle_otr;
  wire [ADC_WIDTH-1:0] angle_zero;
  wire zero_valid;

  angle_process # (
    .ADC_WIDTH(ADC_WIDTH),
    .ANGLE_WIDTH(ANGLE_WIDTH),
    .SYS_CLK_FREQ_HZ(SYS_CLK_FREQ_HZ),
    .CONTROL_FREQ_HZ(CONTROL_FREQ_HZ),
    .ANGLE_RANGE_DEG(ANGLE_RANGE_DEG),
    .ADC_FULL_SCALE(ADC_FULL_SCALE),
    .ANGLE_SCALE(ANGLE_SCALE),
    .ANGLE_SIGN(ANGLE_SIGN),
    .ANGLE_ZERO_DEFAULT(ANGLE_ZERO_DEFAULT)
  )
  angle_process_inst (
    .clk(clk),
    .rst_n(rst_n),
    .angle_filtered(angle_filtered),
    .angle_active_in(angle_active_in),
    .angle_otr_in(angle_otr_in),
    .calib_en(calib_en),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .angle_otr(angle_otr),
    .angle_zero(angle_zero),
    .zero_valid(zero_valid)
  );

    always #10 clk = ~clk;

    initial begin
        // 初始状态
        clk            = 1'b0;
        rst_n          = 1'b0;
        angle_filtered = 10'd500;
        angle_active_in = 1'b0;
        angle_otr_in   = 1'b0;
        calib_en       = 1'b0;

        // 保持复位100ns
        #100;
        rst_n = 1'b1;

        // 模拟滤波器输出有效
        angle_active_in = 1'b1;

        // 保持2.1ms，模拟零点校准
        calib_en = 1'b1;
        #2_100_000;
        calib_en = 1'b0;

        // 模拟角度正向偏差
        angle_filtered = 10'd512;
        #1_100_000;

        // 模拟角度反向偏差
        angle_filtered = 10'd488;
        #1_100_000;

        // 模拟ADC超量程
        angle_otr_in = 1'b1;
        #1_100_000;

        // 关闭超量程
        angle_otr_in = 1'b0;

        #100_000;
        $finish;
    end


    always @(negedge clk) begin
        if (angle_active) begin
            $display(
                "time=%0t ns, angle_filtered=%0d, angle_zero=%0d, zero_valid=%b, angle_deg=%0d, angle_vel=%0d, angle_otr=%b",
                $time,
                angle_filtered,
                angle_zero,
                zero_valid,
                $signed(angle_deg),
                $signed(angle_vel),
                angle_otr
            );
        end
    end

endmodule