/*
 PID控制器，Y = Kp*p + Ki*i - Kd*d
*/
module pid #(
    //参数
    parameter signed [15:0] Kp = 16'sd100,
    parameter signed [15:0] Ki = 16'sd0,
    parameter signed [15:0] Kd = 16'sd100,
    parameter signed [12:0] MAX_OUT = 13'sd2500,    // 占空比范围-2500~2500
    parameter signed [12:0] MIN_OUT = -13'sd2500,
    parameter signed [31:0] MAX_I = 32'sd10000,     // 积分抗饱和限幅
    parameter signed [31:0] MIN_I = -32'sd10000 
) (
    input  wire clk,
    input  wire rst_n,
    //PID控制信号
    input  wire pid_en,
    //PID数据处理周期，用离散信号代替连续处理
    input  wire angle_active,
    //数据
    input  wire signed [31:0] target,  //目标信息
    input  wire signed [31:0] cur,     //当前信息
    input  wire signed [31:0] diff,    //微分输入
    //PID输出信号
    output reg  signed [12:0] pid_data
);

// 误差计算
wire signed [31:0] err = target - cur;

//比例项
wire signed [47:0] pid_p = Kp * err;

//积分项
reg signed [31:0] i;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        i <= 32'b0;
    end else if(angle_active && pid_en) begin
        if (Ki != 16'sd0) begin     //如果积分常数为0，没有必要算积分项了
            if ( (i + err) >= MAX_I) //采用下一个积分结果，如果采用当前积分，我们的积分项会永远锁定在MAX_I，i将永远无法变化了
                i <= MAX_I;
            else if ( (i + err) <= MIN_I)
                i <= MIN_I;
            else
                i <= i + err;
        end
    end else if(!pid_en) begin
        //在没有使能下，清空积分项
        i <= 32'b0;
    end
end

wire signed [47:0] pid_i = Ki * i;

//微分项
wire signed [47:0] pid_d = Kd * diff;

//求和输出，右移8位，即除以256
wire signed [47:0] pid_sum = (pid_p + pid_i - pid_d) >>> 8;
    
//输出寄存器化，输出限幅
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pid_data <= 13'sd0;
    end else if (!pid_en) begin
        pid_data <= 13'sd0;
    end else if (angle_active && pid_en) begin
        if (pid_sum > MAX_OUT)
            pid_data <= MAX_OUT;
        else if (pid_sum < MIN_OUT)
            pid_data <= MIN_OUT;
        else
            pid_data <= pid_sum[12:0];
    end
end

endmodule