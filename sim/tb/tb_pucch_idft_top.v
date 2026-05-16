`timescale 1ns / 1ps

module tb_idft_12p();

    // --- 1. Khai báo tín hi?u ---
    reg clk;
    reg rst_n;
    reg [31:0] s_axis_data;
    reg s_axis_valid;
    reg s_axis_last;
    
    wire m_axis_valid;
    wire [191:0] pwr_all_bus;

    // M?ng ?? soi 12 k?t qu? biên ?? ngay trên Waveform
    wire [15:0] mag_result [0:11];

    // --- 2. N?p d? li?u De-spread c?a Vat vào m?ng ---
    reg [31:0] de_spread_samples [0:11];

    // --- 3. K?t n?i m?ng mag_result vào bus 192-bit ---
    genvar k;
    generate
        for (k = 0; k < 12; k = k + 1) begin : unflatten_bus
            assign mag_result[k] = pwr_all_bus[k*16 +: 16];
        end
    endgenerate

    // --- 4. Kh?i t?o Module UUT ---
    idft_12p_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_data(s_axis_data),
        .s_axis_valid(s_axis_valid),
        .s_axis_last(s_axis_last),
        .m_axis_valid(m_axis_valid),
        .pwr_all_bus(pwr_all_bus)
    );

    // --- 5. T?o Clock 122.88 MHz (~8.138 ns) ---
    initial clk = 0;
    always #4.069 clk = ~clk;

    // --- 6. K?ch b?n mô ph?ng ---
    initial begin
        // Kh?i t?o giá tr? ban ??u
        rst_n = 0;
        s_axis_data = 32'd0;
        s_axis_valid = 1'b0;
        s_axis_last = 1'b0;

        // Gán d? li?u de-spread c?a Vat
        de_spread_samples[0]  = 32'hFFFC1FF3;
        de_spread_samples[1]  = 32'h0FFA1BAC;
        de_spread_samples[2]  = 32'h1BAC0FFB;
        de_spread_samples[3]  = 32'h1FF1FFFD;
        de_spread_samples[4]  = 32'h1BAEF004;
        de_spread_samples[5]  = 32'h0FF6E451;
        de_spread_samples[6]  = 32'hFFFDE00F;
        de_spread_samples[7]  = 32'hF006E453;
        de_spread_samples[8]  = 32'hE455F005;
        de_spread_samples[9]  = 32'hE00AFFFE;
        de_spread_samples[10] = 32'hE4520FF9;
        de_spread_samples[11] = 32'hF0051BAC;

        // Reset h? th?ng
        #100;
        @(negedge clk);
        rst_n = 1;

        // ??i kh?i fetch_unit n?p xong Twiddle Factor t? ROM (R?t quan tr?ng!)
        wait(uut.fetch_done == 1'b1);
        repeat(10) @(posedge clk);

        // --- B?t ??u b?m 12 m?u vào IDFT ---
        $display("--- [%t] START: Bom 12 mau De-spread vao IDFT ---", $time);
        
        for (integer i = 0; i < 12; i = i + 1) begin
            @(posedge clk);
            #2; // Tr? nh? ?? né c?nh clock (an toàn cho Post-Impl Sim)
            s_axis_data  <= de_spread_samples[i];
            s_axis_valid <= 1'b1;
            s_axis_last  <= (i == 11); // B?t last ? m?u cu?i cùng
        end

        // K?t thúc b?m d? li?u
        @(posedge clk);
        #2;
        s_axis_valid <= 1'b0;
        s_axis_last  <= 1'b0;

        // --- ??i k?t qu? ??u ra ---
        wait(m_axis_valid == 1'b1);
        #1; // ??i tín hi?u ?n ??nh
        
        $display("\n=================================================");
        $display("   KET QUA BIEN DO (MAGNITUDE) SAU IDFT");
        $display("=================================================");
        for (integer i = 0; i < 12; i = i + 1) begin
            $display(" Sample [%0d] | Mag = %d (Hex: %h)", i, mag_result[i], mag_result[i]);
        end
        $display("=================================================\n");

        #200;
        $display("--- [%t] SUCCESS: Da kiem tra xong module IDFT! ---", $time);
        $stop;
    end

endmodule