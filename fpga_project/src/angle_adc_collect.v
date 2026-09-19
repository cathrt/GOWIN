//模块功能：采集10位ADC角度原始码值//
module angle_adc_collect #(
    parameter integer ADC_WIDTH      = 10,
    parameter integer CLK_FREQ_HZ    = 50_000_000,  // 系统时钟频率(PLL输出)//
    parameter integer ADC_POWERUP_US = 100          // ADC上电稳定等待(us)//
)(
    input  wire                    clk,
    input  wire                    rst_n,

    input  wire [ADC_WIDTH-1:0]    adc_data,
    input  wire                    adc_otr,

    output wire                    adc_clk,
    output wire                    adc_oe,

    // ADC采集结果
    output reg  [ADC_WIDTH-1:0]    angle_raw,
    output reg                     angle_valid,
    output reg                     adc_overrange
);

    assign adc_clk = clk;//系统时钟即可//

    // 复位同步：异步复位、同步释放
    reg [1:0] rst_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rst_sync <= 2'b00;
        else   rst_sync <= {rst_sync[0], 1'b1};
    end

    wire rst_n_sync = rst_sync[1];

    reg adc_oe_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) adc_oe_r <= 1'b1;          // 复位期间关闭ADC//
        else        adc_oe_r <= ~rst_n_sync;   // 复位释放后拉低使能//
    end

    assign adc_oe = adc_oe_r;

    // 上电稳定计数：ADC使能且时钟持续输出一段时间后数据才可信//
    localparam integer POWERUP_CYCLES = (CLK_FREQ_HZ / 1_000_000) * ADC_POWERUP_US;
    localparam integer PWR_CNT_W      = $clog2(POWERUP_CYCLES + 1);

    reg [PWR_CNT_W-1:0] pwr_cnt;
    reg                 pwr_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwr_cnt  <= {PWR_CNT_W{1'b0}};
            pwr_done <= 1'b0;
        end
        else if (rst_n_sync && !pwr_done) begin
            if (pwr_cnt >= POWERUP_CYCLES) pwr_done <= 1'b1;
            else                           pwr_cnt  <= pwr_cnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            angle_raw     <= {ADC_WIDTH{1'b0}};
            angle_valid   <= 1'b0;
            adc_overrange <= 1'b0;
        end
        else begin
            // 上电稳定后 angle_valid 持续为高//
            angle_valid <= pwr_done;

            if (pwr_done) begin
                angle_raw     <= adc_data;
                adc_overrange <= adc_otr;
            end
        end
    end

endmodule
