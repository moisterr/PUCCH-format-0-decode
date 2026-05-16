`timescale 1ns / 1ps

module tb_de_spread();

    // --- Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- Inputs to de_spread ---
    reg [31:0] s_fft_data;
    reg        s_fft_valid;
    reg        s_fft_last;
    reg [4:0]  u_index;

    // --- Outputs from de_spread ---
    wire [31:0] m_data_out;
    wire        m_valid_out;
    wire        m_last_out;

    // --- Memory ch?a 12 m?u ??u vào ---
    reg [31:0] input_mem [0:11];
    integer i;

    // 1. Instantiate Module de_spread
    de_spread uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_fft_data(s_fft_data),
        .s_fft_valid(s_fft_valid),
        .s_fft_last(s_fft_last),
        .u_index(u_index),
        .m_data_out(m_data_out),
        .m_valid_out(m_valid_out),
        .m_last_out(m_last_out)
    );

    // 2. T?o Clock 122.88 MHz (~8.138ns m?i chu k?)
    initial clk = 0;
    always #4.069 clk = ~clk;

    // 3. Ti?n trình mô ph?ng
    initial begin
        // --- Kh?i t?o ---
        rst_n = 0;
        s_fft_data = 0;
        s_fft_valid = 0;
        s_fft_last = 0;
        u_index = 5'd0; // Thi?t l?p u = 7 t??ng ?ng v?i b? d? li?u b?n g?i

        // ??c d? li?u t? file txt
        $readmemh("2_recovered_comparison_32b.txt", input_mem);

        #100;
        @(posedge clk); rst_n = 1;
        #50;

        $display("--- [%t] Bat dau day 12 mau vao de_spread ---", $time);

        // --- B?m 12 m?u vào module ---
        for (i = 0; i < 12; i = i + 1) begin
            @(posedge clk);
            #2; // Delay nh? ?? ?n ??nh tín hi?u sau c?nh clock
            s_fft_valid <= 1'b1;
            s_fft_data  <= input_mem[i];
            s_fft_last  <= (i == 11) ? 1'b1 : 1'b0;
        end

        // K?t thúc b?m d? li?u
        @(posedge clk);
        #2;
        s_fft_valid <= 1'b0;
        s_fft_last  <= 1'b0;

        // ??i thêm m?t kho?ng th?i gian ?? d? li?u ch?y qua b? nhân (latency ~6 nh?p)
        #200; 
        $display("--- [%t] Hoan thanh mo phong ---", $time);
        $finish; // S? d?ng $stop ?? Vivado d?ng l?i ? ?ây, không ch?y mãi mãi
    end

    // 4. Monitor: Theo dõi k?t qu? ??u ra
    always @(posedge clk) begin
        if (m_valid_out) begin
            $display("OUT -> Hex: %h | Last: %b | Time: %t", 
                     m_data_out, m_last_out, $time);
        end
    end

endmodule