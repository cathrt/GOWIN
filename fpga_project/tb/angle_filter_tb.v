`timescale 1ns/1ps;
module angle_filter_tb;

  // Parameters
  localparam integer ADC_WIDTH = 10;
  localparam integer FILTER_SHIFT = 3;
  localparam integer FRAC_BITS = 4;

  //Ports
  reg  clk;
  reg  rst_n;
  reg [ADC_WIDTH-1:0] angle_raw;
  reg  angle_valid;
  reg  adc_overrange;
  wire [ADC_WIDTH-1:0] angle_filtered;
  wire angle_active;
  wire angle_otr;

  angle_filter # (
    .ADC_WIDTH(ADC_WIDTH),
    .FILTER_SHIFT(FILTER_SHIFT),
    .FRAC_BITS(FRAC_BITS)
  )
  angle_filter_inst (
    .clk(clk),
    .rst_n(rst_n),
    .angle_raw(angle_raw),
    .angle_valid(angle_valid),
    .adc_overrange(adc_overrange),
    .angle_filtered(angle_filtered),
    .angle_active(angle_active),
    .angle_otr(angle_otr)
  );

   always #10  clk = ~ clk ;
   
   initial begin
    // 初始状态
    clk           = 1'b0;
    rst_n         = 1'b0;
    angle_raw     = 10'd0;
    angle_valid   = 1'b0;
    adc_overrange = 1'b0;

    // 保持复位100ns
    #100;
    rst_n = 1'b1;

    angle_raw   = 10'd500;
    angle_valid = 1'b1;

    #20;
    angle_valid = 1'b0;

    // 等待一个时钟周期
    #20;

    angle_raw   = 10'd520;
    angle_valid = 1'b1;

    #20;
    angle_valid = 1'b0;

    // 测试ADC超量程
    #20;
    adc_overrange = 1'b1;

    // 输入超量程数据900
    angle_raw   = 10'd900;
    angle_valid = 1'b1;

    #20;
    angle_valid = 1'b0;

    // 关闭超量程
    #20;
    adc_overrange = 1'b0;

    #100;
    $stop;
end

    // 观察滤波输出//
    always @(negedge clk) begin
        if (angle_active) begin
            $display(
                "time=%0t ns, angle_raw=%0d, angle_filtered=%0d, angle_active=%b, angle_otr=%b",
                $time,
                angle_raw,
                angle_filtered,
                angle_active,
                angle_otr
            );
        end
    end
endmodule