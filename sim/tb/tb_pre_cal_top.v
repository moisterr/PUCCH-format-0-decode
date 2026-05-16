`timescale 1ns/1ps

module tb_pre_cal_top();

    reg clk, rst_n, run_en, param_en, RRC_configured;
    reg [9:0] PCI, hoppingID;
    wire [3:0] bit_cnt, symb_cnt;
    wire [4:0] slot_cnt;
    wire [8:0] bram_addr;
    wire [13:0] bram_din;
    wire bram_we, done;

    // DUT - ? Post-Impl Sim, ?ây s? là Netlist
    pre_cal_TOP dut (
        .clk(clk), .rst_n(rst_n), .PCI(PCI), .hoppingID(hoppingID),
        .RRC_configured(RRC_configured), .run_en(run_en), .param_en(param_en),
        .bit_cnt(bit_cnt), .symb_cnt(symb_cnt), .slot_cnt(slot_cnt),
        .bram_addr(bram_addr), .bram_din(bram_din), .bram_we(bram_we), .done(done)
    );

    initial clk = 0;
    always #4.069 clk = ~clk;

    initial begin
        // Kh?i t?o tham s? (PCI=120, m0=3)
        rst_n = 0; PCI = 120; hoppingID = 0; RRC_configured = 0; run_en = 0; param_en = 0;
        #100; rst_n = 1; #20;

        // N?p tham s?
        @(posedge clk); #1; param_en = 1;
        @(posedge clk); #1; param_en = 0;

        // Thay vì wait(dut.p_en_d3), ta ??i m?t kho?ng th?i gian c? ??nh 
        // ?? ??m b?o n?p Seeds xong (Post-Impl không soi ???c tín hi?u n?i b?)
        repeat(10) @(posedge clk); 
        
        #1;
        $display("--- [START] Post-Implementation Sim | PCI=%0d ---", PCI);
        run_en = 1;

        // Ch? tín hi?u done t? c?ng Output
        wait(done == 1'b1);
        repeat(20) @(posedge clk);
        $display("--- [SUCCESS] Pre-calculation Finished! ---");
        $finish;
    end

    // --- Monitor: ?ây là linh h?n c?a Black-box Testing ---
    always @(posedge clk) begin
        if (bram_we) begin
            // Thêm #2 ?? ??i tín hi?u Post-Impl ?n ??nh (SDF delay) r?i m?i in
            #2; 
            $display("Time=%0t | Addr=%0d | Slot=%0d | Symb=%0d | u=%0d | ncs=%0d", 
                     $time, bram_addr, slot_cnt, symb_cnt, 
                     bram_din[13:9], bram_din[8:5]);
        end
    end

    // --- Matrix Check: ?ã ???c s?a ?? không ch?c vào n?i b? dut ---
    // (Ch? dùng ?? tính toán giá tr? Golden trong TB)
    reg [30:0] g_ncs, g_fgh; integer j;
    initial begin
        // Tính toán Golden Data d?a trên PCI th?c t? trong TB
        // PCI=120 -> g_ncs=120, g_fgh=4 (120/30)
        g_ncs = 120; g_fgh = 4;
        for (j = 0; j < 1600; j = j + 1) begin
            g_ncs = {(g_ncs[3]^g_ncs[2]^g_ncs[1]^g_ncs[0]), g_ncs[30:1]};
            g_fgh = {(g_fgh[3]^g_fgh[2]^g_fgh[1]^g_fgh[0]), g_fgh[30:1]};
        end
        
        // Post-Implementation Sim không nên check n?i b? j_n2, j_f2
        // vì chúng th??ng b? ??i tên ho?c g?p vào LUT.
        // Chúng ta s? tin t??ng vào k?t qu? u và ncs in ra ? Monitor.
    end

endmodule