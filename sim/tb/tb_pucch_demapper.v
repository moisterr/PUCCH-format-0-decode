`timescale 1ns / 1ps

module tb_de_map();

    // --- Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- Inputs to de_map ---
    reg [31:0] s_fft_real;
    reg [31:0] s_fft_imag;
    reg [11:0] s_fft_index;
    reg        s_fft_valid;
    reg [11:0] start_re_idx;

    // --- Outputs from de_map ---
    wire [15:0] m_pucch_real;
    wire [15:0] m_pucch_imag;
    wire        m_pucch_valid;
    wire        m_pucch_last;

    // --- Memory ?? ch?a 4096 m?u FFT ---
    // Gi? ??nh file txt l?u 64-bit: [63:32] là Imag, [31:0] là Real
    reg [63:0] fft_mem [0:4095];
    integer i;

    // 1. Instantiate Module de_map
    de_map uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_fft_real(s_fft_real),
        .s_fft_imag(s_fft_imag),
        .s_fft_index(s_fft_index),
        .s_fft_valid(s_fft_valid),
        .start_re_idx(start_re_idx),
        .m_pucch_real(m_pucch_real),
        .m_pucch_imag(m_pucch_imag),
        .m_pucch_valid(m_pucch_valid),
        .m_pucch_last(m_pucch_last)
    );

    // 2. T?o Clock 122.88 MHz (Kho?ng 8.138ns m?i chu k?)
    initial clk = 0;
    always #4.069 clk = ~clk;

    // 3. Ti?n trình mô ph?ng
    initial begin
        // --- Kh?i t?o ---
        rst_n = 0;
        s_fft_real = 0;
        s_fft_imag = 0;
        s_fft_index = 0;
        s_fft_valid = 0;
        start_re_idx = 12'd120; // Thi?t l?p v? trí b?t ??u là 400

        // ??c d? li?u t? file txt
        $readmemh("1_fft_out_64b.txt", fft_mem);

        #100;
        @(posedge clk); rst_n = 1;
        #50;

        $display("--- [%t] Bat dau day 4096 mau FFT vao de_map ---", $time);

        // --- B?m 4096 m?u vào module ---
        for (i = 0; i < 4096; i = i + 1) begin
            @(posedge clk);
            #2;
            s_fft_valid <= 1'b1;
            s_fft_index <= i;
            s_fft_real  <= fft_mem[i][31:0];  // 32-bit Real th?p
            s_fft_imag  <= fft_mem[i][63:32]; // 32-bit Imag cao
        end

        // K?t thúc b?m d? li?u
        @(posedge clk);
        s_fft_valid <= 1'b0;
        s_fft_index <= 0;

        #200;
        $display("--- [%t] Hoan thanh mo phong ---", $time);
        $stop;
    end

    // 4. Monitor: Theo dõi k?t qu? ??u ra
    // Chúng ta ch? quan tâm khi valid lên cao
    always @(posedge clk) begin
        if (m_pucch_valid) begin
            $display("OUT -> Real: %h | Imag: %h | Last: %b | Time: %t", 
                     m_pucch_real, m_pucch_imag, m_pucch_last, $time);
        end
    end

endmodule