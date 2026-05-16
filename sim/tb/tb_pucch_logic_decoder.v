`timescale 1ns / 1ps

module tb_logic_decode();

    reg clk;
    reg rst_n;
    reg [3:0] peak_index;
    reg       is_signal;
    reg       done;
    reg [3:0] n_cs;
    reg [3:0] m0;
    reg       is_2bit_mode;
    reg       sr_present;
    
    wire       dtx;
    wire [1:0] decoded_bits;
    wire       out_valid;

    // Kh?i t?o UUT
    logic_decode uut (
        .clk(clk), .rst_n(rst_n),
        .peak_index(peak_index), .is_signal(is_signal), .done(done),
        .n_cs(n_cs), .m0(m0), .is_2bit_mode(is_2bit_mode), .sr_present(sr_present),
        .dtx(dtx), .decoded_bits(decoded_bits), .out_valid(out_valid)
    );

    // Clock 100MHz
    always #5 clk = ~clk;

    // Task apply_test c?i ti?n
    task apply_test(
        input [3:0] t_peak, input [3:0] t_ncs, input [3:0] t_m0,
        input t_signal, input t_2bit, input t_sr
    );
    begin
        @(negedge clk);
        peak_index = t_peak; n_cs = t_ncs; m0 = t_m0;
        is_signal = t_signal; is_2bit_mode = t_2bit; sr_present = t_sr;
        done = 1'b1;
        @(negedge clk);
        done = 1'b0;
        
        // ??i tín hi?u out_valid m?t cách an toàn
        wait(out_valid == 1'b1); 
        #1; // ??i 1ns ?? d? li?u dtx/decoded_bits ?n ??nh h?n
        $display("[Time %0t] Peak:%d, NCS:%d, M0:%d | Signal:%b, Mode:%0dB, SR:%b => DTX:%b, Bits:%b", 
                 $time, peak_index, n_cs, m0, is_signal, (is_2bit_mode?2:1), sr_present, dtx, decoded_bits);
        @(negedge clk);
    end
    endtask

    initial begin
        // Kh?i t?o ban ??u
        clk = 0; rst_n = 0; done = 0;
        peak_index = 0; n_cs = 0; m0 = 0;
        is_2bit_mode = 0; sr_present = 0; is_signal = 0;

        $display("--- BAT DAU SIMULATION ---");
        #100 rst_n = 1; // Gi?i phóng Reset
        #20;

        // CASE 1: Testcase c?a Vat (Peak=1, NCS=4, M0=3) -> m_cs = 6 (ACK)
        apply_test(4'd1, 4'd4, 4'd3, 1'b1, 1'b0, 1'b0);

        // CASE 2: 1-bit mode, SR present (mcs=0) -> Bits=01
        apply_test(4'd0, 4'd0, 4'd0, 1'b1, 1'b0, 1'b1);

        // CASE 3: 2-bit mode, No SR (mcs=3) -> Bits=01
        apply_test(4'd3, 4'd0, 4'd0, 1'b1, 1'b1, 1'b0);

        // CASE 4: 2-bit mode, SR present (mcs=3) -> HARQ=1, SR=1 (Bits=11)
        apply_test(4'd3, 4'd0, 4'd0, 1'b1, 1'b1, 1'b1);

        #100;
        $display("--- KET THUC KIEM TRA ---");
        $finish;
    end
endmodule