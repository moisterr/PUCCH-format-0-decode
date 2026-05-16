`timescale 1ns / 1ps

/**
 * Module: pucch_idft_branch
 * Description: Processing Element (PE) for IDFT calculation. 
 * Performs complex multiplication and accumulation (MAC) in two pipeline stages.
 * Format: Q15 fixed-point arithmetic.
 */

module pucch_idft_branch (
    input  wire        clk,
    input  wire        rst_n,
    
    // Input Interface
    input  wire [31:0] i_sample_data,  // {Imag[31:16], Real[15:0]}
    input  wire [31:0] i_twid_coeff,   // {Imag[31:16], Real[15:0]}
    input  wire        i_en,           // Enable processing
    input  wire        i_clr,          // Clear accumulator
    
    // Output Interface (16-bit Result)
    output wire [15:0] o_res_real,
    output wire [15:0] o_res_imag
);

    // Internal signed wires for DSP inference
    wire signed [15:0] w_data_re = i_sample_data[15:0];
    wire signed [15:0] w_data_im = i_sample_data[31:16];
    wire signed [15:0] w_twid_re = i_twid_coeff[15:0];
    wire signed [15:0] w_twid_im = i_twid_coeff[31:16];

    // --- STAGE 1: Complex Multiplication (1 Cycle) ---
    // Formula: (A + jB) * (C + jD) = (AC - BD) + j(AD + BC)
    reg signed [31:0] reg_prod_re, reg_prod_im;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_prod_re <= 32'd0; 
            reg_prod_im <= 32'd0;
        end else if (i_en) begin
            // Perform multiplication and right shift 15 bits for Q15 scaling
            reg_prod_re <= (w_data_re * w_twid_re - w_data_im * w_twid_im) >>> 15;
            reg_prod_im <= (w_data_re * w_twid_im + w_data_im * w_twid_re) >>> 15;
        end
    end

    // --- STAGE 2: Accumulation (1 Cycle) ---
    reg signed [31:0] reg_acc_re, reg_acc_im;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_acc_re <= 32'd0; 
            reg_acc_im <= 32'd0;
        end else if (i_en) begin
            // If i_clr is active, start a new accumulation with the current product
            reg_acc_re <= (i_clr) ? reg_prod_re : reg_acc_re + reg_prod_re;
            reg_acc_im <= (i_clr) ? reg_prod_im : reg_acc_im + reg_prod_im;
        end
    end

    // Output mapping (Lower 16 bits of the accumulator)
    assign o_res_real = reg_acc_re[15:0];
    assign o_res_imag = reg_acc_im[15:0];

endmodule