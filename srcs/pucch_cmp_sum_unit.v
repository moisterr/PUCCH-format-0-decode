`timescale 1ns / 1ps

/**
 * Module: pucch_cmp_sum_unit
 * Description: Basic unit to compare two values, find the maximum with its index, 
 * and calculate their sum in a single pipeline stage.
 */

module pucch_cmp_sum_unit #(
    parameter DATA_W = 16,
    parameter SUM_W  = 17
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              i_en,
    input  wire [DATA_W-1:0] i_val_a,
    input  wire [DATA_W-1:0] i_val_b,
    input  wire [3:0]        i_idx_a,
    input  wire [3:0]        i_idx_b,
    
    output reg  [DATA_W-1:0] o_max_val,
    output reg  [3:0]        o_max_idx,
    output reg  [SUM_W-1:0]  o_sum_val,
    output reg               o_valid
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_max_val <= 0;
            o_max_idx <= 0;
            o_sum_val <= 0;
            o_valid   <= 0;
        end else if (i_en) begin
            o_valid   <= 1'b1;
            o_sum_val <= i_val_a + i_val_b;
            if (i_val_a >= i_val_b) begin
                o_max_val <= i_val_a;
                o_max_idx <= i_idx_a;
            end else begin
                o_max_val <= i_val_b;
                o_max_idx <= i_idx_b;
            end
        end else begin
            o_valid   <= 1'b0;
        end
    end
endmodule