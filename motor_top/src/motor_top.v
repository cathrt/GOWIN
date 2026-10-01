
module motor_top(
    input  wire clk,
    input  wire rst_n,
    input  wire [3:0] key_in,
    output wire ain1,
    output wire ain2,
    output wire pwm_out 
);

localparam KEY_NUM = 4;
localparam DUTY_MAX = 2500;

wire [3:0] key_pulse;
key # (
    .KEY_NUM(KEY_NUM)
  )
  key_inst (
    .clk(clk),
    .rst_n(rst_n),
    .key_in(key_in),
    .key_pulse(key_pulse)
  );

reg signed [12:0] duty_signed;
reg motor_stop;
motor # (
    .DUTY_MAX(DUTY_MAX)
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

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        motor_stop  <= 1'b1;
        duty_signed <= 13'sd0;
    end else if (key_pulse[0]) begin
        // 顺时针旋转 (正向占空比)
        duty_signed <= 13'sd500;
        motor_stop  <= 1'b0;
    end else if (key_pulse[1]) begin
        // 逆时针旋转 (反向占空比)
        duty_signed <= -13'sd500;
        motor_stop  <= 1'b0;
    end else if (key_pulse[2]) begin
        // 平稳刹停
        motor_stop  <= 1'b1;
        duty_signed <= 13'sd0;
    end
end


endmodule