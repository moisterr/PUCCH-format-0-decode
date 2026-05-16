`timescale 1ns / 1ps

/**
 * Module: pucch_idft_top
 * Description: 12-point IDFT core for PUCCH Format 0. 
 * Features parallel branch processing and Alpha-max plus Beta-min magnitude estimation.
 */

module pucch_idft_top (
    input  wire          clk,
    input  wire          rst_n,
    
    // Slave AXI-Stream (From De-spreader)
    input  wire [31:0]   s_axis_data,
    input  wire          s_axis_valid,
    input  wire          s_axis_last,
    
    // Master Interface
    output reg           o_idft_valid,
    output reg  [191:0]  o_pwr_all_bus 
);

    // --- Internal Signals ---
    wire [3:0]    w_rom_addr;
    wire [383:0]  w_rom_dout;
    wire          w_fetch_done;
    wire [4607:0] w_twid_bank_flat;
    
    reg  [3:0]    reg_k_cnt;
    reg  [3:0]    reg_k_cnt_delayed;
    reg  [31:0]   reg_twid_coeff [0:11];

    wire [15:0]   w_res_real [0:11];
    wire [15:0]   w_res_imag [0:11];
    wire [15:0]   w_mag_wire [0:11];

    integer i;

    // --- 1. Twiddle Coefficient Selection Stage (1 Cycle) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<12; i=i+1) reg_twid_coeff[i] <= 32'd0;
            reg_k_cnt_delayed <= 4'd0;
        end else if (s_axis_valid && w_fetch_done) begin
            reg_k_cnt_delayed <= reg_k_cnt;
            for (i=0; i<12; i=i+1) begin
                // Slicing the 4608-bit bus into 12 segments of 32-bit based on k_cnt
                reg_twid_coeff[i] <= w_twid_bank_flat[(i*384 + reg_k_cnt*32) +: 32];
            end
        end
    end

    // --- 2. Twiddle Fetcher & ROM ---
    // Note: Assuming your ROM IP is named pucch_twiddle_rom
    twiddle_ROM i_rom (
        .clka  (clk),
        .addra (w_rom_addr),
        .douta (w_rom_dout)
    );

    pucch_twiddle_fetcher i_fetcher (
        .clk             (clk),
        .rst_n           (rst_n),
        .i_rom_dout      (w_rom_dout),
        .o_rom_addr      (w_rom_addr),
        .o_fetch_done    (w_fetch_done),
        .o_twid_bank_bus (w_twid_bank_flat)
    );

    // --- 3. Parallel IDFT Branches Processing ---
    genvar n;
    generate
        for (n = 0; n < 12; n = n + 1) begin : gen_idft_engine
            pucch_idft_branch i_branch (
                .clk           (clk),
                .rst_n         (rst_n),
                .i_sample_data (s_axis_data),
                .i_twid_coeff  (reg_twid_coeff[n]), 
                .i_en          (s_axis_valid && w_fetch_done),
                .i_clr         (reg_k_cnt_delayed == 4'd0), // Clear at the start of new symbol
                .o_res_real    (w_res_real[n]),
                .o_res_imag    (w_res_imag[n])
            );

            // Magnitude Estimation: Alpha-max + Beta-min algorithm
            // Approx: Mag = max(|R|, |I|) + 1/4 * min(|R|, |I|)
            wire [15:0] abs_r = (w_res_real[n][15]) ? (~w_res_real[n] + 1'b1) : w_res_real[n];
            wire [15:0] abs_i = (w_res_imag[n][15]) ? (~w_res_imag[n] + 1'b1) : w_res_imag[n];
            
            wire [15:0] max_v = (abs_r > abs_i) ? abs_r : abs_i;
            wire [15:0] min_v = (abs_r > abs_i) ? abs_i : abs_r;

            assign w_mag_wire[n] = max_v + (min_v >> 2);
        end
    endgenerate

    // --- 4. Final Output Latching (1 Cycle) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_pwr_all_bus <= 192'd0;
        end else begin
            for (i = 0; i < 12; i = i + 1) begin
                o_pwr_all_bus[i*16 +: 16] <= w_mag_wire[i];
            end
        end
    end

    // --- 5. Control Logic & Valid Pipeline (4 Cycles Total Delay) ---
    // Latency: 1 (Coeff Reg) + 2 (Branch Pipeline) + 1 (Magnitude Latch) = 4
    reg [3:0] reg_valid_pipe; 
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_k_cnt      <= 4'd0;
            reg_valid_pipe <= 4'b0;
            o_idft_valid   <= 1'b0;
        end else begin
            // Sample Counter
            if (s_axis_valid && w_fetch_done)
                reg_k_cnt <= (s_axis_last) ? 4'd0 : reg_k_cnt + 1;

            // Shift register to align o_idft_valid with latched data
            reg_valid_pipe <= {reg_valid_pipe[2:0], (s_axis_valid && s_axis_last)};
            o_idft_valid   <= reg_valid_pipe[3];
        end
    end

endmodule