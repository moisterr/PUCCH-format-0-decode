`timescale 1ns / 1ps

module pucch_datapath #(
    parameter FFT_SIZE = 4096,
    parameter CP_LEN_LONG  = 352,
    parameter CP_LEN_SHORT = 288
)(
    input  wire        clk, rst_n,
    input  wire        i_run_pre_cal, i_adc_valid_gated, i_flush,
    input  wire [9:0]  i_pci, i_hopping_id, i_rrc_configured,
    input  wire [3:0]  i_m0, i_alpha_shift,
    input  wire        i_group_hopping, i_is_2bit_mode, i_param_en,
    input  wire [11:0] i_start_re_idx,
    input  wire [4:0]  i_curr_slot,
    input  wire [3:0]  i_curr_symbol,
    input  wire [23:0] i_adc_tdata,

    output wire        o_pre_cal_done, o_internal_ready,
    output wire [1:0]  o_final_harq,
    output wire        o_final_sr, o_final_dtx, o_final_valid
);

    // BRAM Signals
    wire [8:0]  w_pre_cal_addr;
    wire [13:0] w_pre_cal_din;
    wire        w_pre_cal_we;
    wire [8:0]  w_read_addr_wire = ({4'b0, i_curr_slot} * 9'd14) + {5'b0, i_curr_symbol};
    reg  [8:0]  reg_read_addr_d1;

    // Logic: Exactly 1-cycle delay for BRAM address as per original
    always @(posedge clk) reg_read_addr_d1 <= w_read_addr_wire;

    wire [13:0] w_bram_dout;

    // Sub-modules Instantiation
    pucch_pre_cal_top i_pre_cal (
        .clk(clk), .rst_n(rst_n),
        .i_pci(i_pci), .i_hopping_id(i_hopping_id), .i_rrc_configured(i_rrc_configured),
        .i_run_en(i_run_pre_cal), .i_param_en(i_param_en),
        .o_bram_addr(w_pre_cal_addr), .o_bram_din(w_pre_cal_din),
        .o_bram_we(w_pre_cal_we), .o_done(o_pre_cal_done)
    );

    param_BRAM i_pucch_param_bram (
        .clka(clk), .wea(w_pre_cal_we), .addra(w_pre_cal_addr), .dina(w_pre_cal_din),
        .clkb(clk), .addrb(reg_read_addr_d1), .doutb(w_bram_dout)
    );

    pucch_decode_top #(
        .FFT_SIZE     (FFT_SIZE), 
        .CP_LEN_LONG  (CP_LEN_LONG), 
        .CP_LEN_SHORT (CP_LEN_SHORT)
    ) i_pucch_decode_top (
        .clk               (clk), 
        .rst_n             (rst_n && !i_flush), 
        
        // Input AXI-Stream
        .s_axis_adc_tdata  (i_adc_tdata),       
        .s_axis_adc_tvalid (i_adc_valid_gated), 
        .s_axis_adc_tready (o_internal_ready),  
        .i_symbol_idx      (i_curr_symbol),     
        
        // Parameters
        .i_param_bram_dout (w_bram_dout),
        .i_group_hopping   (i_group_hopping),   
        .i_start_re_idx    (i_start_re_idx),    
        .i_alpha_shift     (i_alpha_shift),     
        .i_m0              (i_m0),              
        .i_is_2bit_mode    (i_is_2bit_mode),    
        
        // Final Results 
        .o_final_harq      (o_final_harq), 
        .o_final_sr        (o_final_sr),
        .o_final_dtx       (o_final_dtx), 
        .o_final_valid     (o_final_valid),
        
        // Diagnostics
        .o_diag_peak_idx   (), 
        .o_diag_pucch_real (),
        .o_diag_pucch_imag ()
    );

endmodule