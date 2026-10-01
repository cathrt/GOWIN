module top (
    input  wire clk,
    input  wire rstn,
    //与ADC接口
    output wire clk_adc,        //驱动ADC的时钟
    output wire adc_oe,         //ADC使能开启
    input  wire [9:0] adc_data, //ADC传进来的原始数据
    input  wire adc_otr,        //ADC超限的信号
    //与编码器接口
    input  wire encode_a,       //编码器传进来的A相数据
    input  wire encode_b,       //编码器传进来的B相数据
    //与按键接口
    input  wire [3:0] key_in,   //传进来的4个按键信号
    //与电机驱动模块TB6612的接口
    output wire ain1,           //1，2决定电机正反转
    output wire ain2,
    output wire pwm_out,        //PWM输出，一种占空比变化的周期性信号
    //与LED接口
    output wire [3:0] led_out         //LED输出
);
localparam WIDTH_DATA = 32;
localparam CLK_F = 50_000_000;
localparam PWM_F = 20_000;
// PWM满幅，CLK_F(50MHz) / PWM_F(20KHz)
localparam DUTY_MAX = CLK_F / PWM_F;

// 复位按键 ：异步复位，同步释放
wire rst_n;
rst_n_sync  rst_n_sync_inst (
    .rstn(rstn),
    .clk(clk),
    .rst_n(rst_n)
  );

// 按键模块
localparam KEY_NUM = 4;
wire [3:0] key_pulse;   //按键完成单周期脉冲
key # (
    .KEY_NUM(KEY_NUM)
  )
  key_inst (
    .clk(clk),
    .rst_n(rst_n),
    .key_in(key_in),
    .key_pulse(key_pulse)
  );




endmodule //top