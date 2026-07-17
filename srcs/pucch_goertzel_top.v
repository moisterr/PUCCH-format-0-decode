`timescale 1ns / 1ps

module pucch_goertzel_top (
    input  wire        clk,
    input  wire        rst_n,

    // ----------------------------------------------------
    // Configuration Interface (Receives commands from MAC/Testbench)
    // ----------------------------------------------------
    input  wire [11:0] i_start_idx,    // Starting RE index (e.g., 120)
    input  wire        i_config_valid, // Trigger pulse to load new configuration
    output reg         o_ready,        // Flag indicating coefficients are fully loaded

    // ----------------------------------------------------
    // AXI-Stream Input (Receives 4096 data samples from CP Remover)
    // ----------------------------------------------------
    input  wire [31:0] s_axis_tdata,   // {Imag[15:0], Real[15:0]}
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,

    // ----------------------------------------------------
    // AXI-Stream Output (Pushes 12 RE samples to Despreader)
    // ----------------------------------------------------
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast
);

    // =========================================================
    // 1. INTERFACE WITH 3 ROM IPs (Latency = 2)
    // =========================================================
    reg  [11:0] rom_addr;
    wire [15:0] rom_dout_c2;
    wire [15:0] rom_dout_c;
    wire [15:0] rom_dout_s;

    rom_c2_ip u_rom_c2 (.clka(clk), .addra(rom_addr), .douta(rom_dout_c2));
    rom_c_ip  u_rom_c  (.clka(clk), .addra(rom_addr), .douta(rom_dout_c));
    rom_s_ip  u_rom_s  (.clka(clk), .addra(rom_addr), .douta(rom_dout_s));

    // =========================================================
    // 2. COEFFICIENT LOADING PIPELINE 
    // =========================================================
    reg signed [15:0] reg_c2 [0:11];
    reg signed [15:0] reg_c  [0:11];
    reg signed [15:0] reg_s  [0:11];

    reg [3:0] read_cnt;
    reg       is_loading;
    reg [2:0] pipe_valid; // 3-bit shift register to account for ROM read latency
    reg [3:0] write_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rom_addr    <= 0;
            read_cnt    <= 0;
            is_loading  <= 0;
            pipe_valid  <= 3'b000;
            write_idx   <= 0;
            o_ready     <= 0;
        end else begin
            // --- PART A: BURST ADDRESS GENERATOR ---
            if (i_config_valid) begin
                rom_addr    <= i_start_idx;
                read_cnt    <= 1;
                is_loading  <= 1;
                o_ready     <= 0;
                pipe_valid  <= 3'b100; // Inject first trigger into 3-bit shift pipeline
            end else if (is_loading) begin
                rom_addr    <= rom_addr + 1;
                pipe_valid  <= {1'b1, pipe_valid[2:1]}; // Shift the Valid stream
                
                if (read_cnt == 12) begin
                    is_loading <= 0; 
                end else begin
                    read_cnt   <= read_cnt + 1;
                end
            end else begin
                pipe_valid  <= {1'b0, pipe_valid[2:1]}; // Flush remaining pipeline
            end

            // --- PART B: CAPTURE OUTPUT DATA (WITH LATCH LOCK) ---
            if (pipe_valid[0] && !o_ready) begin
                reg_c2[write_idx] <= rom_dout_c2;
                reg_c [write_idx] <= rom_dout_c;
                reg_s [write_idx] <= rom_dout_s;
                
                if (write_idx == 11) begin
                    // Lock the counter at index 11, prevent wrap-around to 0
                    // This prevents the Pipeline Flush from overwriting with garbage data
                    o_ready   <= 1'b1; 
                end else begin
                    write_idx <= write_idx + 1;
                end
            end else if (i_config_valid) begin
                write_idx <= 0; // Only unlock and reset counter on new config command
            end
        end
    end

    // =========================================================
    // 3. INSTANTIATE 12 PARALLEL GOERTZEL BRANCHES
    // =========================================================
    wire signed [15:0] w_res_re [0:11];
    wire signed [15:0] w_res_im [0:11];
    wire [11:0]        w_valid;

    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : gen_goertzel
            pucch_goertzel_branch u_branch (
                .clk(clk),
                .rst_n(rst_n),
                .i_data_re(s_axis_tdata[15:0]),
                .i_data_im(s_axis_tdata[31:16]),
                .i_valid  (s_axis_tvalid && o_ready), 
                .i_last   (s_axis_tlast),
                .i_c2(reg_c2[i]),
                .i_c (reg_c[i]),
                .i_s (reg_s[i]),
                .o_res_re(w_res_re[i]),
                .o_res_im(w_res_im[i]),
                .o_valid (w_valid[i])
            );
        end
    endgenerate

    // =========================================================
    // 4. SERIALIZER STATE MACHINE (Queues results for output)
    // =========================================================
    reg [3:0] out_idx;
    reg       out_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_busy      <= 0;
            out_idx       <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= 0;
        end else begin
            // Trigger serialization when the first branch completes
            if (w_valid[0] && !out_busy) begin
                out_busy <= 1;
                out_idx  <= 0;
            end

            if (out_busy) begin
                m_axis_tdata  <= {w_res_im[out_idx], w_res_re[out_idx]};
                m_axis_tvalid <= 1'b1;
                
                if (out_idx == 11) begin
                    m_axis_tlast <= 1'b1; 
                    out_busy     <= 1'b0; 
                end else begin
                    m_axis_tlast <= 1'b0;
                    out_idx      <= out_idx + 1;
                end
            end else begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end
        end
    end

endmodule
