`timescale 1ns/1ps

module angle_adc_collect_tb;

  // Parameters
  localparam integer ADC_WIDTH = 10;
  localparam integer CLK_FREQ_HZ = 50_000_000;
  localparam integer ADC_POWERUP_US = 100;

  //Ports
  reg  clk;
  reg  rst_n;
  reg [ADC_WIDTH-1:0] adc_data;
  reg  adc_otr;
  wire  adc_clk;
  wire  adc_oe;
  wire [ADC_WIDTH-1:0] angle_raw;
  wire angle_valid;
  wire adc_overrange;

  angle_adc_collect # (
    .ADC_WIDTH(ADC_WIDTH),
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .ADC_POWERUP_US(ADC_POWERUP_US)
  )
  angle_adc_collect_inst (
    .clk(clk),
    .rst_n(rst_n),
    .adc_data(adc_data),
    .adc_otr(adc_otr),
    .adc_clk(adc_clk),
    .adc_oe(adc_oe),
    .angle_raw(angle_raw), 
    .angle_valid(angle_valid),
    .adc_overrange(adc_overrange)
  ); 

   always #10 clk=~clk;
   #100;
rst_n = 1'b1;

// 等待ADC完成100us上电
#120_000;

// ADC上电完成后再改变数据
adc_data = 10'd600;

#1000;
adc_data = 10'd700;

#1000;
adc_data = 10'd400;

#1000;
adc_otr = 1'b1;

#1000;
adc_otr = 1'b0;

#100;
$stop;

   end
   always @(negedge clk) begin
        if (angle_valid) begin
            $display(
                //显示时间，数据，信号，是否有效，使能，超量//
                "time=%0t ns, adc_data=%0d, angle_raw=%0d, angle_valid=%b, adc_oe=%b, adc_otr=%b",
                $time,
                adc_data,
                angle_raw,
                angle_valid,
                adc_oe,
                adc_overrange
            );
        end
    end


endmodule