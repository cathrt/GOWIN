/*
位置计数器
功能：
    1. 将电机转动的角度数字化（位置），即用 1 脉冲 来代表 360/1040 度
       正转+1，反转-1
    2. 锁存进1ms周期中
*/
module decode_cnt #(
    parameter WIDTH_DATA = 16 // Q16.0格式
)(
    input  wire clk,
    input  wire rst_n,

    // 控制端
    input  wire pos_clr,                            // 在从起摆转向平衡时清零计数
    input  wire ctrl_tick,                          // 控制环路周期使能脉冲

    //输入
    input  wire encode_pulse,                       // 边沿脉冲
    input  wire motor_dir,                          // 电机的转向，[0]为正转，[1]为反转
    
    //输出
    output reg signed [WIDTH_DATA-1:0] cur_pos,     // 水平臂当前位置，用于仿真比较pos_arm
    output reg signed [WIDTH_DATA-1:0] pos_arm      // 水平臂当前位置，经过 1ms 锁存的数据
);

// 计数器
//reg [WIDTH_DATA-1:0] cur_pos;   //当前电机转动信息，1 代表 360/1040 度
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      cur_pos <= {WIDTH_DATA{1'b0}};     
    end else if(pos_clr) begin
		cur_pos <= {WIDTH_DATA{1'b0}};     // 接收到清零信号时清零
    end else if(encode_pulse) begin
        if(!motor_dir) begin
            cur_pos <= cur_pos + 1'b1;  // 正转+1
        end
        else if(motor_dir) begin
            cur_pos <= cur_pos - 1'b1;  // 反转-1
        end
    end
end

// 控制节拍快照锁存器 (状态向量时间对齐)
always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_arm <= {WIDTH_DATA{1'b0}};
        end else if (pos_clr) begin
            pos_arm <= {WIDTH_DATA{1'b0}};
        end else if (ctrl_tick) begin
            // 每一个 1ms 周期起始点，将精确的位置送入 LQR 闭环
            pos_arm <= cur_pos;
        end
    end

endmodule