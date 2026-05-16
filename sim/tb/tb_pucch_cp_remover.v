`timescale 1ns / 1ps

module tb_cp_removal();
    // --- Clock & Reset ---
    reg clk;
    reg rst_n;
    
    // --- ADC Interface ---
    reg [23:0] s_axis_adc_tdata;
    reg        s_axis_adc_tvalid;
    wire       s_axis_adc_tready;
    
    // --- Control ---
    reg [3:0]  symbol_idx;
    
    // --- FFT Interface ---
    wire [31:0] m_axis_fft_tdata;
    wire        m_axis_fft_tvalid;
    wire        m_axis_fft_tlast;
    reg         m_axis_fft_tready;

    // --- Support Variables ---
    // Khai báo 4448 ?? ch?a ?? Symbol 0 (CP dài nh?t)
    reg [23:0] test_mem [0:4447]; 
    integer i;
    integer out_cnt;
    integer NUM_SAMPLES; // S? m?u th?c t? c?n b?m

    // 1. Instantiate UUT (Module c?n test)
    cp_removal #(
        .FFT_SIZE(4096),
        .CP_LONG(352),
        .CP_SHORT(288)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_adc_tdata(s_axis_adc_tdata),
        .s_axis_adc_tvalid(s_axis_adc_tvalid),
        .s_axis_adc_tready(s_axis_adc_tready),
        .symbol_idx(symbol_idx),
        .m_axis_fft_tdata(m_axis_fft_tdata),
        .m_axis_fft_tvalid(m_axis_fft_tvalid),
        .m_axis_fft_tlast(m_axis_fft_tlast),
        .m_axis_fft_tready(m_axis_fft_tready)
    );

    // 2. Clock Generation (122.88 MHz)
    initial clk = 0;
    always #4.069 clk = ~clk;

    // 3. Stimulus Block
    initial begin
        // --- C?U HÌNH TEST T?I ?ÂY ---
        symbol_idx = 4'd12; // S?a thành 0 n?u test Symbol 0, ho?c 1-13 cho các symbol khác
        $readmemh("1_adc_out_24b.txt", test_mem); // Tên file t??ng ?ng
        
        // T? ??ng tính toán s? m?u c?n b?m d?a trên symbol_idx
        if (symbol_idx == 4'd0) 
            NUM_SAMPLES = 4448; // 352 (CP) + 4096
        else 
            NUM_SAMPLES = 4384; // 288 (CP) + 4096
        // -----------------------------

        // Kh?i t?o tr?ng thái ban ??u
        rst_n = 0;
        out_cnt = 0;
        s_axis_adc_tdata = 0;
        s_axis_adc_tvalid = 0;
        m_axis_fft_tready = 1; 
        
        #100; 
        @(posedge clk); 
        rst_n <= 1;
        
        repeat(5) @(posedge clk);
        $display("--- [%t] START SIMULATION: Symbol %d ---", $time, symbol_idx);
        
        // Vòng l?p b?m d? li?u
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            #4; // Delay 4ns ?? né c?nh clock, giúp d? li?u c?c k? ?n ??nh
            
            if (s_axis_adc_tready) begin
                s_axis_adc_tdata  <= test_mem[i]; 
                s_axis_adc_tvalid <= 1'b1;        
            end else begin
                // N?u module ch?a s?n sàng (tready=0), ??ng ??i t?i m?u hi?n t?i
                i = i - 1; 
            end
        end

        // K?t thúc b?m d? li?u
        @(posedge clk);
        #1;
        s_axis_adc_tvalid <= 1'b0;
        
        // ??i cho ??n khi nh?n ?? m?u Payload (m_axis_fft_tlast nh?y lên)
        wait(m_axis_fft_tlast && m_axis_fft_tvalid);
        
        #500;
        $display("--- [%t] END SIMULATION ---", $time);
        $display("Tong so mau FFT thu duoc: %d", out_cnt);
        
        if (out_cnt == 4096) 
            $display(">>> KET QUA: SUCCESS (Du 4096 mau)");
        else 
            $display(">>> KET QUA: FAILED (Chi thu duoc %d mau)", out_cnt);
            
        $stop;
    end

    // 4. Monitor Block: Theo dõi d? li?u ra
    always @(posedge clk) begin
        #6; // ??i d? li?u "l?ng" xu?ng sau c?nh clock
        if (m_axis_fft_tvalid && m_axis_fft_tready) begin
            // In m?u ??u tiên và m?u cu?i cùng ?? ??i chi?u Hex nhanh
            if (out_cnt == 0)
                $display("Mau FFT dau tien (Index 0): %h", m_axis_fft_tdata);
            
            if (m_axis_fft_tlast)
                $display("Mau FFT cuoi cung (Index 4095): %h", m_axis_fft_tdata);
            
            out_cnt <= out_cnt + 1;
        end
    end

endmodule