/*
角速度生成模块
采用T法测速，公式：角速度 = K / m2，K = 2 * Π * f_c / 1040 / 0.001(1ms)
以 1 代表 1 个编码器脉冲弧度 (2*π / 1040 / 0.001 rad/s)
则角速度计算公式变为：
    cur_speed = f_c / m2 (单位：脉冲/秒, counts/s)
    f_c = 50_000_000 (50MHz 系统时钟)
    m2  = 编码器相邻边沿间的高频时钟计数
*/
module decode_speed #(
    parameter WIDTH_DATA = 16
) (
        input  wire clk,
        input  wire rst_n,
        //输入
        input  wire encode_pulse,               // 边沿脉冲
        input  wire motor_dir,                  // 电机转向,[0]为正转，[1]为反转
        //输出
        output reg  signed [WIDTH_DATA-1:0] cur_speed     // 当前角速度
    );

    // K = f_c 
    localparam [31:0] K = 32'd50_000_000;

    // 两个脉冲之间间隔时间比100ms长，则认为电机不转，50MHz*100ms = 5_000_000 
    localparam [23:0] CNT_MAX = 24'd5_000_000;

    // 自动计算位宽
    localparam WIDTH = $clog2(CNT_MAX);

    // 计数器，用于计算脉冲间隔计数值
    reg [WIDTH-1:0] cnt; 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= CNT_MAX;         // 上电时不让电机转动
        end else if (encode_pulse) begin
            cnt <= 'd1;             // 脉冲到来，计数器清零,但清零的这个周期应该是新周期的第一个系统周期
        end else if (cnt < CNT_MAX) begin
            cnt <= cnt + 1'b1;      // 脉冲间隔计数值小于最大值，计数器加1
        end else begin
            cnt <= CNT_MAX;         // 脉冲间隔计数值大于最大值，计数器保持最大值
        end
    end

    //锁存脉冲间隔计数值
    //不锁存的话，cnt会直接清零重新计数
    reg [WIDTH-1:0] m2_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m2_r <= 'd1;        // 除数不能为0，初始化为1
        end else if (encode_pulse && cnt < CNT_MAX) begin
            m2_r <= cnt;        // 脉冲到来，锁存脉冲间隔计数值
        end 
    end

    // 超过脉冲间隔计数值最大值，使能电机停止转动
    reg motor_stop;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            motor_stop <= 1'b1;         // 上电关闭电机
        end else if (cnt >= CNT_MAX) begin
            motor_stop <= 1'b1;         // 超限关闭电机
        end else if(encode_pulse) begin
            // 脉冲到来：若之前未超时(cnt < CNT_MAX)，说明是连续脉冲，速度生效；
            // 若之前已超时(cnt >= CNT_MAX)，说明是起步首脉冲，速度暂不可信
            motor_stop <= (cnt >= CNT_MAX);
        end
    end

    // 启动除法器模块
    reg  req_valid;  // 除法器启动脉冲
    wire req_ready;  // 除法器空闲的脉冲
    // 当有新脉冲且除法器空闲时，打出 1 拍 req_valid 启动除法
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_valid <= 1'b0;
        end else if (encode_pulse && cnt < CNT_MAX && req_ready) begin
            req_valid <= 1'b1;
        end else begin
            req_valid <= 1'b0;
        end
    end

    // Gowin Divider IP 除法器 例化
    wire [31:0]speed;
    wire resp_valid;    // 计算完成标志
    gowin_divider u_gowin_divider (
        .clk        (clk),
        .rstn       (rst_n),
        .func       (4'd5),                 // 5 = 无符号除法 (DIVU)
        .op0        (K),                    // 被除数
        .op1        ({{(32-WIDTH){1'b0}}, m2_r}), // 除数 (自动补齐32位)
        .req_valid  (req_valid),            // 启动计算脉冲
        .req_ready  (req_ready),            // 1 即IP核可以开启新的计算
        .resp_ready (1'b1),                 // 随时准备接收结果，常通
        .resp_valid (resp_valid),           // 计算完成标志，高电平表示出来结果了
        .res0       (speed),                // 商输出，无符号数
        .res1       (),                     // 余数悬空
        .kill       (1'b0),                 // 中断信号，拉低即不取消计算
        .tagI       (5'd0),
        .tagO       ()
    );

    // 锁存有效除法结果并进行符号转换
    reg  [WIDTH_DATA-1:0] abs_speed;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            abs_speed <= 'd0;
        end else if (resp_valid) begin
            // 仅在计算完成标志有效时锁存结果
            // 饱和限幅：若计算值超过 16 位有符号上限 32767，锁死在 32767
            abs_speed <= (speed > 32'd32767) ? 16'd32767 : speed[15:0];
        end
    end

    // 电机正反转
    // 除法器不允许除数为0，而当电机停止转动时，m2_r被设置为1，除法器输出的角速度为K_MOTOR，但实际上此时角速度应为0，因此需要在此处进行处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_speed <= {WIDTH_DATA{1'b0}};
        end else if (motor_stop) begin
            cur_speed <= {WIDTH_DATA{1'b0}};    // 强制电机停止转动，角速度为0
        end else begin 
            if (!motor_dir) begin
                cur_speed <= $signed(abs_speed);         // 正转，角速度为正
            end else begin
                cur_speed <= -$signed(abs_speed);        // 反转，角速度为负
            end
        end
    end
endmodule