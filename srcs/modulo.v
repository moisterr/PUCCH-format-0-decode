`timescale 1ns / 1ps

/**
 * Module: pucch_modulo
 * Description: Combinational module to perform modulo operation.
 * Optimized for small constant denominators like 12 or 30.
 */

module pucch_modulo #(
    parameter IN_WIDTH  = 11, // Input width (e.g., sum of 8-bit and 10-bit values)
    parameter MOD_VALUE = 30, // Modulo constant (typically 12 or 30 for PUCCH)
    parameter OUT_WIDTH = 5   // Output width (5 bits for mod 30, 4 bits for mod 12)
)(
    input  wire [IN_WIDTH-1:0]  i_data,
    output wire [OUT_WIDTH-1:0] o_data
);

    // Combinational remainder logic
    // Synthesis tools (like Vivado) will optimize this into a specialized LUT-based 
    // structure since the MOD_VALUE is a constant.
    assign o_data = i_data % MOD_VALUE;

endmodule