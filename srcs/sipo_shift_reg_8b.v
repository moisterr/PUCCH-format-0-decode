`timescale 1ns / 1ps

/**
 * Module: pucch_sipo_reg_8b
 * Description: Serial-In Parallel-Out (SIPO) shift register.
 * Collects 8 serial bits from the Gold Sequence generator to form a parallel byte.
 */

module pucch_sipo_reg_8b (
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_shift_en, // Active during bit_cnt 0 to 7
    input  wire        i_bit,      // Serial bit input from Gold XOR logic
    output wire [7:0]  o_data      // 8-bit parallel output
);

    reg [7:0] reg_shift;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            reg_shift <= 8'd0;
        end else if (i_shift_en) begin
            /**
             * Shifting logic: 
             * Newest bit enters at MSB (bit 7), 
             * older bits shift down towards LSB (bit 0).
             * After 8 shifts, the first bit received resides in reg_shift[0].
             */
            reg_shift <= {i_bit, reg_shift[7:1]};
        end
    end

    // Continuous assignment: parallel data is always available for the next stage (Add/Mod)
    assign o_data = reg_shift;

endmodule