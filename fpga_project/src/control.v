/*
主控状态机
状态定义:
1. 等待 (STATE_WAIT)   : 等待 key_pulse 启动
2. 起摆 (STATE_SWING)  : 摆杆晃动蓄力，输出 swing_en
3. 平衡 (STATE_BALANCE): 倾角进入 ±ANGLE_LIMIT°，输出 pid_en
4. 保护 (STATE_PROTECT): 角度超限/异常，输出 motor_stop 关闭电机
*/
module control #(
    parameter ANGLE_LIMIT = 12
  )(
    input wire clk,
    input wire rst_n,
    //角度信息输入
    input wire angle_active,            //角度有效节拍，控制PID在这个节拍下 同步 锁存最新的角度与位置
    input wire signed [15:0] angle_deg, //原始角度
    input wire angle_otr,               //角度超限标志位
    //位置信息输入
    input wire signed [31:0] cur_pos,   //当前电机转动角度
    //按键输入
    input wire key_pluse,               //按键输入，开始倒立摆
    //输出
    output reg motor_stop,              //电机停止转动标志位,[1]停止转动，[0]允许转动
    output reg swing_en,                //摆杆起摆标志位
    output reg pid_en,                  //PID使能标志位
    output reg signed [31:0] target_pos //目标位置
  );

  localparam  STATE_WAIT    = 2'b00; //等待状态
  localparam  STATE_SWING   = 2'b01; //起摆状态
  localparam  STATE_BALANCE = 2'b10; //平衡状态
  localparam  STATE_PROTECT = 2'b11; //保护状态

  //状态切换时序
  reg [1:0]state_cur;
  reg [1:0]state_next;
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state_cur <= 2'b00;
    end
    else
    begin
      state_cur <= state_next;
    end
  end

  //状态机切换逻辑
  always @(*)
  begin
    //state_next = state_cur; //默认保持当前状态，即不切换状态时保持当前状态
    case (state_cur)
      //等待状态
      STATE_WAIT:
      begin
        if (key_pluse)
        begin
          state_next = STATE_SWING; //按键启动，进入起摆状态
        end
        else
        begin
          state_next = STATE_WAIT; //继续等待
        end
      end
      //起摆状态
      STATE_SWING:
      begin
        if (angle_deg > -ANGLE_LIMIT && angle_deg < ANGLE_LIMIT && angle_active)
        begin //在这个节拍下，才进入平衡状态
          state_next = STATE_BALANCE; //角度进入 ±ANGLE_LIMIT°，进入平衡状态
        end
        else
        begin
          state_next = STATE_SWING; //继续起摆
        end
      end
      //平衡状态
      STATE_BALANCE:
      begin
        if (angle_otr)
        begin
          state_next = STATE_PROTECT; //角度超限，进入保护状态
        end
        else
        begin
          state_next = STATE_BALANCE; //继续平衡
        end
      end
      //保护状态
      STATE_PROTECT:
      begin
        if (key_pluse)
        begin
          state_next = STATE_WAIT; //按键启动，进入等待状态
        end
        else
        begin
          state_next = STATE_PROTECT; //继续保护
        end
      end

      default:
      begin
        state_next = STATE_WAIT; //默认回到等待状态
      end
    endcase
  end

  //输出时序逻辑
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      motor_stop <= 1'b1;
      swing_en <= 1'b0;
      pid_en <= 1'b0;
      target_pos <= 32'sd0;
    end
    else
    begin
      case (state_next)
        //等待状态
        STATE_WAIT:
        begin
          motor_stop <= 1'b1; //关闭电机
          swing_en <= 1'b0;
          pid_en <= 1'b0;
          target_pos <= 32'sd0;
        end
        //起摆状态
        STATE_SWING:
        begin
          motor_stop <= 1'b0;
          swing_en <= 1'b1;   //输出起摆标志位
          pid_en <= 1'b0;
          target_pos <= 32'sd0;
        end
        //平衡状态
        STATE_BALANCE:
        begin
          motor_stop <= 1'b0;
          swing_en <= 1'b0;
          pid_en <= 1'b1;        //输出PID使能标志位
          //只在进入平衡状态的第一个节拍下，锁存当前电机转动角度为目标位置
          if (state_cur != STATE_BALANCE)
          begin
            target_pos <= cur_pos;
          end
        end
        //保护状态
        STATE_PROTECT:
        begin
          motor_stop <= 1'b1; //关闭电机
          swing_en <= 1'b0;
          pid_en <= 1'b0;
          target_pos <= 32'sd0;
        end

        default:
        begin
          motor_stop <= 1'b1; //关闭电机
          swing_en <= 1'b0;
          pid_en <= 1'b0;
          target_pos <= 32'sd0;
        end
      endcase
    end
  end

endmodule
