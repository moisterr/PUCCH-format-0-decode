`timescale 1ns / 1ps

/**
 * Module: pucch_adder_param
 * Description: Parameterized combinational adder.
 * Used to combine hopping sequences with fixed offsets before modulo reduction.
 */

module pucch_adder_param #(
    parameter WIDTH_A   = 8, // e.g., Hopping register output (8-bit)
    parameter WIDTH_B   = 5, // e.g., Fixed offset or ID (5-bit)
    parameter WIDTH_SUM = 9  // Sum width (usually MAX(A,B) + 1 to prevent overflow)
)(
    input  wire [WIDTH_A-1:0]   i_data_a,
    input  wire [WIDTH_B-1:0]   i_data_b,
    output wire [WIDTH_SUM-1:0] o_sum
);

    // Combinational unsigned addition
    // The synthesis tool will automatically handle bit-width extension
    // to match the WIDTH_SUM.
    assign o_sum = i_data_a + i_data_b;

endmodule