//angle:角度封装//
module angle #(
    parameter integer ADC_WIDTH   = 10,
    parameter integer ANGLE_WIDTH = 32
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // ADC接口//
    output wire                         clk_adc,
    output wire                         adc_oe,
    input  wire [ADC_WIDTH-1:0]         adc_data,
    input  wire                         adc_otr,

    // 零点校准输入//
    input  wire                         calib_en,

    // 角度处理输出//
    output wire                         angle_active,
    output wire signed [ANGLE_WIDTH-1:0] angle_deg,
    output wire signed [ANGLE_WIDTH-1:0] angle_vel,
    output wire                         angle_otr
);

    wire [ADC_WIDTH-1:0] adc_raw;
    wire                 adc_valid;
    wire                 adc_overrange;


    wire [ADC_WIDTH-1:0] angle_filtered;
    wire                 filter_active;
    wire                 filter_otr;

    wire [ADC_WIDTH-1:0] angle_zero;
    wire                 zero_valid;

    //角度采集模块。//
    angle_adc_collect #(
        .ADC_WIDTH      (ADC_WIDTH),
        .CLK_FREQ_HZ    (50_000_000),
        .ADC_POWERUP_US (100)
    ) angle_adc_collect_inst (
        .clk           (clk),
        .rst_n         (rst_n),
        .adc_data      (adc_data),
        .adc_otr       (adc_otr),
        .adc_clk       (clk_adc),
        .adc_oe        (adc_oe),
        .angle_raw     (adc_raw),
        .angle_valid   (adc_valid),
        .adc_overrange (adc_overrange)
    );


    // 角度滤波模块//
    
    angle_filter #(
        .ADC_WIDTH    (ADC_WIDTH),
        .FILTER_SHIFT (3),
        .FRAC_BITS    (4)
    ) angle_filter_inst (
        .clk             (clk),
        .rst_n           (rst_n),
        .angle_raw       (adc_raw),
        .angle_valid     (adc_valid),
        .adc_overrange   (adc_overrange),
        .angle_filtered  (angle_filtered),
        .angle_active    (filter_active),
        .angle_otr       (filter_otr)
    );

    // 角度处理模块//
    angle_process #(
        .ADC_WIDTH           (ADC_WIDTH),
        .ANGLE_WIDTH         (ANGLE_WIDTH),
        .SYS_CLK_FREQ_HZ     (50_000_000),
        .CONTROL_FREQ_HZ     (1_000),
        .ANGLE_RANGE_DEG     (345),
        .ADC_FULL_SCALE      (1023),
        .ANGLE_SCALE         (256),
        .ANGLE_SIGN          (1),
        .ANGLE_ZERO_DEFAULT  (1023)
    ) angle_process_inst (
        .clk             (clk),
        .rst_n           (rst_n),
        .angle_filtered  (angle_filtered),
        .angle_active_in (filter_active),
        .angle_otr_in    (filter_otr),
        .calib_en        (calib_en),
        .angle_active    (angle_active),
        .angle_deg       (angle_deg),
        .angle_vel       (angle_vel),
        .angle_otr       (angle_otr),
        .angle_zero      (angle_zero),
        .zero_valid      (zero_valid)
    );

endmodule