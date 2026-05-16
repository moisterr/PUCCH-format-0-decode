`timescale 1ns / 1ps

module tb_peak_detector();

    // --- Tín hi?u ?i?u khi?n ---
    reg clk;
    reg rst_n;
    reg [767:0] pwr_all_bus;
    reg valid_in;
    reg [3:0] alpha_shift;

    // --- Tín hi?u ??u ra ---
    wire [3:0] peak_index;
    wire peak_valid;
    wire done;

    // --- M?ng n?i b? ?? n?p d? li?u cho d? ---
    reg [63:0] pwr_test [0:11];

    // 1. Instantiate Module
    peak_detector uut (
        .clk(clk),
        .rst_n(rst_n),
        .pwr_all_bus(pwr_all_bus),
        .valid_in(valid_in),
        .alpha_shift(alpha_shift),
        .peak_index(peak_index),
        .peak_valid(peak_valid),
        .done(done)
    );

    // 2. T?o Clock (100MHz)
    initial clk = 0;
    always #4.069 clk = ~clk;

    // 3. Logic ghép m?ng vào bus 768-bit
    integer k;
    always @(*) begin
        for (k = 0; k < 12; k = k + 1) begin
            pwr_all_bus[k*64 +: 64] = pwr_test[k];
        end
    end

    // 4. K?ch b?n mô ph?ng
    initial begin
        // --- Giai ?o?n 1: Kh?i t?o ---
        rst_n = 0;
        valid_in = 0;
        alpha_shift = 4'd3; // alpha = 2^3 = 8 (C?u hình SNR khá cao)
        
        // N?p d? li?u t? b?ng MATLAB c?a b?n
        pwr_test[0]  = 64'd356;
        pwr_test[1]  = 64'd9635474697; // PEAK t?i n=1
        pwr_test[2]  = 64'd223;
        pwr_test[3]  = 64'd106;
        pwr_test[4]  = 64'd99;
        pwr_test[5]  = 64'd119;
        pwr_test[6]  = 64'd80;
        pwr_test[7]  = 64'd81;
        pwr_test[8]  = 64'd126;
        pwr_test[9]  = 64'd34;
        pwr_test[10] = 64'd2;
        pwr_test[11] = 64'd5;

        #100 rst_n = 1;
        #20;

        // --- Giai ?o?n 2: Test tr??ng h?p có tín hi?u (Normal) ---
        @(posedge clk);
        valid_in <= 1'b1;
        @(posedge clk);
        valid_in <= 1'b0;

        wait(done);
        $display("--- CASE 1: CO TIN HIEU ---");
        $display("Peak Index: %d (Ky vong: 1)", peak_index);
        $display("Peak Valid: %b (Ky vong: 1)", peak_valid);

        #200;

        // --- Giai ?o?n 3: Test tr??ng h?p nhi?u tr?ng (DTX) ---
        // Gi? s? UE không g?i gì, toàn b? 12 v? trí ??u là nhi?u x?p x? nhau
        for (integer i = 0; i < 12; i = i + 1) begin
            pwr_test[i] = 64'd500 + ($random % 100); 
        end

        @(posedge clk);
        valid_in <= 1'b1;
        @(posedge clk);
        valid_in <= 1'b0;

        wait(done);
        $display("--- CASE 2: NHIEU TRANG (DTX) ---");
        $display("Peak Valid: %b (Ky vong: 0)", peak_valid);

        #100;
        $finish;
    end

endmodule