`timescale 1ns / 1ps

/**
 * Module: pucch_twiddle_fetcher
 * Description: Fetches 12 sets of twiddle factors from ROM at startup.
 * Each set is 384-bit wide. Handles 2-cycle ROM latency.
 */

module pucch_twiddle_fetcher (
    input  wire          clk,
    input  wire          rst_n,
    
    // ROM Interface
    input  wire [383:0]  i_rom_dout,
    output reg  [3:0]    o_rom_addr,
    
    // Status and Data Output
    output reg           o_fetch_done,
    output wire [4607:0] o_twid_bank_bus
);

    // --- Internal Registers ---
    reg [3:0]   reg_fetch_cnt;
    reg [3:0]   reg_addr_dly1, reg_addr_dly2;
    reg [383:0] reg_twid_bank [0:11];

    // --- Fetch Logic with 2-cycle Latency Management ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rom_addr    <= 4'd0;
            reg_fetch_cnt <= 4'd0;
            o_fetch_done  <= 1'b0;
            reg_addr_dly1 <= 4'd0;
            reg_addr_dly2 <= 4'd0;
        end else if (!o_fetch_done) begin
            // 1. Address Generation (Max index 11)
            if (o_rom_addr < 4'd11) 
                o_rom_addr <= o_rom_addr + 4'd1;
            else 
                o_rom_addr <= 4'd11;

            // 2. Latency Pipeline (Matches 2-cycle BRAM delay)
            reg_addr_dly1 <= o_rom_addr;
            reg_addr_dly2 <= reg_addr_dly1;

            // 3. Data Capture
            // We start capturing once the address delay pipeline is full (after 2 cycles)
            if (reg_fetch_cnt < 4'd12) begin
                // Condition to wait for the first valid data from ROM
                if (o_rom_addr >= 4'd2 || reg_addr_dly2 > 0) begin
                    reg_twid_bank[reg_fetch_cnt] <= i_rom_dout;
                    reg_fetch_cnt <= reg_fetch_cnt + 4'd1;
                    
                    // Completion check
                    if (reg_fetch_cnt == 4'd11) 
                        o_fetch_done <= 1'b1;
                end
            end
        end
    end

    // --- Output Flattening (Register Bank to Bus) ---
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : gen_twid_flatten
            assign o_twid_bank_bus[i*384 +: 384] = reg_twid_bank[i];
        end
    endgenerate

endmodule