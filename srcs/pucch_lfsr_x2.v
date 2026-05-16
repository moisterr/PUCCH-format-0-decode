`timescale 1ns / 1ps

module pucch_lfsr_x2 (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_load_en,
    input  wire        i_shift_en,
    input  wire [30:0] i_seed,
    output wire        o_bit
);

    reg [30:0] reg_state;

    // Feedback logic for x2: x2(n+31) = x2(n+3) ^ x2(n+2) ^ x2(n+1) ^ x2(n)
    wire w_feedback = reg_state[3] ^ reg_state[2] ^ reg_state[1] ^ reg_state[0];

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            reg_state <= 31'h1;
        end else if (i_load_en) begin
            reg_state <= i_seed;
        end else if (i_shift_en) begin
            reg_state <= {w_feedback, reg_state[30:1]};
        end
    end

    assign o_bit = reg_state[0];

endmodule