/*
 PID控制器，Y = Kp*p + Ki*i + Kd*d
*/
module pid #(
    //参数
    parameter Kp = 100,
    parameter Ki = 10,
    parameter Kd = 100,
    parameter integer MUX_OUT =  13'sd2500,
    parameter integer MIN_OUT = -13'sd2500
) (
    input  wire clk,
    input  wire rst_n,
    //PID控制信号
    input  wire pid_en,
    //PID数据处理周期，用离散信号代替连续处理
    input  wire angle_active,
    //数据
    input  wire [31:0] target,  //目标信息
    input  wire [31:0] cur,     //当前信息
    input  wire [31:0] diff,    //微分输入
    //PID输出信号
    output wire [13:0] pid_data
);

//比例项
reg [31:0] pid_p;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pid_p <= 32'b0;
    end else if (pid_en && angle_active) begin
        pid_p <= Kp * (target - cur);
    end
end

//积分项
reg [31:0] pid_i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pid_i <= 32'b0;
    end else if (pid_en && angle_active) begin
        pid_i <= (pid_i + cur) * Ki;
    end
end

//微分项
reg [31:0] pid_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pid_d <= 32'b0;
    end else if (pid_en && angle_active) begin
        pid_d <= Kd * diff;
    end
end

//求和输出
reg [31:0] pid_sum;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pid_sum <= 32'b0;
    end else if (pid_en && angle_active) begin
        pid_sum <= (pid_p + pid_i + pid_d) << 8;  // 左移8位，即除以256
    end
end
    
//输出限制
assign pid_data = (pid_sum > MUX_OUT) ? MUX_OUT : (pid_sum < MIN_OUT) ? MIN_OUT : pid_sum[13:0];

endmodule