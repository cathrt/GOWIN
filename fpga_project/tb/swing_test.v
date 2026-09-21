`timescale 1ns/1ps

module swing_test;

    localparam WIDTH_DATA = 16;

    reg  clk;
    reg  rst_n;
    //控制信息
    reg  swing_en;
    reg  angle_active;
    //角度信息
    reg  signed [WIDTH_DATA-1:0] angle_deg;
    reg  signed [WIDTH_DATA-1:0] angle_vel;
    wire signed [12:0] swing_data;

    swing  uut (
    .clk(clk),
    .rst_n(rst_n),
    .swing_en(swing_en),
    .angle_active(angle_active),
    .angle_deg(angle_deg),
    .angle_vel(angle_vel),
    .swing_data(swing_data)
  );

    //时钟激励
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    integer  i;

    //主体激励
    initial begin
        //初始化
        rst_n = 1'b0;
        angle_active = 1'b0;
        swing_en = 1'b0;
        angle_deg = 0;
        angle_vel = 0;
        //关闭复位
        #100 rst_n = 1'b1;
        #500;
        //开启起摆使能
        @(negedge clk);
        swing_en = 1'b1;
        #100;
        for (i = 0; i < 4; i = i + 1) begin
            @(negedge clk);
            case (i)
                // 状态 0: 下半周 + 顺时针 (|θ| > 90°, vel <= 0) -> 预期输出: +750
                0: begin
                    angle_deg = 16'sd356;  // 约 120° (下半周，356 > 267)
                    angle_vel = -16'sd20;  // 顺时针速度
                end
                // 状态 1: 下半周 + 逆时针 (|θ| > 90°, vel > 0)  -> 预期输出: -750
                1: begin
                    angle_deg = 16'sd356;  // 约 120° (下半周，356 > 267)
                    angle_vel = 16'sd20;   // 逆时针速度
                end
                // 状态 2: 上半周 + 顺时针 (|θ| <= 90°, vel <= 0) -> 预期输出: -450
                2: begin
                    angle_deg = 16'sd134;  // 约 45° (上半周，134 <= 267)
                    angle_vel = -16'sd20;  // 顺时针速度
                end
                // 状态 3: 上半周 + 逆时针 (|θ| <= 90°, vel > 0)  -> 预期输出: +450
                3: begin
                    angle_deg = 16'sd134;  // 约 45° (上半周，134 <= 267)
                    angle_vel = 16'sd20;   // 逆时针速度
                end
            endcase
            // 激励角度使能
            angle_active = 1'b1;
            @(negedge clk);
            //关闭角度使能，只维持一个周期
            angle_active = 1'b0;
            //#180;   //本来是2ms传输一次数据，现在缩小为200ns，前面经过了一个时钟周期，因此要 -20ns  
            repeat(9) @(negedge clk); // 1 + 9 = 10拍，严格等于 200ns        
        end
        //关闭起摆使能
        @(negedge clk);
        swing_en = 1'b0;
        #200;

        $stop;
    end

endmodule