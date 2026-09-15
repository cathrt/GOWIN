/*
位置计数器
将电机转动的角度数字化（位置），即用 1 来代表 360/1040 度
正转+1，反转-1
*/
module decode_cnt(
    input wire clk,
    input wire rst_n,
    //输入
    input wire encode_pluse,            //边沿脉冲
    input wire motor_dir,               //电机的转向，[1]为正转，[0]为反转
    //输出
    output reg signed [31:0] cur_pos    //当前电机转动信息，1 代表 360/1040 度

);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      cur_pos <= 32'sd0;
    end
    else if(encode_pluse) begin
        if(motor_dir) begin
            cur_pos <= cur_pos + 1'b1;
        end
        else if(!motor_dir) begin
            cur_pos <= cur_pos - 1'b1;
        end
    end
end

endmodule