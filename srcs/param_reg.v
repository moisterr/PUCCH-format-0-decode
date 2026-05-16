`timescale 1ns / 1ps

/**
 * Module: pucch_param_reg
 * Description: Parameterized register with enable and asynchronous reset.
 * Used for stable latching of configuration parameters (NID, PCI, etc.).
 */

module pucch_param_reg #(
    parameter WIDTH = 10
)(
    input  wire             i_clk,
    input  wire             i_rst_n,
    input  wire             i_en,    // Enable signal to latch new data
    input  wire [WIDTH-1:0] i_data,  // Input data stream
    output reg  [WIDTH-1:0] o_data   // Latched output value
);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // Reset to zero upon asynchronous rst_n signal
            o_data <= {WIDTH{1'b0}};
        end else if (i_en) begin
            // Update output only when enable is high
            o_data <= i_data;
        end
        // Implicit hold logic: if i_en is low, o_data retains its previous value.
    end

endmodule