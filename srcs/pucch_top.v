`timescale 1ns / 1ps

module pucch_top #(
    parameter FFT_SIZE     = 4096,
    parameter CP_LEN_LONG  = 352,
    parameter CP_LEN_SHORT = 288
)(
    input  wire        i_clk,
    input  wire        i_rst_n,

    // --- Configuration Triggers ---
    input  wire        i_nid_change_en,

    // --- Network & Cell Parameters ---
    input  wire [9:0]  i_pci,
    input  wire [9:0]  i_hopping_id,
    input  wire        i_rrc_configured,

    // --- Decoding Static Configuration ---
    input  wire [3:0]  i_m0,
    input  wire        i_group_hopping,
    input  wire        i_is_2bit_mode,
    input  wire [11:0] i_start_re_idx,
    input  wire [3:0]  i_alpha_shift,

    // --- ADC Input AXI-Stream ---
    input  wire [23:0] i_adc_tdata,
    input  wire        i_adc_tvalid,
    output wire        o_adc_tready,

    // --- Real-time Timing Reference ---
    input  wire [4:0]  i_curr_slot,
    input  wire [3:0]  i_curr_symbol,

    // --- Decode Done ---
    // N?i v?i o_playback_done t? pucch_playback_ctrl
    // FSM ch? v? IDLE sau khi stream xong, không ph?i khi final_valid lên
    input  wire        i_decode_done,

    // --- Status expose ra wrapper ---
    output wire        o_adc_gate_en,   // FSM ?ang ? ST_READY

    // --- Final Decoded Results ---
    output wire [1:0]  o_final_harq,
    output wire        o_final_sr,
    output wire        o_final_dtx,
    output wire        o_final_valid
);

    // =========================================================
    // 1. INTERNAL WIRES
    // =========================================================
    wire w_run_pre_cal;
    wire w_adc_gate_en;
    wire w_pre_cal_done;
    wire w_internal_ready;
    wire w_flush;

    // =========================================================
    // 2. FSM CONTROLLER
    // =========================================================
    pucch_controller i_pucch_controller (
        .clk            (i_clk),
        .rst_n          (i_rst_n),
        .nid_change_en  (i_nid_change_en),
        .pre_cal_done   (w_pre_cal_done),
        .PCI            (i_pci),
        .hoppingID      (i_hopping_id),
        .RRC_configured (i_rrc_configured),
        .decode_done    (i_decode_done),    
        .run_pre_cal    (w_run_pre_cal),
        .adc_gate_en    (w_adc_gate_en),
        .flush          (w_flush)
    );

    // =========================================================
    // 3. MAIN DATAPATH
    // =========================================================
    pucch_datapath #(
        .FFT_SIZE     (FFT_SIZE),
        .CP_LEN_LONG  (CP_LEN_LONG),
        .CP_LEN_SHORT (CP_LEN_SHORT)
    ) i_pucch_datapath (
        .clk                (i_clk),
        .rst_n              (i_rst_n),
        .i_run_pre_cal      (w_run_pre_cal),
        .i_adc_valid_gated  (i_adc_tvalid && w_adc_gate_en),
        .i_flush            (w_flush),
        .i_pci              (i_pci),
        .i_hopping_id       (i_hopping_id),
        .i_rrc_configured   (i_rrc_configured),
        .i_m0               (i_m0),
        .i_group_hopping    (i_group_hopping),
        .i_is_2bit_mode     (i_is_2bit_mode),
        .i_start_re_idx     (i_start_re_idx),
        .i_alpha_shift      (i_alpha_shift),
        .i_param_en         (i_nid_change_en),
        .i_curr_slot        (i_curr_slot),
        .i_curr_symbol      (i_curr_symbol),
        .i_adc_tdata        (i_adc_tdata),
        .o_pre_cal_done     (w_pre_cal_done),
        .o_internal_ready   (w_internal_ready),
        .o_final_harq       (o_final_harq),
        .o_final_sr         (o_final_sr),
        .o_final_dtx        (o_final_dtx),
        .o_final_valid      (o_final_valid)
    );

    // =========================================================
    // 4. OUTPUT
    // =========================================================
    assign o_adc_tready  = w_adc_gate_en && w_internal_ready;
    assign o_adc_gate_en = w_adc_gate_en;

endmodule