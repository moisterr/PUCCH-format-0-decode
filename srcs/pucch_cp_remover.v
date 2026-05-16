`timescale 1ns / 1ps

module pucch_cp_remover #(
    parameter FFT_SIZE     = 4096,
    parameter CP_LEN_LONG  = 352,
    parameter CP_LEN_SHORT = 288
)(
    input  wire        clk, rst_n,
    input  wire [23:0] s_axis_adc_tdata,
    input  wire        s_axis_adc_tvalid,
    output wire        s_axis_adc_tready,
    input  wire [3:0]  i_symbol_idx,
    output reg  [31:0] m_axis_fft_tdata,
    output reg         m_axis_fft_tvalid,
    output reg         m_axis_fft_tlast,
    input  wire        m_axis_fft_tready
);
    localparam CP_BOUNDARY_LONG   = CP_LEN_LONG  - 1;
    localparam CP_BOUNDARY_SHORT  = CP_LEN_SHORT - 1;
    localparam FULL_BOUNDARY_LONG  = CP_LEN_LONG  + FFT_SIZE - 1;
    localparam FULL_BOUNDARY_SHORT = CP_LEN_SHORT + FFT_SIZE - 1;

    // --- Config registers v?i reset ---
    reg [13:0] cfg_cp_end;
    reg [13:0] cfg_sym_end;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_cp_end  <= CP_BOUNDARY_LONG;    // default symbol 0
            cfg_sym_end <= FULL_BOUNDARY_LONG;
        end else begin
            if (i_symbol_idx == 4'd0) begin
                cfg_cp_end  <= CP_BOUNDARY_LONG;
                cfg_sym_end <= FULL_BOUNDARY_LONG;
            end else begin
                cfg_cp_end  <= CP_BOUNDARY_SHORT;
                cfg_sym_end <= FULL_BOUNDARY_SHORT;
            end
        end
    end

    // --- Counter & Window ---
    reg [13:0] sample_cnt;
    reg        is_fft_window;

    wire transfer_en = s_axis_adc_tvalid && m_axis_fft_tready;

    // Combinational: last sample c?a symbol
    wire is_last_sample = is_fft_window && (sample_cnt == cfg_sym_end);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt    <= 14'd0;
            is_fft_window <= 1'b0;
        end else if (transfer_en) begin
            if (sample_cnt == cfg_sym_end) begin
                sample_cnt    <= 14'd0;
                is_fft_window <= 1'b0;
            end else begin
                sample_cnt <= sample_cnt + 1;
                if (sample_cnt == cfg_cp_end)
                    is_fft_window <= 1'b1;
            end
        end
    end

    // --- Pipeline Stage 1 ---
    reg [31:0] data_map_pipe;
    reg        valid_pipe, last_pipe;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe    <= 1'b0;
            last_pipe     <= 1'b0;
            data_map_pipe <= 32'd0;
        end else if (m_axis_fft_tready) begin
            valid_pipe    <= s_axis_adc_tvalid && is_fft_window;
            last_pipe     <= s_axis_adc_tvalid && is_last_sample;
            data_map_pipe <= {{s_axis_adc_tdata[23:12], 4'b0},
                              {s_axis_adc_tdata[11:0],  4'b0}};
        end
    end

    // --- Pipeline Stage 2 ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_fft_tvalid <= 1'b0;
            m_axis_fft_tlast  <= 1'b0;
            m_axis_fft_tdata  <= 32'd0;
        end else if (m_axis_fft_tready) begin
            m_axis_fft_tvalid <= valid_pipe;
            m_axis_fft_tlast  <= last_pipe;
            m_axis_fft_tdata  <= data_map_pipe;
        end
    end

    assign s_axis_adc_tready = m_axis_fft_tready;

endmodule