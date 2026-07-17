`timescale 1ns / 1ps

module pucch_goertzel_branch (
    input  wire clk,
    input  wire rst_n,

    input  wire signed [15:0] i_data_re,
    input  wire signed [15:0] i_data_im,
    input  wire               i_valid,
    input  wire               i_last,     

    input  wire signed [15:0] i_c2,       // Q2.14 (2*cos)
    input  wire signed [15:0] i_c,        // Q1.15 (cos)
    input  wire signed [15:0] i_s,        // Q1.15 (sin)

    output reg  signed [15:0] o_res_re,
    output reg  signed [15:0] o_res_im,
    output reg                o_valid
);

    // =========================================================================
    // STAGE 0: INPUT PIPELINE (Isolates routing delay from external modules)
    // =========================================================================
    reg signed [31:0] stg0_data_re, stg0_data_im;
    reg signed [15:0] stg0_c2, stg0_c, stg0_s;
    reg               stg0_valid, stg0_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg0_data_re <= 0; 
            stg0_data_im <= 0;
            stg0_c2      <= 0; 
            stg0_c       <= 0; 
            stg0_s       <= 0;
            stg0_valid   <= 0; 
            stg0_last    <= 0;
        end else begin
            stg0_data_re <= {{16{i_data_re[15]}}, i_data_re}; // Sign extension
            stg0_data_im <= {{16{i_data_im[15]}}, i_data_im};
            stg0_c2      <= i_c2;
            stg0_c       <= i_c;
            stg0_s       <= i_s;
            stg0_valid   <= i_valid;
            stg0_last    <= i_last;
        end
    end

    // Flag indicating the first sample of a new symbol (Back-to-back processing)
    reg first_sample;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            first_sample <= 1'b1;
        else if (stg0_valid && stg0_last) 
            first_sample <= 1'b1;
        else if (stg0_valid) 
            first_sample <= 1'b0;
    end

    // =========================================================================
    // STAGE 1: CORE IIR FILTER (Optimized for 100% DSP48 inference)
    // =========================================================================
    reg signed [47:0] mac_p_re, mac_p_im; // Equivalent to PREG (DSP output register)
    reg signed [31:0] s2_re, s2_im;       // Sample s1[n-1]

    // MUX to inject zero for the first sample (Removes reset logic delay)
    wire signed [31:0] s1_re_comb = first_sample ? 32'd0 : (mac_p_re >>> 14);
    wire signed [31:0] s1_im_comb = first_sample ? 32'd0 : (mac_p_im >>> 14);
    wire signed [31:0] s2_re_comb = first_sample ? 32'd0 : s2_re;
    wire signed [31:0] s2_im_comb = first_sample ? 32'd0 : s2_im;

    // C-port arithmetic (Uses high-speed LUT Adder)
    wire signed [32:0] sub_re = stg0_data_re - s2_re_comb;
    wire signed [32:0] sub_im = stg0_data_im - s2_im_comb;

    // ZERO-DELAY HACK: Shift by 14 and add 8192 using wire concatenation { }
    wire signed [47:0] c_port_re = { sub_re[32], sub_re[32:0], 1'b1, 13'd0 };
    wire signed [47:0] c_port_im = { sub_im[32], sub_im[32:0], 1'b1, 13'd0 };

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mac_p_re <= 0; 
            mac_p_im <= 0;
            s2_re    <= 0; 
            s2_im    <= 0;
        end else if (stg0_valid) begin
            // Sample delay registers
            s2_re <= s1_re_comb;
            s2_im <= s1_im_comb;
            
            // FORCE DSP SYNTHESIS: Vivado will infer this entirely into a DSP MAC block
            mac_p_re <= (s1_re_comb * stg0_c2) + c_port_re;
            mac_p_im <= (s1_im_comb * stg0_c2) + c_port_im;
        end
    end

    // =========================================================================
    // STAGE 2: CAPTURE FINAL RESULT
    // =========================================================================
    reg capture_flag;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            capture_flag <= 1'b0;
        else 
            capture_flag <= (stg0_valid && stg0_last); 
    end

    reg signed [31:0] cap_s1_re, cap_s1_im;
    reg signed [31:0] cap_s2_re, cap_s2_im;
    reg               cap_valid;

    always @(posedge clk) begin
        if (capture_flag) begin
            cap_s1_re <= mac_p_re >>> 14;  // This is s1[N]
            cap_s1_im <= mac_p_im >>> 14;
            cap_s2_re <= s2_re;            // This is s1[N-1]
            cap_s2_im <= s2_im;
            cap_valid <= 1'b1;
        end else begin
            cap_valid <= 1'b0;
        end
    end

    // =========================================================================
    // STAGE 3: OUTPUT COEFFICIENT MULTIPLICATION (PIPELINED MULTIPLIERS)
    // =========================================================================
    reg signed [47:0] m_c_re, m_c_im, m_s_re, m_s_im;
    reg signed [31:0] p2_s2_re, p2_s2_im;
    reg               stg3_valid;

    always @(posedge clk) begin
        if (cap_valid) begin
            m_c_re     <= cap_s1_re * stg0_c;
            m_c_im     <= cap_s1_im * stg0_c;
            m_s_re     <= cap_s1_re * stg0_s;
            m_s_im     <= cap_s1_im * stg0_s;
            p2_s2_re   <= cap_s2_re;
            p2_s2_im   <= cap_s2_im;
            stg3_valid <= 1'b1;
        end else begin
            stg3_valid <= 1'b0;
        end
    end

    // =========================================================================
    // STAGE 4: ADDITION/SUBTRACTION AND OUTPUT ROUNDING
    // =========================================================================
    
    // Rounding and shifting back to appropriate Q format
    wire signed [31:0] rounded_c_re = (m_c_re + 48'sd16384) >>> 15; 
    wire signed [31:0] rounded_c_im = (m_c_im + 48'sd16384) >>> 15;
    wire signed [31:0] rounded_s_re = (m_s_re + 48'sd16384) >>> 15;
    wire signed [31:0] rounded_s_im = (m_s_im + 48'sd16384) >>> 15;

    wire signed [31:0] final_re = rounded_c_re - rounded_s_im - p2_s2_re;
    wire signed [31:0] final_im = rounded_s_re + rounded_c_im - p2_s2_im;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_res_re <= 0;
            o_res_im <= 0;
            o_valid  <= 0;
        end else begin
            if (stg3_valid) begin
                o_res_re <= final_re[23:8]; 
                o_res_im <= final_im[23:8];
                o_valid  <= 1'b1;
            end else begin
                o_valid  <= 1'b0;
            end
        end
    end

endmodule
