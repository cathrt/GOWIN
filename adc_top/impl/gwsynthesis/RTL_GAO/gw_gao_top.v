module gw_gao(
    \target_pend[15] ,
    \target_pend[14] ,
    \target_pend[13] ,
    \target_pend[12] ,
    \target_pend[11] ,
    \target_pend[10] ,
    \target_pend[9] ,
    \target_pend[8] ,
    \target_pend[7] ,
    \target_pend[6] ,
    \target_pend[5] ,
    \target_pend[4] ,
    \target_pend[3] ,
    \target_pend[2] ,
    \target_pend[1] ,
    \target_pend[0] ,
    \pos_pend[15] ,
    \pos_pend[14] ,
    \pos_pend[13] ,
    \pos_pend[12] ,
    \pos_pend[11] ,
    \pos_pend[10] ,
    \pos_pend[9] ,
    \pos_pend[8] ,
    \pos_pend[7] ,
    \pos_pend[6] ,
    \pos_pend[5] ,
    \pos_pend[4] ,
    \pos_pend[3] ,
    \pos_pend[2] ,
    \pos_pend[1] ,
    \pos_pend[0] ,
    \vel_pend[15] ,
    \vel_pend[14] ,
    \vel_pend[13] ,
    \vel_pend[12] ,
    \vel_pend[11] ,
    \vel_pend[10] ,
    \vel_pend[9] ,
    \vel_pend[8] ,
    \vel_pend[7] ,
    \vel_pend[6] ,
    \vel_pend[5] ,
    \vel_pend[4] ,
    \vel_pend[3] ,
    \vel_pend[2] ,
    \vel_pend[1] ,
    \vel_pend[0] ,
    \angle_err[15] ,
    \angle_err[14] ,
    \angle_err[13] ,
    \angle_err[12] ,
    \angle_err[11] ,
    \angle_err[10] ,
    \angle_err[9] ,
    \angle_err[8] ,
    \angle_err[7] ,
    \angle_err[6] ,
    \angle_err[5] ,
    \angle_err[4] ,
    \angle_err[3] ,
    \angle_err[2] ,
    \angle_err[1] ,
    \angle_err[0] ,
    ctrl_tick,
    \key_pulse[3] ,
    \key_pulse[2] ,
    \key_pulse[1] ,
    \key_pulse[0] ,
    clk,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input \target_pend[15] ;
input \target_pend[14] ;
input \target_pend[13] ;
input \target_pend[12] ;
input \target_pend[11] ;
input \target_pend[10] ;
input \target_pend[9] ;
input \target_pend[8] ;
input \target_pend[7] ;
input \target_pend[6] ;
input \target_pend[5] ;
input \target_pend[4] ;
input \target_pend[3] ;
input \target_pend[2] ;
input \target_pend[1] ;
input \target_pend[0] ;
input \pos_pend[15] ;
input \pos_pend[14] ;
input \pos_pend[13] ;
input \pos_pend[12] ;
input \pos_pend[11] ;
input \pos_pend[10] ;
input \pos_pend[9] ;
input \pos_pend[8] ;
input \pos_pend[7] ;
input \pos_pend[6] ;
input \pos_pend[5] ;
input \pos_pend[4] ;
input \pos_pend[3] ;
input \pos_pend[2] ;
input \pos_pend[1] ;
input \pos_pend[0] ;
input \vel_pend[15] ;
input \vel_pend[14] ;
input \vel_pend[13] ;
input \vel_pend[12] ;
input \vel_pend[11] ;
input \vel_pend[10] ;
input \vel_pend[9] ;
input \vel_pend[8] ;
input \vel_pend[7] ;
input \vel_pend[6] ;
input \vel_pend[5] ;
input \vel_pend[4] ;
input \vel_pend[3] ;
input \vel_pend[2] ;
input \vel_pend[1] ;
input \vel_pend[0] ;
input \angle_err[15] ;
input \angle_err[14] ;
input \angle_err[13] ;
input \angle_err[12] ;
input \angle_err[11] ;
input \angle_err[10] ;
input \angle_err[9] ;
input \angle_err[8] ;
input \angle_err[7] ;
input \angle_err[6] ;
input \angle_err[5] ;
input \angle_err[4] ;
input \angle_err[3] ;
input \angle_err[2] ;
input \angle_err[1] ;
input \angle_err[0] ;
input ctrl_tick;
input \key_pulse[3] ;
input \key_pulse[2] ;
input \key_pulse[1] ;
input \key_pulse[0] ;
input clk;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire \target_pend[15] ;
wire \target_pend[14] ;
wire \target_pend[13] ;
wire \target_pend[12] ;
wire \target_pend[11] ;
wire \target_pend[10] ;
wire \target_pend[9] ;
wire \target_pend[8] ;
wire \target_pend[7] ;
wire \target_pend[6] ;
wire \target_pend[5] ;
wire \target_pend[4] ;
wire \target_pend[3] ;
wire \target_pend[2] ;
wire \target_pend[1] ;
wire \target_pend[0] ;
wire \pos_pend[15] ;
wire \pos_pend[14] ;
wire \pos_pend[13] ;
wire \pos_pend[12] ;
wire \pos_pend[11] ;
wire \pos_pend[10] ;
wire \pos_pend[9] ;
wire \pos_pend[8] ;
wire \pos_pend[7] ;
wire \pos_pend[6] ;
wire \pos_pend[5] ;
wire \pos_pend[4] ;
wire \pos_pend[3] ;
wire \pos_pend[2] ;
wire \pos_pend[1] ;
wire \pos_pend[0] ;
wire \vel_pend[15] ;
wire \vel_pend[14] ;
wire \vel_pend[13] ;
wire \vel_pend[12] ;
wire \vel_pend[11] ;
wire \vel_pend[10] ;
wire \vel_pend[9] ;
wire \vel_pend[8] ;
wire \vel_pend[7] ;
wire \vel_pend[6] ;
wire \vel_pend[5] ;
wire \vel_pend[4] ;
wire \vel_pend[3] ;
wire \vel_pend[2] ;
wire \vel_pend[1] ;
wire \vel_pend[0] ;
wire \angle_err[15] ;
wire \angle_err[14] ;
wire \angle_err[13] ;
wire \angle_err[12] ;
wire \angle_err[11] ;
wire \angle_err[10] ;
wire \angle_err[9] ;
wire \angle_err[8] ;
wire \angle_err[7] ;
wire \angle_err[6] ;
wire \angle_err[5] ;
wire \angle_err[4] ;
wire \angle_err[3] ;
wire \angle_err[2] ;
wire \angle_err[1] ;
wire \angle_err[0] ;
wire ctrl_tick;
wire \key_pulse[3] ;
wire \key_pulse[2] ;
wire \key_pulse[1] ;
wire \key_pulse[0] ;
wire clk;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i(ctrl_tick),
    .trig1_i({\key_pulse[3] ,\key_pulse[2] ,\key_pulse[1] ,\key_pulse[0] }),
    .data_i({\target_pend[15] ,\target_pend[14] ,\target_pend[13] ,\target_pend[12] ,\target_pend[11] ,\target_pend[10] ,\target_pend[9] ,\target_pend[8] ,\target_pend[7] ,\target_pend[6] ,\target_pend[5] ,\target_pend[4] ,\target_pend[3] ,\target_pend[2] ,\target_pend[1] ,\target_pend[0] ,\pos_pend[15] ,\pos_pend[14] ,\pos_pend[13] ,\pos_pend[12] ,\pos_pend[11] ,\pos_pend[10] ,\pos_pend[9] ,\pos_pend[8] ,\pos_pend[7] ,\pos_pend[6] ,\pos_pend[5] ,\pos_pend[4] ,\pos_pend[3] ,\pos_pend[2] ,\pos_pend[1] ,\pos_pend[0] ,\vel_pend[15] ,\vel_pend[14] ,\vel_pend[13] ,\vel_pend[12] ,\vel_pend[11] ,\vel_pend[10] ,\vel_pend[9] ,\vel_pend[8] ,\vel_pend[7] ,\vel_pend[6] ,\vel_pend[5] ,\vel_pend[4] ,\vel_pend[3] ,\vel_pend[2] ,\vel_pend[1] ,\vel_pend[0] ,\angle_err[15] ,\angle_err[14] ,\angle_err[13] ,\angle_err[12] ,\angle_err[11] ,\angle_err[10] ,\angle_err[9] ,\angle_err[8] ,\angle_err[7] ,\angle_err[6] ,\angle_err[5] ,\angle_err[4] ,\angle_err[3] ,\angle_err[2] ,\angle_err[1] ,\angle_err[0] ,ctrl_tick}),
    .clk_i(clk)
);

endmodule
