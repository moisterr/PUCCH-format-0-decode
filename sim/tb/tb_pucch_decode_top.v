`timescale 1ns / 1ps

module tb_decode_TOP();

    // --- 1. Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- 2. Interface ??u vào ---
    reg [23:0] s_axis_adc_tdata;
    reg        s_axis_adc_tvalid;
    wire       s_axis_adc_tready;
    reg [3:0]  symbol_idx;
    reg [11:0] start_re_idx;
    reg [4:0]  u_index;
    reg [3:0]  alpha_shift; 

    // C?u hình B? gi?i mã
    reg [3:0]  n_cs;
    reg [3:0]  m0;
    reg        is_2bit_mode;

    // --- 3. Interface ??u ra (C?P NH?T THEO CHU?N 3GPP) ---
    wire [15:0] m_pucch_real;
    wire [15:0] m_pucch_imag;
    wire [1:0]  final_harq;    // Thay th? cho final_bits
    wire        final_sr;      // Thêm m?i ??u ra SR
    wire        final_dtx;     
    wire        final_valid;   
    wire [3:0]  diag_peak_idx; 

    // --- 4. B? nh? ---
    reg [23:0] adc_mem [0:4447]; 
    integer i;
    integer NUM_SAMPLES;

    // =========================================================
    // 5. INSTANTIATION (C?p nh?t port map)
    // =========================================================
    decode_TOP #(
        .FFT_SIZE(4096), .CP_LONG(352), .CP_SHORT(288)
    ) uut (
        .clk(clk), .rst_n(rst_n),
        .s_axis_adc_tdata(s_axis_adc_tdata), .s_axis_adc_tvalid(s_axis_adc_tvalid),
        .s_axis_adc_tready(s_axis_adc_tready), .symbol_idx(symbol_idx),
        .start_re_idx(start_re_idx), .u_index(u_index), .alpha_shift(alpha_shift),
        .n_cs(n_cs), .m0(m0), .is_2bit_mode(is_2bit_mode),
        .final_harq(final_harq), .final_sr(final_sr), // N?i vào port m?i
        .final_dtx(final_dtx), .final_valid(final_valid),
        .diag_peak_idx(diag_peak_idx), .m_pucch_real(m_pucch_real), .m_pucch_imag(m_pucch_imag)
    );

    // --- 6. Clock 122.88 MHz ---
    initial clk = 0;
    always #4.069 clk = ~clk;

    // =========================================================
    // 7. K?CH B?N MÔ PH?NG
    // =========================================================
    initial begin
        // Kh?i t?o
        rst_n = 0; s_axis_adc_tdata = 24'd0; s_axis_adc_tvalid = 1'b0;
        symbol_idx = 4'd0; start_re_idx = 12'd0; u_index = 5'd0; alpha_shift = 4'd1; 
        
        // C?u hình Testcase: ncs=6, m0=0, 2-bit mode
        n_cs = 4'd10; m0 = 4'd0; is_2bit_mode = 1'b1; 

        #200; repeat(100) @(negedge clk); #2 rst_n = 1;

        // N?p data
        @(posedge clk); #2;
        symbol_idx = 4'd0; start_re_idx = 12'd400; u_index = 5'd0;        
        NUM_SAMPLES = (symbol_idx == 4'd0) ? 4448 : 4384;
        $readmemh("3_adc_out_24b.txt", adc_mem);

        wait(s_axis_adc_tready == 1'b1);
        $display("--- [%t] START: Bom data vao Receiver (NCS=%0d, Mode=%0d-bit) ---", $time, n_cs, is_2bit_mode ? 2 : 1);
        
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            if (s_axis_adc_tready) begin
                #4; s_axis_adc_tdata <= adc_mem[i]; s_axis_adc_tvalid <= 1'b1;
            end else begin
                i = i - 1; #1.2 s_axis_adc_tvalid <= 1'b0;
            end
        end
        @(posedge clk); #2 s_axis_adc_tvalid <= 1'b0;

        // --- ??i k?t qu? và hi?n th? tách bi?t HARQ và SR ---
        fork
            begin
                wait(final_valid);
                #10;
                $display("\n=======================================================");
                $display("       FINAL 3GPP PUCCH DECODING RESULT");
                $display("=======================================================");
                
                if (!final_dtx) begin
                    $display(" STATUS : [SIGNAL DETECTED]");
                    $display(" Peak   : %0d", diag_peak_idx);
                    
                    // Hi?n th? HARQ-ACK
                    if (!is_2bit_mode) 
                        $display(" HARQ   : %b (1-bit)", final_harq[0]);
                    else 
                        $display(" HARQ   : %b (2-bit)", final_harq);
                    
                    // Hi?n th? tr?ng thái SR
                    $display(" SR     : %s (%b)", (final_sr) ? "POSITIVE" : "NEGATIVE", final_sr);
                    
                    // Hi?n th? chi ti?t theo b?ng mapping
                    $display("-------------------------------------------------------");
                    $write(" Result : ");
                    if (is_2bit_mode) begin
                        case (final_harq)
                            2'b00: $write("NACK,NACK");
                            2'b01: $write("NACK,ACK");
                            2'b11: $write("ACK,ACK");
                            2'b10: $write("ACK,NACK");
                        endcase
                    end else begin
                        $write(final_harq[0] ? "ACK" : "NACK");
                    end
                    $display(" + %s SR", final_sr ? "Positive" : "Negative");

                end else begin
                    $display(" STATUS : [DTX] - Noise only");
                end
                $display("=======================================================\n");
                
                #1000;
                $display("--- [%t] SUCCESS: Finish! ---", $time);
            end
            begin
                repeat(150000) @(posedge clk); 
                $display("--- [%t] ERROR: Timeout! ---", $time);
            end
        join_any
        $stop;
    end
endmodule