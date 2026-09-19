`timescale 1ns/1ps;
module angle_tb;

  // Parameters
  localparam integer ADC_WIDTH = 10;
  localparam integer ANGLE_WIDTH = 32;

  //Ports
  reg  clk;
  reg  rst_n;
  wire  clk_adc;
  wire  adc_oe;
  reg [ADC_WIDTH-1:0] adc_data;
  reg  adc_otr;
  reg  calib_en;
  wire  angle_active;
  wire signed [ANGLE_WIDTH-1:0] angle_deg;
  wire signed [ANGLE_WIDTH-1:0] angle_vel;
  wire  angle_otr;

  angle # (
    .ADC_WIDTH(ADC_WIDTH),
    .ANGLE_WIDTH(ANGLE_WIDTH)
  )
  angle_inst (
    .clk(clk),
    .rst_n(rst_n),
    .clk_adc(clk_adc),
    .adc_oe(adc_oe),
    .adc_data(adc_data),
    .adc_otr(adc_otr),
    .calib_en(calib_en),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .angle_otr(angle_otr)
  );
  always #10 clk = ~clk;

    initial begin
        clk      = 1'b0;
        rst_n    = 1'b0;
        adc_data = 10'd500;
        adc_otr  = 1'b0;
        calib_en = 1'b0;

        // 保持复位100ns//
        #100;
        rst_n = 1'b1;

        // 等待ADC完成100us上电稳定//
        #120_000;

        // 零点校准//
        // 当前ADC值500作为零点//
        calib_en = 1'b1;
        #2_100_000;
        calib_en = 1'b0;

        // 模拟角度正向变化//
        adc_data = 10'd512;
        #1_100_000;

        // 模拟角度反向变化
        adc_data = 10'd488;
        #1_100_000;

        // 模拟ADC超量程
        adc_otr  = 1'b1;
        adc_data = 10'd600;
        #1_100_000;

        // 关闭ADC超量程
        adc_otr = 1'b0;

        #100_000;
        $finish;
    end

    always @(negedge clk) begin
        if (angle_active) begin
            $display(
                "time=%0t ns, adc_data=%0d, angle_deg=%0d, angle_vel=%0d, angle_active=%b, angle_otr=%b, adc_oe=%b",
                $time,
                adc_data,
                $signed(angle_deg),
                $signed(angle_vel),
                angle_active,
                angle_otr,
                adc_oe
            );
        end
    end

endmodule