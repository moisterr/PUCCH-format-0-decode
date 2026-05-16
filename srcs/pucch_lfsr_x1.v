`timescale 1ns / 1ps

module pucch_lfsr_x1 (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_load_en,  // Load seed from Jump Matrix
    input  wire        i_shift_en, // Enable shifting
    input  wire [30:0] i_seed,     // Jumped seed value
    output wire        o_bit       // Output bit (LSB)
);

    reg [30:0] reg_state;

    // Feedback logic for x1: x1(n+31) = x1(n+3) ^ x1(n)
    wire w_feedback = reg_state[3] ^ reg_state[0];

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            reg_state <= 31'h1; // Default x1 initialization
        end else if (i_load_en) begin
            reg_state <= i_seed;
        end else if (i_shift_en) begin
            reg_state <= {w_feedback, reg_state[30:1]};
        end
    end

    assign o_bit = reg_state[0];

endmodule