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

// 角度模块
localparam ADC_WIDTH = 10;
localparam ANGLE_WIDTH = 32;
wire angle_active;      // 角度传播脉冲，周期为 2ms
wire signed [WIDTH_DATA-1:0] angle_deg;    // 垂直摆杆角度  ，Q16，即放大 65536 倍
wire signed [WIDTH_DATA-1:0] angle_vel;    // 垂直摆杆角速度，Q16
wire angle_otr;         // 电机超限的信号
wire calib_en;			// 清零信号
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

// 编码器模块
wire pos_clr;		// 编码器数据清零信号，脉冲
wire motor_dir;     // 电机转向，1正转，0反转
wire signed [WIDTH_DATA-1:0] cur_pos;    // 水平摆杆角度，即位置，用 1 代表 2Π/1040 度，Q0
wire signed [WIDTH_DATA-1:0] cur_speed;  // 水平摆杆速度，Q0
decode # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  decode_inst (
    .clk(clk),
    .rst_n(rst_n),
    .pos_clr(pos_clr),
    .encode_a(encode_a),
    .encode_b(encode_b),
    .motor_dir(motor_dir),
    .cur_pos(cur_pos)
  );

// 主控模块
localparam  ANGLE_LIMIT = 12;
wire swing_en;      //起摆使能信号，持续高电平
wire motor_stop;    //电机停止信号，脉冲
wire signed [WIDTH_DATA-1:0] target_pend;  //垂直摆杆目标角度
wire lqr_en;		//LQR使能信号，持续高电平

// LESO + LQR模块
wire sat_pos;				// 正向饱和标志
wire sat_neg;				// 反向饱和标志
wire signed [12:0] u_duty;	// LQR输出的占空比数据，Q0
lqr_leso # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  lqr_leso_inst (
    .clk(clk),
    .rst_n(rst_n),
    .angle_active(angle_active),
    .lqr_en(lqr_en),
    .target_arm(32'sd0),
    .target_pend(target_pend),
    .angle_deg(angle_deg),
    .cur_pos(cur_pos),
    .cur_speed(cur_speed),
    .u_duty(u_duty),
    .sat_pos(sat_pos),
    .sat_neg(sat_neg)
  );

  // 起摆模块
wire signed [12:0] swing_data;  //起摆输出的占空比数据
swing # (
    .WIDTH_DATA(WIDTH_DATA)
  )
  swing_inst (
    .clk(clk),
    .rst_n(rst_n),
    .swing_en(swing_en),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .swing_data(swing_data)
  );

// 2选1 MUX，选择输出起摆还是LQR
reg signed [12:0] duty_signed;  //电机有符号占空比
always @(*) begin
    if(lqr_en) begin
        duty_signed = u_duty;
    end else if(swing_en) begin
        duty_signed = swing_data;
    end else begin
        duty_signed = 13'sd0;
    end
end

// 电机驱动模块
motor # (
    .CLK_F(CLK_F),
    .PWM_F(PWM_F)
  )
  motor_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .ain1(ain1),
    .ain2(ain2),
    .pwm_out(pwm_out)
  );

// led模块
assign led_out[0] = motor_dir; // 电机反转
assign led_out[1] = motor_dir; // 电机正转
assign led_out[2] = 1'b0;
assign led_out[3] = 1'b0;

endmodule //top