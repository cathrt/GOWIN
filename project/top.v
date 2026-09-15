module top (
    input  wire clk,
    input  wire rst_n,
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
    output wire led_out         //LED输出
);

//按键模块
    localparam KEY_NUM = 4;
    wire [3:0] key_pluse;   //按键完成单周期脉冲
key # (
    .KEY_NUM(KEY_NUM)
  )
  key_inst (
    .clk(clk),
    .rst_n(rst_n),
    .key_in(key_in),
    .key_pulse(key_pulse)
  );

//角度模块
    wire angle_active;               //角度传播脉冲，2ms
    wire signed [16:0] angle_deg;    //电机角度
    wire signed [16:0] angle_vel;    //电机速度
    wire angle_otr;                  //电机超限的信号
angle angle_inst (
    .clk(clk),
    .rst_n(rst_n),
    .clk_adc(clk_adc),
    .adc_oe(adc_oe),
    .adc_data(adc_data),
    .adc_otr(adc_otr),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .angle_otr(angle_otr)
  );

//编码器模块
    wire motor_dir;                //电机转向，1正转，0反转
    wire signed [31:0] cur_pos;    //电机当前位置
    wire signed [15:0] cur_speed;  //电机当前速度
decode  decode_inst (
    .clk(clk),
    .rst_n(rst_n),
    .encode_a(encode_a),
    .encode_b(encode_b),
    .motor_dir(motor_dir),
    .cur_pos(cur_pos),
    .cur_speed(cur_speed)
  );

//主控模块
    wire swing_en;      //起摆使能信号
    wire pid_en;        //PID使能信号
    wire motor_stop;    //电机停止信号
control # (
    .ANGLE_LIMIT(ANGLE_LIMIT)
  )
  control_inst (
    .clk(clk),
    .rst_n(rst_n),
    .key_pluse(key_pluse),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_otr(angle_otr),
    .cur_pos(cur_pos),
    .swing_en(swing_en),
    .pid_en(pid_en),
    .motor_stop(motor_stop)
  );

//起摆模块
    wire signed [12:0] swing_data;  //起摆输出的占空比数据
swing  swing_inst (
    .clk(clk),
    .rst_n(rst_n),
    .swing_en(swing_en),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .swing_data(swing_data)
  );
/*
双环并联解耦 PID 模块
- 内环: 垂直被动摆杆角度环 (纯 PD 控制)
- 外环: 水平旋转臂位置环 (PID 控制)
*/
wire signed [12:0] pid_data;  //PID输出的占空比数据

pid_double # (
    .KP_ANGLE(KP_ANGLE),
    .KD_ANGLE(KD_ANGLE),
    .KP_POS(KP_POS),
    .KI_POS(KI_POS),
    .KD_POS(KD_POS),
    .MAX_I_POS(MAX_I_POS),
    .MIN_I_POS(MIN_I_POS)
  )
  pid_double_inst (
    .clk(clk),
    .rst_n(rst_n),
    .pid_en(pid_en),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .cur_pos(cur_pos),
    .cur_speed(cur_speed),
    .pid_data(pid_data)
  );

//2选1 MUX，选择输出起摆还是PID
always @(*) begin
    if(pid_en) begin
        duty_signed = pid_data;
    end else if(swing_en) begin
        duty_signed = swing_data;
    end else begin
        duty_signed = 13'sd0;
    end
end

//电机驱动模块
    wire [12:0] duty_signed;  //电机有符号占空比
motor  motor_inst (
    .clk(clk),
    .rst_n(rst_n),
    .duty_signed(duty_signed),
    .motor_stop(motor_stop),
    .ain1(ain1),
    .ain2(ain2),
    .pwm_out(pwm_out)
  );

endmodule //top