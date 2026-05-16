`timescale 1ns / 1ps

/**
 * Module: pucch_peak_detector
 * Description: 3-stage comparison tree to find the global peak among 12 IDFT outputs.
 * Followed by a threshold decision stage. Total Latency: 5 cycles.
 */

module pucch_peak_detector (
    input  wire          clk,
    input  wire          rst_n,
    input  wire [191:0]  i_pwr_bus,    // 12 magnitude samples from IDFT
    input  wire          i_valid,      // Valid pulse from IDFT
    input  wire [3:0]    i_alpha_shift,
    
    output wire [3:0]    o_peak_index,
    output wire          o_is_signal, 
    output wire          o_done         
);

    // --- Intermediate Signals for the Tree ---
    wire [15:0] w_s1_max [0:5]; wire [3:0] w_s1_idx [0:5]; wire [16:0] w_s1_sum [0:5]; wire w_v1;
    wire [15:0] w_s2_max [0:2]; wire [3:0] w_s2_idx [0:2]; wire [18:0] w_s2_sum [0:2]; wire w_v2;

    // =========================================================
    // STAGE 1: 6 Parallel Comparators (12 -> 6)
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : gen_stage1
            pucch_cmp_sum_unit #(.DATA_W(16), .SUM_W(17)) u1 (
                .clk(clk), .rst_n(rst_n), .i_en(i_valid),
                .i_val_a(i_pwr_bus[(2*i)*16 +: 16]), .i_idx_a(2*i),
                .i_val_b(i_pwr_bus[(2*i+1)*16 +: 16]), .i_idx_b(2*i+1),
                .o_max_val(w_s1_max[i]), .o_max_idx(w_s1_idx[i]), .o_sum_val(w_s1_sum[i]), .o_valid(w_v1)
            );
        end
    endgenerate

    // =========================================================
    // STAGE 2: 3 Parallel Comparators (6 -> 3)
    // =========================================================
    generate
        for (i = 0; i < 3; i = i + 1) begin : gen_stage2
            pucch_cmp_sum_unit #(.DATA_W(16), .SUM_W(19)) u2 (
                .clk(clk), .rst_n(rst_n), .i_en(w_v1),
                .i_val_a(w_s1_max[2*i]),     .i_idx_a(w_s1_idx[2*i]),
                .i_val_b(w_s1_max[2*i+1]),   .i_idx_b(w_s1_idx[2*i+1]),
                .o_max_val(w_s2_max[i]), .o_max_idx(w_s2_idx[i]), 
                .o_sum_val(w_s2_sum[i]), .o_valid(w_v2)
            );
        end
    endgenerate

    // =========================================================
    // STAGE 3: Final 3-way Comparison & Total Sum (1 Cycle)
    // =========================================================
    reg [15:0] reg_final_max; 
    reg [3:0]  reg_final_idx; 
    reg [20:0] reg_total_sum; 
    reg        reg_v3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_v3        <= 1'b0;
            reg_final_max <= 16'd0;
            reg_final_idx <= 4'd0;
            reg_total_sum <= 21'd0;
        end else begin
            reg_v3        <= w_v2;
            reg_total_sum <= w_s2_sum[0] + w_s2_sum[1] + w_s2_sum[2];
            
            // Efficient 3-way max detection
            if (w_s2_max[0] >= w_s2_max[1] && w_s2_max[0] >= w_s2_max[2]) begin
                reg_final_max <= w_s2_max[0]; reg_final_idx <= w_s2_idx[0];
            end else if (w_s2_max[1] >= w_s2_max[0] && w_s2_max[1] >= w_s2_max[2]) begin
                reg_final_max <= w_s2_max[1]; reg_final_idx <= w_s2_idx[1];
            end else begin
                reg_final_max <= w_s2_max[2]; reg_final_idx <= w_s2_idx[2];
            end
        end
    end

    // =========================================================
    // STAGE 4 & 5: Threshold Decision
    // =========================================================
    pucch_threshold_decision u_decision (
        .clk(clk), .rst_n(rst_n), .i_en(reg_v3),
        .i_max_val(reg_final_max), .i_max_idx(reg_final_idx), 
        .i_total_sum(reg_total_sum), .i_alpha_shift(i_alpha_shift),
        .o_peak_index(o_peak_index), .o_peak_valid(o_is_signal), 
        .o_done(o_done)
    );

endmodule