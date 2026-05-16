`timescale 1ns / 1ps

/**
 * Module: pucch_demapper
 * Description: Extracts 12 Resource Elements (REs) from the FFT output grid
 * starting from the designated start_re_idx.
 */

module pucch_demapper (
    input  wire        clk,
    input  wire        rst_n,
    
    // Interface from FFT Wrapper (32-bit complex)
    input  wire [31:0] i_fft_real,
    input  wire [31:0] i_fft_imag,
    input  wire [11:0] i_fft_index,
    input  wire        i_fft_valid,
    
    // Configuration
    input  wire [11:0] i_start_re_idx, 
    
    // Interface Output (16-bit complex)
    output reg  [15:0] o_pucch_real,
    output reg  [15:0] o_pucch_imag,
    output reg         o_pucch_valid,
    output reg         o_pucch_last
);

    // =============================================================
    // 1. INPUT REGISTER STAGE (Timing Buffer)
    // =============================================================
    reg [31:0] reg_fft_real;
    reg [31:0] reg_fft_imag;
    reg [11:0] reg_fft_index;
    reg        reg_fft_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_fft_real  <= 32'd0;
            reg_fft_imag  <= 32'd0;
            reg_fft_index <= 12'd0;
            reg_fft_valid <= 1'b0;
        end else begin
            reg_fft_real  <= i_fft_real;
            reg_fft_imag  <= i_fft_imag;
            reg_fft_index <= i_fft_index;
            reg_fft_valid <= i_fft_valid;
        end
    end

    // =============================================================
    // 2. FSM LOGIC (Sequential & Combinational Blocks)
    // =============================================================
    localparam ST_IDLE    = 2'b00;
    localparam ST_EXTRACT = 2'b01;
    localparam ST_DONE    = 2'b10;

    reg [1:0]  state, next_state;
    reg [3:0]  sample_cnt, next_sample_cnt;
    reg [15:0] next_pucch_real, next_pucch_imag;
    reg        next_pucch_valid, next_pucch_last;

    // --- Sequential Block: State and Output Update ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            sample_cnt     <= 4'd0;
            o_pucch_real   <= 16'd0;
            o_pucch_imag   <= 16'd0;
            o_pucch_valid  <= 1'b0;
            o_pucch_last   <= 1'b0;
        end else begin
            state          <= next_state;
            sample_cnt     <= next_sample_cnt;
            o_pucch_real   <= next_pucch_real;
            o_pucch_imag   <= next_pucch_imag;
            o_pucch_valid  <= next_pucch_valid;
            o_pucch_last   <= next_pucch_last;
        end
    end

    // --- Combinational Block: Logic Computation ---
    always @(*) begin
        // Default assignments to maintain current values and avoid latches
        next_state        = state;
        next_sample_cnt   = sample_cnt;
        next_pucch_real   = 16'd0;
        next_pucch_imag   = 16'd0;
        next_pucch_valid  = 1'b0;
        next_pucch_last   = 1'b0;

        case (state)
            ST_IDLE: begin
                // Transition to EXTRACT when start index is matched
                if (reg_fft_valid && (reg_fft_index == i_start_re_idx)) begin
                    next_state       = ST_EXTRACT;
                    next_sample_cnt  = 4'd1; // First sample identified
                    next_pucch_real  = reg_fft_real[23:8]; // Fixed bit selection
                    next_pucch_imag  = reg_fft_imag[23:8];
                    next_pucch_valid = 1'b1;
                end
            end

            ST_EXTRACT: begin
                if (reg_fft_valid) begin
                    next_pucch_real  = reg_fft_real[23:8];
                    next_pucch_imag  = reg_fft_imag[23:8];
                    next_pucch_valid = 1'b1;
                    
                    if (sample_cnt == 4'd11) begin
                        next_state      = ST_DONE;
                        next_pucch_last = 1'b1; // Mark the end of the RB (12 REs)
                    end else begin
                        next_sample_cnt = sample_cnt + 4'd1;
                    end
                end
            end

            ST_DONE: begin
                next_state      = ST_IDLE;
                next_sample_cnt = 4'd0;
            end
            
            default: next_state = ST_IDLE;
        endcase
    end

endmodule