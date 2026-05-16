`timescale 1ns / 1ps

/**
 * Module: pucch_despreader
 * Description: Multiplies received PUCCH symbols with the conjugated base sequence 
 * from ROM based on the dynamic u_index.
 */

module pucch_despreader (
    input  wire        clk,
    input  wire        rst_n,
    
    // Input Interface (From De-mapper)
    input  wire [31:0] i_pucch_data,  
    input  wire        i_pucch_valid,
    input  wire        i_pucch_last,
    input  wire [4:0]  i_u_index,     
    
    // Output Interface (To IDFT)
    output wire [31:0] o_despread_data,  
    output wire        o_despread_valid,
    output wire        o_despread_last
);

    // =============================================================
    // 1. SAMPLE COUNTER (Synchronized with input valid)
    // =============================================================
    reg [3:0] reg_sample_cnt;

    always @(posedge clk) begin
        if (!rst_n) 
            reg_sample_cnt <= 4'd0;
        else if (i_pucch_valid) begin
            if (reg_sample_cnt == 4'd11)
                reg_sample_cnt <= 4'd0;
            else
                reg_sample_cnt <= reg_sample_cnt + 1'b1;
        end
    end

    // =============================================================
    // 2. ROM ADDRESS CALCULATION (Optimized: u * 12 + n)
    // =============================================================
    // logic: (u << 3) + (u << 2) equals u * (8 + 4) = u * 12
    wire [8:0] w_rom_addr = (i_u_index << 3) + (i_u_index << 2) + reg_sample_cnt;

    // =============================================================
    // 3. SEQUENCE ROM INSTANTIATION (Latency = 2)
    // =============================================================
    wire [31:0] w_conj_seq;
    reg         reg_valid_d1; 

    always @(posedge clk) reg_valid_d1 <= i_pucch_valid;

    // Keep ROM enabled for one extra cycle to allow the last sample (n=11) to exit
    sequence_ROM i_sequence_rom (
        .clka  (clk),
        .ena   (i_pucch_valid | reg_valid_d1), 
        .addra (w_rom_addr), 
        .douta (w_conj_seq)
    );

    // =============================================================
    // 4. PIPELINE ALIGNMENT DELAY (Matching ROM Latency)
    // =============================================================
    reg [31:0] reg_data_d1,  reg_data_d2;
    reg        reg_valid_d2;
    reg        reg_last_d1,   reg_last_d2;

    always @(posedge clk) begin
        if (!rst_n) begin
            reg_valid_d2 <= 1'b0;
        end else begin
            // Data delay path
            reg_data_d1  <= i_pucch_data;
            reg_data_d2  <= reg_data_d1;
            
            // Valid delay path (2 cycles to match ROM dout latency)
            reg_valid_d2 <= reg_valid_d1; 
            
            // Last signal delay path
            reg_last_d1  <= i_pucch_last;
            reg_last_d2  <= reg_last_d1;
        end
    end

    // =============================================================
    // 5. COMPLEX MULTIPLIER IP (Latency = 4)
    // =============================================================
    // AXI-Stream interface ensures synchronization between data and conj_seq
    de_spread_mul i_complex_multiplier (
        .aclk                (clk),
        .aresetn             (rst_n),
        
        // Port A: Received PUCCH Data (Delayed to align with ROM)
        .s_axis_a_tdata      (reg_data_d2),
        .s_axis_a_tvalid     (reg_valid_d2),
        .s_axis_a_tlast      (reg_last_d2),
        
        // Port B: Conjugated Base Sequence from ROM
        .s_axis_b_tdata      (w_conj_seq),
        .s_axis_b_tvalid     (reg_valid_d2), 
        
        // Master Output Port
        .m_axis_dout_tdata   (o_despread_data),
        .m_axis_dout_tvalid  (o_despread_valid),
        .m_axis_dout_tlast   (o_despread_last)
    );

endmodule