`timescale 1ns / 1ps

/**
 * Module: pucch_threshold_decision
 * Description: Decision logic using an adaptive threshold (CFAR-like).
 * Logic: 11 * Max_Power > (Total_Power - Max_Power) * 2^alpha_shift
 */

module pucch_threshold_decision (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        i_en,
    input  wire [15:0] i_max_val,
    input  wire [3:0]  i_max_idx,
    input  wire [20:0] i_total_sum,
    input  wire [3:0]  i_alpha_shift,
    
    output reg  [3:0]  o_peak_index,
    output reg         o_peak_valid, // 1: Signal detected, 0: DTX
    output reg         o_done
);

    // Internal wires for noise calculation
    wire [20:0] w_noise_mag = i_total_sum - i_max_val;
    
    // Pipeline registers
    reg [39:0] reg_left_side;  // Scaled Signal
    reg [39:0] reg_right_side; // Scaled Noise
    reg [3:0]  reg_idx;
    reg        reg_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_left_side  <= 40'd0;
            reg_right_side <= 40'd0;
            reg_idx        <= 4'd0;
            reg_valid      <= 1'b0;
            o_peak_index   <= 4'd0;
            o_peak_valid   <= 1'b0;
            o_done         <= 1'b0;
        end else begin
            // --- STAGE 1: Calculate Sides ---
            reg_valid <= i_en;
            reg_idx   <= i_max_idx;
            
            // Left side: Signal * 11 (8 + 2 + 1)
            reg_left_side  <= (i_max_val << 3) + (i_max_val << 1) + i_max_val;
            
            // Right side: Noise * 2^alpha_shift
            reg_right_side <= {19'b0, w_noise_mag} << i_alpha_shift;

            // --- STAGE 2: Comparison Decision ---
            o_done <= reg_valid;
            if (reg_valid) begin
                // Compare with full precision to avoid overflow errors
                if (reg_left_side > reg_right_side) begin
                    o_peak_index <= reg_idx;
                    o_peak_valid <= 1'b1;
                end else begin
                    o_peak_index <= 4'd0;
                    o_peak_valid <= 1'b0;
                end
            end
        end
    end
endmodule