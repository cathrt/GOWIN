`timescale 1ns/1ps

module swing_test;
    reg  clk;
    reg  rst_n;
    //控制信息
    reg  swing_en;
    reg  angle_active;
    //角度信息
    reg  signed [17:0] angle_deg;
    reg  signed [17:0] angle_vel;
    wire signed [17:0] swing_data;

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
        angle_deg = 17'sd0;
        angle_vel = 17'sd0;
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
                // 状态 0: 下半周 + 顺时针 (|θ| > 90°, vel <= 0) 预期输出 2500 * 0.3  = 750 
                0: begin
                    angle_deg = 17'sd15360; // 120° * 128 (下半周)
                    angle_vel = -17'sd500;  // 顺时针
                end
                // 状态 1: 下半周 + 逆时针 (|θ| > 90°, vel >  0) 预期输出 -750
                1: begin
                    angle_deg = 17'sd15360; // 120° * 128 (下半周)
                    angle_vel = 17'sd500;   // 逆时针
                end
                // 状态 2: 上半周 + 顺时针 (|θ| <= 90°, vel <= 0) 预期输出 -450
                2: begin
                    angle_deg = 17'sd5760;  // 45° * 128 (上半周)
                    angle_vel = -17'sd500;  // 顺时针
                end
                // 状态 3: 上半周 + 逆时针 (|θ| <= 90°, vel >  0) 预期输出 450 
                3: begin
                    angle_deg = 17'sd5760;  // 45° * 128 (上半周)
                    angle_vel = 17'sd500;   // 逆时针
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