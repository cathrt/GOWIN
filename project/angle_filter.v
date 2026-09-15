// 模块功能：一阶IIR角度低通滤波,输出平滑角度//
module angle_filter #(
    parameter integer ADC_WIDTH    = 10,
    parameter integer FILTER_SHIFT = 3,      //2^3//       
    parameter integer FRAC_BITS    = FILTER_SHIFT + 1//滤波结果默认保留4位小数//
)(
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire [ADC_WIDTH-1:0]    angle_raw,
    input  wire                    angle_valid,//为1时滤波器更新//
    input  wire                    adc_overrange,

    // 滤波结果
    output reg  [ADC_WIDTH-1:0]    angle_filtered,
    output reg                     angle_active,//滤波有效。/
    output reg                     angle_otr
);

    
    localparam integer ACC_WIDTH = ADC_WIDTH + FRAC_BITS + 1;//累加器位宽，额外1位用于符号位//

    reg  signed [ACC_WIDTH-1:0] acc; 

    reg                         filter_init;//1为滤波初始化标志//
    wire signed [ACC_WIDTH-1:0] x_ext;        //把ADC数据扩展为内部定点格式//
    wire signed [ACC_WIDTH-1:0] err; //输入数据与当前的误差//         
    wire signed [ACC_WIDTH-1:0] corr;     //需要修正得数据/   
    wire signed [ACC_WIDTH-1:0] acc_next;     
    wire signed [ACC_WIDTH-1:0] out_round;    

    assign x_ext = {1'b0, angle_raw, {FRAC_BITS{1'b0}}};

    assign err = x_ext - acc;
    assign corr = (err + (1 <<< (FILTER_SHIFT-1))) >>> FILTER_SHIFT;//IIR公式计算 
//（）部分实现四舍五入//
    assign acc_next = acc + corr;

    assign out_round = (acc_next + (1 <<< (FRAC_BITS-1))) >>> FRAC_BITS;
    //右移4位恢复为普通ADC整数//
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc            <= {ACC_WIDTH{1'b0}};
            filter_init    <= 1'b0;
            angle_filtered <= {ADC_WIDTH{1'b0}};
            angle_active   <= 1'b0;
            angle_otr      <= 1'b0;
        end
        else begin
            if (angle_valid) begin
                if (!filter_init) begin
                    // 第一次采样直接作为初始滤波值，避免上电爬升瞬态//
                    acc            <= x_ext;
                    angle_filtered <= angle_raw;
                    filter_init    <= 1'b1;
                end
                else begin
                    // 正常进行IIR滤波
                    acc            <= acc_next;
                    angle_filtered <= out_round[ADC_WIDTH-1:0];
                end
                // 输出数据有效//
                angle_active <= 1'b1;

                // 传递ADC超量程标志//
                angle_otr <= adc_overrange;
            end
        end
    end

endmodule
