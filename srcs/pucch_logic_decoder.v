`timescale 1ns / 1ps

/**
 * Module: pucch_logic_decoder
 * Description: Decodes the physical peak index into HARQ-ACK and SR bits
 * based on the cyclic shift mapping defined in 3GPP standards.
 */

module pucch_logic_decoder (
    input  wire        clk,
    input  wire        rst_n,
    
    // Interface from Peak Detector
    input  wire [3:0]  i_peak_index,
    input  wire        i_is_signal,   // 1: Signal present, 0: DTX/Noise
    input  wire        i_done,         // Pulse indicating detector result is ready
    
    // System Configuration Parameters
    input  wire [3:0]  i_n_cs,
    input  wire [3:0]  i_m0,
    input  wire        i_is_2bit_mode, // 0: 1-bit HARQ, 1: 2-bit HARQ
    
    // Final Decoded Outputs
    output reg         o_dtx,          // 1: Discontinuous Transmission (No Signal)
    output reg  [1:0]  o_harq_ack,     // Decoded HARQ-ACK bits
    output reg         o_sr,           // 0: Negative SR, 1: Positive SR
    output reg         o_valid         // Pulse indicating decoding completion
);

    // =========================================================
    // 1. CYCLIC SHIFT CALCULATION (m_cs)
    // =========================================================
    // Formula: $m_{cs} = (peak\_index + 24 - n_{cs} - m_0) \pmod{12}$
    // Adding 24 ensures the value is positive before the modulo operation.
    wire [5:0] w_mcs_raw = (i_peak_index + 5'd24) - i_n_cs - i_m0;
    reg  [3:0] reg_mcs;

    always @(*) begin
        if (w_mcs_raw >= 24)      reg_mcs = w_mcs_raw - 24;
        else if (w_mcs_raw >= 12) reg_mcs = w_mcs_raw - 12;
        else                      reg_mcs = w_mcs_raw[3:0];
    end

    // =========================================================
    // 2. MAPPING LOGIC (HARQ-ACK + SR Decoding)
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_dtx      <= 1'b1;
            o_harq_ack <= 2'b00;
            o_sr       <= 1'b0;
            o_valid    <= 1'b0;
        end else if (i_done) begin
            o_valid <= 1'b1;
            
            if (!i_is_signal) begin
                // No valid signal detected by Peak Detector
                o_dtx      <= 1'b1;
                o_harq_ack <= 2'b00;
                o_sr       <= 1'b0;
            end else begin
                o_dtx <= 1'b0;
                if (!i_is_2bit_mode) begin
                    // --- 1-BIT HARQ-ACK Mode ---
                    case (reg_mcs)
                        4'd0:    begin o_harq_ack <= 2'b00; o_sr <= 1'b0; end // NACK, Neg SR
                        4'd3:    begin o_harq_ack <= 2'b00; o_sr <= 1'b1; end // NACK, Pos SR
                        4'd6:    begin o_harq_ack <= 2'b01; o_sr <= 1'b0; end // ACK,  Neg SR
                        4'd9:    begin o_harq_ack <= 2'b01; o_sr <= 1'b1; end // ACK,  Pos SR
                        default: begin o_harq_ack <= 2'b00; o_sr <= 1'b0; end
                    endcase
                end else begin
                    // --- 2-BIT HARQ-ACK Mode ---
                    case (reg_mcs)
                        4'd0:    begin o_harq_ack <= 2'b00; o_sr <= 1'b0; end // {0,0}, Neg SR
                        4'd1:    begin o_harq_ack <= 2'b00; o_sr <= 1'b1; end // {0,0}, Pos SR
                        4'd3:    begin o_harq_ack <= 2'b01; o_sr <= 1'b0; end // {0,1}, Neg SR
                        4'd4:    begin o_harq_ack <= 2'b01; o_sr <= 1'b1; end // {0,1}, Pos SR
                        4'd6:    begin o_harq_ack <= 2'b11; o_sr <= 1'b0; end // {1,1}, Neg SR
                        4'd7:    begin o_harq_ack <= 2'b11; o_sr <= 1'b1; end // {1,1}, Pos SR
                        4'd9:    begin o_harq_ack <= 2'b10; o_sr <= 1'b0; end // {1,0}, Neg SR
                        4'd10:   begin o_harq_ack <= 2'b10; o_sr <= 1'b1; end // {1,0}, Pos SR
                        default: begin o_harq_ack <= 2'b00; o_sr <= 1'b0; end
                    endcase
                end
            end
        end else begin
            o_valid <= 1'b0;
        end
    end

endmodule