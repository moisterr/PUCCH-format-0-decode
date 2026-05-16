`timescale 1ns / 1ps

/**
 * Module: pucch_controller
 * Description: High-level Finite State Machine (FSM) for PUCCH Format 0.
 * Coordinates between pipeline flushing, parameter pre-calculation, and decoding.
 * * Features:
 * - 16-cycle mandatory ST_FLUSH to clear pipeline tails.
 * - Smart Hopping Skip: Bypasses ST_CALC if NID remains unchanged.
 * - Registered outputs for optimized timing and glitch prevention.
 */

module pucch_controller (
    input  wire        clk,
    input  wire        rst_n,
    
    // --- Handshake Signals ---
    input  wire        nid_change_en, // From Top-level (Trigger)
    input  wire        pre_cal_done,  // From Pre-calculation engine
    input  wire        decode_done,   // From Decoder (final_valid)
    
    // --- Config Parameters ---
    input  wire [9:0]  PCI,
    input  wire [9:0]  hoppingID,
    input  wire        RRC_configured,
    
    // --- System Control Outputs ---
    output reg         run_pre_cal,   // Enable BRAM write process
    output reg         adc_gate_en,   // Open gate for ADC stream (ST_READY)
    output reg         flush          // Pipeline clear signal (active high)
);

    // =========================================================
    // 1. STATE DEFINITIONS
    // =========================================================
    typedef enum reg [1:0] {
        ST_IDLE  = 2'b00,
        ST_FLUSH = 2'b01, // Pipeline clearing phase
        ST_CALC  = 2'b10, // BRAM population phase
        ST_READY = 2'b11  // Active decoding phase
    } state_t;

    state_t state;
    state_t next_state;
    reg [3:0] reg_flush_cnt;

    // =========================================================
    // 2. NID MONITORING LOGIC (Smart Skip Strategy)
    // =========================================================
    wire [9:0] w_incoming_nid = RRC_configured ? hoppingID : PCI;
    reg  [9:0] reg_active_nid;
    
    // Check if the current configuration requires a BRAM refresh
    wire w_nid_changed = (w_incoming_nid != reg_active_nid);

    // Update active NID only after BRAM is fully populated
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            reg_active_nid <= 10'h3FF; // Initial value forces first calculation
        else if (state == ST_CALC && pre_cal_done)
            reg_active_nid <= w_incoming_nid;
    end

    // =========================================================
    // 3. FSM STATE TRANSITIONS
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else        state <= next_state;
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            // Trigger start on nid_change_en pulse
            ST_IDLE: begin
                if (nid_change_en) next_state = ST_FLUSH;
            end
            
            // Mandatory 16-cycle flush before any new operation
            ST_FLUSH: begin
                if (reg_flush_cnt == 4'd15) begin
                    if (w_nid_changed) next_state = ST_CALC;  // Refresh BRAM
                    else               next_state = ST_READY; // Skip to Ready
                end
            end
            
            // Wait for Pre-calculation engine to finish BRAM write
            ST_CALC: begin
                if (pre_cal_done) next_state = ST_READY;
            end
            
            // Open ADC gate and wait for symbol decoding completion
            ST_READY: begin
                if (decode_done) begin
                    if (nid_change_en) next_state = ST_FLUSH; // Re-trigger
                    else               next_state = ST_IDLE;
                end
            end
            
            default: next_state = ST_IDLE;
        endcase
    end

    // =========================================================
    // 4. REGISTERED CONTROL OUTPUTS
    // =========================================================
    // Using next_state logic within a clocked block ensures clean 
    // signals with minimal latency.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run_pre_cal   <= 1'b0;
            adc_gate_en   <= 1'b0;
            flush         <= 1'b0;
            reg_flush_cnt <= 4'd0;
        end else begin
            // Drive outputs based on the upcoming state
            run_pre_cal <= (next_state == ST_CALC);
            adc_gate_en <= (next_state == ST_READY);
            flush       <= (next_state == ST_FLUSH);
            
            // Flush counter management
            if (next_state == ST_FLUSH) 
                reg_flush_cnt <= reg_flush_cnt + 4'd1;
            else 
                reg_flush_cnt <= 4'd0;
        end
    end

endmodule