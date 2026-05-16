`timescale 1ns / 1ps

module tb_fft_wrapper();
    // --- Clock & Reset ---
    reg clk;
    reg rst_n;

    // --- Interface to Wrapper ---
    reg [31:0] s_axis_data_tdata;
    reg        s_axis_data_tvalid;
    wire       s_axis_data_tready;
    reg        s_axis_data_tlast;

    wire [31:0] m_fft_real;
    wire [31:0] m_fft_imag;
    wire [11:0] m_fft_index;
    wire        m_fft_valid;
    wire        m_fft_last;
    reg         m_fft_ready;

    // --- Bi?n h? tr? ---
    reg [31:0] cp_out_mem [0:4095]; // Load file ??u ra c?a cp_removal
    integer i;
    integer out_cnt = 0;

    // 1. Instantiate Wrapper
    fft_wrapper uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),
        .s_axis_data_tlast(s_axis_data_tlast),
        .m_fft_real(m_fft_real),
        .m_fft_imag(m_fft_imag),
        .m_fft_index(m_fft_index),
        .m_fft_valid(m_fft_valid),
        .m_fft_last(m_fft_last),
        .m_fft_ready(m_fft_ready)
    );

    // 2. T?o Clock 122.88 MHz
    initial clk = 0;
    always #4.069 clk = ~clk;

    // 3. Kh?i Stimulus
    initial begin
        // Load file txt (??m b?o file n?m trong th? m?c simulation c?a project)
        $readmemh("1_cp_removed_shifted_32b.txt", cp_out_mem);

        // Kh?i t?o ban ??u
        rst_n = 0;
        s_axis_data_tdata = 0;
        s_axis_data_tvalid = 0;
        s_axis_data_tlast = 0;
        m_fft_ready = 1;

        #100;
        @(posedge clk); rst_n <= 1;
        
        // --- ??I WRAPPER C?U HÌNH XONG ---
        // Chân s_axis_data_tready ch? lên 1 sau khi FFT IP nh?n xong config
        $display("--- [%t] WAITING: Doi Wrapper gui cau hinh cho FFT IP... ---", $time);
        wait(s_axis_data_tready == 1'b1);
        repeat(5) @(posedge clk);

        $display("--- [%t] START: Bom du lieu tu file vao FFT Wrapper ---", $time);
        
        for (i = 0; i < 4096; i = i + 1) begin
            @(posedge clk);
            #4; // Dùng tr? 4ns ?? d? li?u c?c k? ?n ??nh nh? ta ?ã rút kinh nghi?m
            
            if (s_axis_data_tready) begin
                s_axis_data_tdata  <= cp_out_mem[i];
                s_axis_data_tvalid <= 1'b1;
                s_axis_data_tlast  <= (i == 4095);
            end else begin
                i = i - 1; // ??i n?u FFT ch?a s?n sàng
            end
        end

        @(posedge clk);
        #4;
        s_axis_data_tvalid <= 1'b0;
        s_axis_data_tlast  <= 1'b0;

        // ??i tín hi?u k?t thúc t? FFT
        wait(m_fft_last && m_fft_valid);
        #500;
        $display("--- [%t] SUCCESS: Da nhan du 4096 mau sau FFT ---", $time);
        $stop;
    end

    // 4. Kh?i Monitor: In k?t qu? ra Console ?? ??i chi?u MATLAB
    always @(posedge clk) begin
        #6; // ??i d? li?u ?n ??nh sau c?nh clock
        if (m_fft_valid && m_fft_ready) begin
            $display("Index: %d | Real: %h | Imag: %h", m_fft_index, m_fft_real, m_fft_imag);
            out_cnt <= out_cnt + 1;
        end
    end

endmodule