`timescale 1ns / 1ps

/**
 * Module: pucch_fft_wrapper
 * Description: Wrapper for Xilinx FFT IP Core (4096-point). 
 * Handles one-time configuration and provides registered AXI-Stream outputs.
 */

module pucch_fft_wrapper (
    input  wire        clk,
    input  wire        rst_n,
    
    // Slave AXI-Stream (From CP Remover)
    input  wire [31:0] s_axis_data_tdata,
    input  wire        s_axis_data_tvalid,
    output wire        s_axis_data_tready,
    input  wire        s_axis_data_tlast,
    
    // Master Interface (To De-mapper)
    output wire [31:0] o_fft_real,
    output wire [31:0] o_fft_imag,
    output wire [11:0] o_fft_index,
    output wire        o_fft_valid,
    output wire        o_fft_last,
    input  wire        i_fft_ready
);

    // --- 1. FFT Configuration Logic (Static Setup) ---
    // FFT IP Core requires configuration (e.g., FWD/INV, Scaling) via S_AXIS_CONFIG
    reg        cfg_valid;
    reg        cfg_done;
    wire       cfg_ready;
    localparam CFG_DATA = 8'h01; // Forward FFT, No scaling (typical for NR)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_valid <= 1'b0;
            cfg_done  <= 1'b0;
        end else if (!cfg_done) begin
            cfg_valid <= 1'b1;
            if (cfg_valid && cfg_ready) begin
                cfg_valid <= 1'b0;
                cfg_done  <= 1'b1;
            end
        end
    end

    // --- 2. Internal Signals ---
    wire [63:0] m_axis_data_tdata_int;
    wire [15:0] m_axis_data_tuser_int; 
    wire        m_axis_data_tvalid_int;
    wire        m_axis_data_tlast_int;
    wire        m_axis_data_tready_int;

    // --- 3. Instantiate Xilinx FFT IP Core ---
    // Note: Ensure the IP name matches your generated IP core name (FFT_4096)
    FFT_4096 i_fft_core (
        .aclk(clk),
        .aresetn(rst_n),
        
        // Configuration Channel
        .s_axis_config_tdata(CFG_DATA),
        .s_axis_config_tvalid(cfg_valid),
        .s_axis_config_tready(cfg_ready),
        
        // Data Input Channel (Slave)
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),
        .s_axis_data_tlast(s_axis_data_tlast),
        
        // Data Output Channel (Master)
        .m_axis_data_tdata(m_axis_data_tdata_int),
        .m_axis_data_tuser(m_axis_data_tuser_int), // Contains frequency index
        .m_axis_data_tvalid(m_axis_data_tvalid_int),
        .m_axis_data_tready(m_axis_data_tready_int),
        .m_axis_data_tlast(m_axis_data_tlast_int)
    );

    // --- 4. Output Pipeline Stage (High Performance Timing) ---
    reg [63:0] reg_m_data;
    reg [11:0] reg_m_index;
    reg        reg_m_valid;
    reg        reg_m_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_m_data  <= 64'd0;
            reg_m_index <= 12'd0;
            reg_m_valid <= 1'b0;
            reg_m_last  <= 1'b0;
        end else if (i_fft_ready) begin 
            reg_m_data  <= m_axis_data_tdata_int;
            reg_m_index <= m_axis_data_tuser_int[11:0]; 
            reg_m_valid <= m_axis_data_tvalid_int;
            reg_m_last  <= m_axis_data_tlast_int;
        end
    end

    // Back-pressure pass-through
    assign m_axis_data_tready_int = i_fft_ready;

    // --- 5. Output Assignment ---
    assign o_fft_real  = reg_m_data[31:0];
    assign o_fft_imag  = reg_m_data[63:32];
    assign o_fft_index = reg_m_index;
    assign o_fft_valid = reg_m_valid;
    assign o_fft_last  = reg_m_last;

endmodule