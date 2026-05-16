`timescale 1ns / 1ps

module pucch_vcu118_wrapper (
    input  wire        i_sysclk_p, i_sysclk_n,  // 300 MHz LVDS - G31/F31
    input  wire        i_cpu_reset,              // Active-HIGH - L19
    output wire [7:0]  o_led
);

    // =========================================================
    // 1. CLOCK & RESET
    // =========================================================
    wire clk_122m88;
    wire locked;
    wire w_soft_rst_vio;

    // sys_reset: dùng ?? reset MMCM (ch? dùng cpu_reset, không dùng soft_rst
    // vì soft_rst ch? reset logic bên trong, không c?n reset MMCM)
    wire sys_reset = i_cpu_reset;

    clk_wiz_0 i_clk_wiz (
        .clk_in1_p (i_sysclk_p),
        .clk_in1_n (i_sysclk_n),
        .clk_out1  (clk_122m88),
        .reset     (sys_reset),
        .locked    (locked)
    );

    // rst_n_internal: active-low, ch? b?t khi MMCM locked
    // soft_rst_vio cho phép reset logic t? VIO mà không reset MMCM
    wire rst_n_internal = locked && !(i_cpu_reset | w_soft_rst_vio);

    // =========================================================
    // 2. INTERNAL WIRES
    // =========================================================

    // VIO control outputs
    wire        w_nid_change_en;
    wire [9:0]  w_pci;
    wire [9:0]  w_hopping_id;
    wire        w_rrc_configured;
    wire [3:0]  w_m0;
    wire        w_group_hopping;
    wire        w_is_2bit_mode;
    wire [11:0] w_start_re_idx;
    wire [3:0]  w_alpha_shift;
    wire [4:0]  w_curr_slot;
    wire [3:0]  w_curr_symbol;
    wire [1:0]  w_scenario_sel;
    wire        w_start_playback;

    // Playback
    wire [13:0] w_rom_addr;
    wire [23:0] w_rom_data;
    wire        w_rom_ena;
    wire [23:0] w_playback_tdata;
    wire        w_playback_tvalid;
    wire        w_playback_tready;
    wire        w_playback_done;

    // pucch_top expose
    wire        w_adc_gate_en_out;

    // Gate: ch? b?t ??u playback khi FSM ?ã ? ST_READY
    wire        w_start_safe = w_start_playback && w_adc_gate_en_out;

    // Results
    wire [1:0]  w_final_harq;
    wire        w_final_sr;
    wire        w_final_dtx;
    wire        w_final_valid;

    // =========================================================
    // 3. VIO - 15 outputs, 4 inputs
    // =========================================================
    vio_0 i_vio_ctrl (
        .clk        (clk_122m88),
        // Outputs ? vào design
        .probe_out0 (w_nid_change_en),   // [0:0]  kích pre_cal
        .probe_out1 (w_pci),             // [9:0]
        .probe_out2 (w_hopping_id),      // [9:0]
        .probe_out3 (w_rrc_configured),  // [0:0]
        .probe_out4 (w_m0),              // [3:0]
        .probe_out5 (w_group_hopping),   // [0:0]
        .probe_out6 (w_is_2bit_mode),    // [0:0]
        .probe_out7 (w_start_re_idx),    // [11:0]
        .probe_out8 (w_alpha_shift),     // [3:0]
        .probe_out9(w_curr_slot),       // [4:0]
        .probe_out10(w_curr_symbol),     // [3:0]
        .probe_out11(w_scenario_sel),    // [1:0]  ch?n scenario 0/1/2
        .probe_out12(w_start_playback),  // [0:0]  trigger phát data
        .probe_out13(w_soft_rst_vio),    // [0:0]  soft reset
        // Inputs ? quan sát trên VIO
        .probe_in0  (w_playback_tready), // [0:0]  pipeline s?n sàng nh?n
        .probe_in1  (w_final_valid),     // [0:0]  có k?t qu?
        .probe_in2  (w_adc_gate_en_out), // [0:0]  FSM ?ang READY
        .probe_in3  (w_playback_done)    // [0:0]  stream xong
    );

    // =========================================================
    // 4. ROM BRAM - ch?a 3 scenario ADC data (.coe)
    //    Depth: 4384+4448+4448 = 13280, Width: 24-bit
    //    Latency: 1 cycle (no output register)
    // =========================================================
    rom_pucch_data i_rom_data (
        .clka  (clk_122m88),
        .ena   (w_rom_ena),
        .addra (w_rom_addr),
        .douta (w_rom_data)
    );

    // =========================================================
    // 5. PLAYBACK CONTROLLER
    // =========================================================
    pucch_playback_ctrl i_playback_ctrl (
        .clk            (clk_122m88),
        .rst_n          (rst_n_internal),
        .i_scenario_sel (w_scenario_sel),
        .i_start_pulse  (w_start_safe),      // gate: ch? ch?y khi FSM READY
        .o_rom_ena      (w_rom_ena),
        .o_rom_addr     (w_rom_addr),
        .i_rom_data     (w_rom_data),
        .o_playback_done(w_playback_done),   // ? i_decode_done c?a pucch_top
        .o_adc_tdata    (w_playback_tdata),
        .o_adc_tvalid   (w_playback_tvalid),
        .i_adc_tready   (w_playback_tready)
    );

    // =========================================================
    // 6. PUCCH_TOP
    // =========================================================
    pucch_top #(
        .FFT_SIZE     (4096),
        .CP_LEN_LONG  (352),
        .CP_LEN_SHORT (288)
    ) i_pucch_core (
        .i_clk           (clk_122m88),
        .i_rst_n         (rst_n_internal),
        .i_nid_change_en (w_nid_change_en),
        .i_pci           (w_pci),
        .i_hopping_id    (w_hopping_id),
        .i_rrc_configured(w_rrc_configured),
        .i_m0            (w_m0),
        .i_group_hopping (w_group_hopping),
        .i_is_2bit_mode  (w_is_2bit_mode),
        .i_start_re_idx  (w_start_re_idx),
        .i_alpha_shift   (w_alpha_shift),
        .i_adc_tdata     (w_playback_tdata),
        .i_adc_tvalid    (w_playback_tvalid),
        .o_adc_tready    (w_playback_tready),
        .i_curr_slot     (w_curr_slot),
        .i_curr_symbol   (w_curr_symbol),
        .i_decode_done   (w_playback_done),  // ? playback_done thay vì final_valid
        .o_adc_gate_en   (w_adc_gate_en_out),
        .o_final_harq    (w_final_harq),
        .o_final_sr      (w_final_sr),
        .o_final_dtx     (w_final_dtx),
        .o_final_valid   (w_final_valid)
    );

    // =========================================================
    // 7. ILA - 10 probes
    // =========================================================
    ila_pucch i_ila_monitor (
        .clk    (clk_122m88),
        .probe0 (w_playback_tdata),    // [23:0] ADC data stream
        .probe1 (w_playback_tvalid),   // [0:0]
        .probe2 (w_playback_tready),   // [0:0]
        .probe3 (w_final_harq),        // [1:0]
        .probe4 (w_final_sr),          // [0:0]
        .probe5 (w_final_valid),       // [0:0]  ? ??t trigger Rising Edge ? ?ây
        .probe6 (w_final_dtx),         // [0:0]
        .probe7 (w_adc_gate_en_out),   // [0:0]  FSM READY
        .probe8 (w_playback_done),     // [0:0]  stream xong
        .probe9 (w_rom_addr)           // [13:0] kéo c? bus ?? verify addr
    );

    // =========================================================
    // 8. GPIO LEDs
    // =========================================================
    assign o_led[0] = rst_n_internal;    // h? th?ng ?ã s?n sàng
    assign o_led[1] = w_adc_gate_en_out; // FSM READY
    assign o_led[2] = w_playback_tvalid; // ?ang stream
    assign o_led[3] = w_playback_done;   // stream xong (pulse ng?n)
    assign o_led[4] = w_final_valid;     // có k?t qu?
    assign o_led[5] = w_final_sr;
    assign o_led[6] = w_final_dtx;
    assign o_led[7] = w_final_harq[0];

endmodule