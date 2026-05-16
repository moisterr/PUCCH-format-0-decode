`timescale 1ns / 1ps

/**
 * Module: pucch_decode_top
 * Description: High-performance 5G NR PUCCH Format 0 Receiver.
 * Integrates CP Removal, FFT, De-mapping, De-spreading, IDFT, and Detection.
 * Optimization: Full Pipeline architecture with Registered Control Paths.
 */

module pucch_decode_top #(
    parameter FFT_SIZE     = 4096,
    parameter CP_LEN_LONG  = 352,
    parameter CP_LEN_SHORT = 288
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // --- Input AXI-Stream Interface (From ADC) ---
    input  wire [23:0] s_axis_adc_tdata,
    input  wire        s_axis_adc_tvalid,
    output wire        s_axis_adc_tready,
    input  wire [3:0]  i_symbol_idx, 
    
    // --- Parameter Interface (From System BRAM/Controller) ---
    input  wire [13:0] i_param_bram_dout, // {u_dyn[4:0], ncs[3:0], u_fix[4:0]}
    input  wire        i_group_hopping,    
    
    // --- Static Configuration (Registered internally for Timing) ---
    input  wire [11:0] i_start_re_idx,  
    input  wire [3:0]  i_alpha_shift,   
    input  wire [3:0]  i_m0,            
    input  wire        i_is_2bit_mode,  

    // --- Final Decoded Results ---
    output wire [1:0]  o_final_harq,    
    output wire        o_final_sr,      
    output wire        o_final_dtx,     
    output wire        o_final_valid,   
    
    // --- Diagnostic Monitoring ---
    output wire [3:0]  o_diag_peak_idx, 
    output wire [15:0] o_diag_pucch_real,
    output wire [15:0] o_diag_pucch_imag
);

    // =========================================================
    // 1. PARAMETER REGISTERING (Elite Timing Optimization)
    // =========================================================
    reg [3:0] reg_ncs, reg_alpha_shift, reg_m0;
    reg [4:0] reg_active_u;
    reg       reg_is_2bit_mode;
    reg [11:0] reg_start_re_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ncs          <= 4'd0;
            reg_alpha_shift  <= 4'd0;
            reg_m0           <= 4'd0;
            reg_active_u     <= 5'd0;
            reg_is_2bit_mode <= 1'b0;
            reg_start_re_idx <= 12'd0;
        end else begin
            reg_ncs          <= i_param_bram_dout[8:5];
            reg_alpha_shift  <= i_alpha_shift;
            reg_m0           <= i_m0;
            reg_is_2bit_mode <= i_is_2bit_mode;
            reg_start_re_idx <= i_start_re_idx;
            // Select u_index based on hopping command
            reg_active_u     <= i_group_hopping ? i_param_bram_dout[13:9] : i_param_bram_dout[4:0];
        end
    end

    // =========================================================
    // 2. INTERNAL SIGNAL DECLARATIONS (w_ naming)
    // =========================================================
    wire [31:0]  w_cp2fft_data;
    wire         w_cp2fft_valid, w_cp2fft_ready, w_cp2fft_last;

    wire [31:0]  w_fft2map_real, w_fft2map_imag;
    wire [11:0]  w_fft2map_index;
    wire         w_fft2map_valid, w_fft2map_last, w_fft2map_ready;

    wire [15:0]  w_map2spread_real, w_map2spread_imag;
    wire         w_map2spread_valid, w_map2spread_last;

    wire [31:0]  w_spread2idft_data;
    wire         w_spread2idft_valid, w_spread2idft_last;

    wire [191:0] w_idft_pwr_bus; 
    wire         w_idft_valid;   

    wire [3:0]   w_det2dec_peak_idx;
    wire         w_det2dec_is_signal;
    wire         w_det2dec_done;

    // =========================================================
    // 3. PIPELINE INSTANTIATION
    // =========================================================

    // Block 1: CP Removal
    pucch_cp_remover #(
        .FFT_SIZE(FFT_SIZE), .CP_LEN_LONG(CP_LEN_LONG), .CP_LEN_SHORT(CP_LEN_SHORT)
    ) i_cp_remover (
        .clk(clk), .rst_n(rst_n),
        .s_axis_adc_tdata(s_axis_adc_tdata), .s_axis_adc_tvalid(s_axis_adc_tvalid),
        .s_axis_adc_tready(s_axis_adc_tready), .i_symbol_idx(i_symbol_idx),
        .m_axis_fft_tdata(w_cp2fft_data), .m_axis_fft_tvalid(w_cp2fft_valid),
        .m_axis_fft_tlast(w_cp2fft_last), .m_axis_fft_tready(w_cp2fft_ready)
    );

    // Block 2: FFT Core Wrapper
    pucch_fft_wrapper i_fft (
        .clk(clk), .rst_n(rst_n),
        .s_axis_data_tdata(w_cp2fft_data), .s_axis_data_tvalid(w_cp2fft_valid),
        .s_axis_data_tready(w_cp2fft_ready), .s_axis_data_tlast(w_cp2fft_last),
        .o_fft_real(w_fft2map_real), .o_fft_imag(w_fft2map_imag),
        .o_fft_index(w_fft2map_index), .o_fft_valid(w_fft2map_valid),
        .o_fft_last(w_fft2map_last), .i_fft_ready(w_fft2map_ready)
    );

    // Block 3: Frequency De-mapper
    pucch_demapper i_demapper (
        .clk(clk), .rst_n(rst_n),
        .i_fft_real(w_fft2map_real), .i_fft_imag(w_fft2map_imag),
        .i_fft_index(w_fft2map_index), .i_fft_valid(w_fft2map_valid),
        .i_start_re_idx(reg_start_re_idx),
        .o_pucch_real(w_map2spread_real), .o_pucch_imag(w_map2spread_imag),
        .o_pucch_valid(w_map2spread_valid), .o_pucch_last(w_map2spread_last)
    );

    // Block 4: Sequence De-spreader
    pucch_despreader i_despreader (
        .clk(clk), .rst_n(rst_n),
        .i_pucch_data({w_map2spread_imag, w_map2spread_real}), 
        .i_pucch_valid(w_map2spread_valid), .i_pucch_last(w_map2spread_last),
        .i_u_index(reg_active_u), 
        .o_despread_data(w_spread2idft_data), .o_despread_valid(w_spread2idft_valid),
        .o_despread_last(w_spread2idft_last)
    );

    // Block 5: 12-point IDFT Engine
    pucch_idft_top i_idft (
        .clk(clk), .rst_n(rst_n),
        .s_axis_data(w_spread2idft_data), .s_axis_valid(w_spread2idft_valid),
        .s_axis_last(w_spread2idft_last),
        .o_idft_valid(w_idft_valid),
        .o_pwr_all_bus(w_idft_pwr_bus) 
    );

    // Block 6: Peak Detector (CFAR-based)
    pucch_peak_detector i_peak_det (
        .clk(clk), .rst_n(rst_n),
        .i_pwr_bus(w_idft_pwr_bus), .i_valid(w_idft_valid), .i_alpha_shift(reg_alpha_shift),
        .o_peak_index(w_det2dec_peak_idx), .o_is_signal(w_det2dec_is_signal), .o_done(w_det2dec_done)
    );

    // Block 7: Logic Decoder (Final Decision)
    pucch_logic_decoder i_decoder (
        .clk(clk), .rst_n(rst_n),
        .i_peak_index(w_det2dec_peak_idx), .i_is_signal(w_det2dec_is_signal), .i_done(w_det2dec_done),
        .i_n_cs(reg_ncs), .i_m0(reg_m0), .i_is_2bit_mode(reg_is_2bit_mode),
        .o_dtx(o_final_dtx), .o_harq_ack(o_final_harq), .o_sr(o_final_sr), .o_valid(o_final_valid)       
    );

    // =========================================================
    // 4. DIAGNOSTICS & ASSIGNMENTS
    // =========================================================
    assign o_diag_peak_idx   = w_det2dec_peak_idx;
    assign o_diag_pucch_real = w_spread2idft_data[15:0];
    assign o_diag_pucch_imag = w_spread2idft_data[31:16];
    assign w_fft2map_ready   = 1'b1;

endmodule