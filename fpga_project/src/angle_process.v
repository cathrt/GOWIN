// 模块功能：零点校准、ADC偏差到角度换算、角速度计算//
module angle_process #(
    parameter integer ADC_WIDTH          = 10,
    parameter integer ANGLE_WIDTH        = 32,//32位Q8.8接口//
    parameter integer SYS_CLK_FREQ_HZ    = 50_000_000,
    parameter integer CONTROL_FREQ_HZ    = 1_000,//角度更新频率//
    parameter integer ANGLE_RANGE_DEG    = 345,
    parameter integer ADC_FULL_SCALE     = 1023,
    parameter integer ANGLE_SCALE        = 256,//角度放大倍数//
    parameter integer ANGLE_SIGN         = 1,//1表示传感器安装方向正向，0表示反向//
    parameter integer ANGLE_ZERO_DEFAULT = 1023//零点ADC值//
)(
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [ADC_WIDTH-1:0]         angle_filtered,//仍然是ADC原始码值，未经过零点校准和角度换算//
    input  wire                         angle_active_in,
    input  wire                         angle_otr_in,

    // 零点校准使能//
    // 置1后，在下一个控制周期采集当前角度作为零点//
    input  wire                         calib_en,


    output reg                          angle_active,
    output reg signed [ANGLE_WIDTH-1:0] angle_deg,
    output reg signed [ANGLE_WIDTH-1:0] angle_vel,//角速度//
    output reg                          angle_otr,

    // 调试输出
    output reg  [ADC_WIDTH-1:0]         angle_zero,//当前零点ADC值//
    output reg                          zero_valid//检验零点校准是否成功//
);

    localparam integer CONTROL_DIV =
        SYS_CLK_FREQ_HZ / CONTROL_FREQ_HZ;//多少个系统时钟周期为一个控制周期，默认位1KHZ//

    localparam integer ANGLE_CALC_SCALE =
        ANGLE_RANGE_DEG * ANGLE_SCALE;//角度比例计算//

    localparam integer ADC_SHIFT = ADC_WIDTH;   // 右移十位代替除法，相当于除以 2^ADC_WIDTH = 1024//

    // 角速度的饱和上下限
    localparam signed [ANGLE_WIDTH-1:0] VEL_MAX = (1 <<< (ANGLE_WIDTH-1)) - 1;
    localparam signed [ANGLE_WIDTH-1:0] VEL_MIN = -(1 <<< (ANGLE_WIDTH-1));

    reg [31:0] ctrl_cnt;

    reg signed [31:0] angle_deg_last;//上一个控制周期的角度值，用于计算角速度//
    reg               angle_init;

    wire control_tick;

    // 校准当拍即生效：calib_en 有效时用当前滤波值作为零点，22行//
    wire [ADC_WIDTH-1:0] zero_used = calib_en ? angle_filtered : angle_zero;

    wire signed [ADC_WIDTH:0] angle_filtered_extend;//默认11位//
    wire signed [ADC_WIDTH:0] angle_zero_extend;
    wire signed [ADC_WIDTH:0] angle_diff;//ADC偏差，当前-零点//

    wire signed [31:0] angle_calc_temp;
    wire signed [31:0] angle_calc_signed;
    wire signed [31:0] angle_vel_calc;
    wire signed [31:0] angle_vel_lim;
    wire signed [ANGLE_WIDTH-1:0] angle_vel_sat;

    // 控制周期到达判断//
    assign control_tick = (ctrl_cnt == CONTROL_DIV - 1);

    // 滤波数据和零点数据扩展为有符号数据//
    assign angle_filtered_extend = $signed({1'b0, angle_filtered});
    assign angle_zero_extend     = $signed({1'b0, zero_used});

    // 计算ADC数据相对于零点的偏差//
    assign angle_diff = angle_filtered_extend - angle_zero_extend;

    // ADC偏差换算为角度，单位为1/256°//
    assign angle_calc_temp =
        (angle_diff * ANGLE_CALC_SCALE + (1 <<< (ADC_SHIFT-1))) >>> ADC_SHIFT;

    // 根据传感器安装方向决定角度正负//
    assign angle_calc_signed = (ANGLE_SIGN == 1) ? angle_calc_temp: -angle_calc_temp;

    // 根据控制周期计算角速度，单位为1/256°/s//
    assign angle_vel_calc =
        (angle_calc_signed - angle_deg_last) * CONTROL_FREQ_HZ;

    // 角速度限幅后截断到输出位宽/
    assign angle_vel_lim = (angle_vel_calc > $signed(VEL_MAX)) ? $signed(VEL_MAX) :
                           (angle_vel_calc < $signed(VEL_MIN)) ? $signed(VEL_MIN) :
                           angle_vel_calc;

    assign angle_vel_sat = angle_vel_lim[ANGLE_WIDTH-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_cnt       <= 32'd0;
            angle_deg_last <= 32'sd0;
            angle_init     <= 1'b0;

            angle_active   <= 1'b0;
            angle_deg      <= {ANGLE_WIDTH{1'b0}};
            angle_vel      <= {ANGLE_WIDTH{1'b0}};
            angle_otr      <= 1'b0;

            angle_zero     <= ANGLE_ZERO_DEFAULT;
            zero_valid     <= 1'b0;
        end
        else begin
            // 产生控制周期//
            if (control_tick) ctrl_cnt <= 32'd0;
            else              ctrl_cnt <= ctrl_cnt + 1'b1;

            // 默认角度数据无效//
            angle_active <= 1'b0;

            if (control_tick && angle_active_in) begin

                // 当前控制周期角度数据有效//
                angle_active <= 1'b1;

                // 传递ADC超量程标志//
                angle_otr <= angle_otr_in;

                // 校准当前角度为零点/
                if (calib_en) begin
                    angle_zero <= angle_filtered;
                    zero_valid <= 1'b1;
                end

                // 第一次有效采样只初始化角度，避免第一次算出异常角速度//
                if (!angle_init) begin
                    angle_deg_last <= angle_calc_signed;
                    angle_deg      <= angle_calc_signed[ANGLE_WIDTH-1:0];
                    angle_vel      <= {ANGLE_WIDTH{1'b0}};
                    angle_init     <= 1'b1;
                end
                else begin
                    angle_deg      <= angle_calc_signed[ANGLE_WIDTH-1:0];
                    angle_vel      <= angle_vel_sat;
                    angle_deg_last <= angle_calc_signed;
                end
            end
        end
    end

endmodule
