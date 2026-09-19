module lqr_leso #(
    parameter WIDTH_DATA = 32
) (
    input  wire clk,
    input  wire rst_n,
    input  wire angle_active,   //2ms周期脉冲
    input  wire lqr_en,         //使能lqr信号，持续高脉冲
    //输入的目标数据
    input  wire signed [WIDTH_DATA-1:0] target_arm,     //垂直摆杆目标角度
    input  wire signed [WIDTH_DATA-1:0] target_pend,    //水平摆杆目标角度
    //输入的垂直摆杆数据
    input  wire signed [WIDTH_DATA-1:0] angle_deg,      //测得的角度
    //输入的水平摆杆数据
    input  wire signed [WIDTH_DATA-1:0] cur_pos,        //测得的位置
    input  wire signed [WIDTH_DATA-1:0] cur_speed,      //计算出的速度
    //输出
    output reg  signed [12:0] u_duty,          //输出的占空比
    output wire sat_pos,
    output wire sat_neg
);

// Q 格式约定
    localparam ARM_Q    = 0;       // 水平臂输入：编码器计数
    localparam PEND_Q   = 16;      // 垂直摆输入：Q16
    localparam ARM_K_Q  = 16;      // 水平增益：Q16
    localparam PEND_K_Q = 16;      // 垂直增益：Q16
    localparam Q_SHIFT  = 16;      // LESO 定点移位

// LQR 增益（Q16）
    localparam signed [WIDTH_DATA-1:0] K1 = 32'sd65536;    // 水平臂位置增益
    localparam signed [WIDTH_DATA-1:0] K2 = 32'sd32768;    // 水平臂速度阻尼
    localparam signed [WIDTH_DATA-1:0] K3 = 32'sd327680;   // 垂直摆角度刚度
    localparam signed [WIDTH_DATA-1:0] K4 = 32'sd65536;    // 垂直摆角速度阻尼

// LESO 参数（Q16，Ts=2ms, wo=60 rad/s, b0=100）
    localparam signed [WIDTH_DATA-1:0] PARAM_TS = 32'sd131;        // 0.002  × 65536
    localparam signed [WIDTH_DATA-1:0] PARAM_L1 = 32'sd23593;      // 0.36   × 65536
    localparam signed [WIDTH_DATA-1:0] PARAM_L2 = 32'sd1415578;    // 21.6   × 65536
    localparam signed [WIDTH_DATA-1:0] PARAM_L3 = 32'sd28311552;   // 432    × 65536
    localparam signed [WIDTH_DATA-1:0] PARAM_B0 = 32'sd13107;      // 0.2    × 65536

// z3 前馈系数 z3_dist/b0 (Q16)
// b0 = 100 → 1/100 = 0.01 → 0.01 × 65536 = 655
    localparam signed [WIDTH_DATA-1:0] INV_B0_Q16 = 32'sd655;

// 13 位饱和边界
    localparam signed [WIDTH_DATA-1:0] U_MAX_32 = 32'sd4095;
    localparam signed [WIDTH_DATA-1:0] U_MIN_32 = -32'sd4096;

// 中间连线
    wire signed [WIDTH_DATA-1:0] z1_pos;
    wire signed [WIDTH_DATA-1:0] z2_vel;
    wire signed [WIDTH_DATA-1:0] z3_dist;
    reg  signed [WIDTH_DATA-1:0] u_sum_old; // 延迟一拍的LQR输出,Q16
    wire signed [WIDTH_DATA-1:0] u_lqr;     //Q0

// LQR模块
leso # (
    .WIDTH_DATA(WIDTH_DATA),
    .Q_SHIFT(Q_SHIFT),
    .PARAM_TS(PARAM_TS),
    .PARAM_L1(PARAM_L1),
    .PARAM_L2(PARAM_L2),
    .PARAM_L3(PARAM_L3),
    .PARAM_B0(PARAM_B0)
  )
  leso_inst (
    .clk(clk),
    .rst_n(rst_n),
    .angle_active(angle_active),
    .y_meas(angle_deg),
    .u_sum_old(u_sum_old),
    .z1_pos(z1_pos),
    .z2_vel(z2_vel),
    .z3_dist(z3_dist)
  );

// LQR模块
lqr # (
    .WIDTH_DATA(WIDTH_DATA),
    .ARM_Q(ARM_Q),
    .PEND_Q(PEND_Q),
    .ARM_K_Q(ARM_K_Q),
    .PEND_K_Q(PEND_K_Q),
    .K1(K1),
    .K2(K2),
    .K3(K3),
    .K4(K4)
  )
  lqr_inst (
    .clk(clk),
    .rst_n(rst_n),
    .lqr_en(lqr_en),
    .target_arm(target_arm),
    .pos_arm(cur_pos),
    .vel_arm(cur_speed),
    .target_pend(target_pend),
    .pos_pend(z1_pos),
    .vel_pend(z2_vel),
    .u_lqr(u_lqr),
    .sat_pos(sat_pos),
    .sat_neg(sat_neg)
  );

// 延迟 4 拍 与输出 u_lqr 同步
// LESO 内部经过了 2拍，LQR 内部也经过了 2拍，共经过了 4拍
// 我们不是每过4拍就输出一个信号，而是一个2MS周期开始的前 4 拍进行移位，输出一个信号进行同步，其余时间在等待
reg [3:0] tick_pipe;
//移位寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_pipe <= 4'b0;
    end else begin
        tick_pipe <= {tick_pipe[2:0], angle_active};    //右移，每一次2MS周期进行一次
    end
end
wire calc_done = tick_pipe[3]; // 第4拍，此时 LESO 与 LQR 乘加全链路运算完毕

// 将z3_dist(类似加速度) 转化为 力
wire [WIDTH_DATA*2-1:0] mult_z3 = z3_dist * INV_B0_Q16; // Q32
// 右移 32 位还原为 Q0 物理推力
wire signed [WIDTH_DATA-1:0] z3 = mult_z3 >>> 32;       // Q0

// 输出加和
reg signed [WIDTH_DATA-1:0] u_sum;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        u_sum <= 0;
    end else if(!lqr_en) begin
        u_sum <= 0;
    end else if(calc_done && lqr_en) begin
        // 在第 5 拍 进行计算
        u_sum <= u_lqr - z3;
    end
end

//最终输出23位转化为13位，并进行饱和限幅
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        u_duty <= 13'sd0;
    end else if(!lqr_en) begin
        u_duty <= 13'sd0;
    end else if(calc_done && lqr_en) begin
        // 在第 5 拍 输出
        // 饱和限幅，最大32位
        if(u_sum > U_MAX_32) begin   
            u_duty <=  13'sd2500;
        end else if (u_sum < U_MIN_32) begin
            u_duty <= -13'sd2500;
        end else begin
            u_duty <= u_sum[12:0];
        end                     
    end
end

//LESO 拿到的是真正下发给电机的 13 位值，将他进行拓展
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        u_sum_old <= 0;
    end else if (angle_active) begin 
        // 每一个周期都要锁存一次数据
        u_sum_old <= {{19{u_duty[12]}}, u_duty};  // 13位→32位
    end
end

endmodule