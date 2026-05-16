`timescale 1ns/1ps

/**
 * Testbench: tb_pucch_top
 * Description: Final standardized version with Automated Output Verification.
 * Ports updated to match pucch_top (i_ and o_ prefixes).
 * Internal hierarchy fixed for glitch-free monitoring.
 */

module tb_pucch_top;

    // =================================================================
    // 1. SCENARIO CONFIGURATION
    // =================================================================
    localparam FILE1 = "1_adc_out_24b.txt";
    localparam FILE2 = "2_adc_out_24b.txt";
    localparam FILE3 = "3_adc_out_24b.txt";

    localparam SYM0_SAMPLES = 4448;
    localparam SYMN_SAMPLES = 4384;
    localparam MAX_SAMPLES  = 4448;

    // Scenarios timing
    localparam S1_SLOT = 5'd0, S1_SYMBOL = 4'd12;
    localparam S2_SLOT = 5'd0, S2_SYMBOL = 4'd0;
    localparam S3_SLOT = 5'd3, S3_SYMBOL = 4'd0;

    // =================================================================
    // 2. DUT SIGNALS & INSTANTIATION
    // =================================================================
    reg         clk, rst_n;
    reg [9:0]   PCI, hoppingID;
    reg         RRC_configured, groupHopping, is_2bit_mode;
    reg [3:0]   m0, alpha_shift;
    reg         nid_change_en, decode_cfg_en;
    reg [23:0]  s_axis_adc_tdata;
    reg         s_axis_adc_tvalid;
    wire        s_axis_adc_tready;
    reg [4:0]   curr_slot;
    reg [3:0]   curr_symbol;
    reg [11:0]  start_re_idx;
    reg tb_decode_done;
    
    wire [1:0]  final_harq;
    wire        final_sr, final_dtx, final_valid;

    // Updated Port Mapping to match standardized pucch_top
    pucch_top #(
        .FFT_SIZE(4096), .CP_LEN_LONG(352), .CP_LEN_SHORT(288)
    ) dut (
        .i_clk                (clk), 
        .i_rst_n              (rst_n),
        .i_nid_change_en      (nid_change_en), 
        .i_pci                (PCI), 
        .i_hopping_id         (hoppingID), 
        .i_rrc_configured     (RRC_configured),
        .i_m0                 (m0), 
        .i_group_hopping      (groupHopping), 
        .i_is_2bit_mode       (is_2bit_mode),
        .i_adc_tdata          (s_axis_adc_tdata), 
        .i_adc_tvalid         (s_axis_adc_tvalid),
        .i_decode_done        (tb_decode_done),
        .o_adc_tready         (s_axis_adc_tready),
        .i_curr_slot          (curr_slot), 
        .i_curr_symbol        (curr_symbol),
        .i_start_re_idx       (start_re_idx), 
        .i_alpha_shift        (alpha_shift),
        .o_final_harq         (final_harq), 
        .o_final_sr           (final_sr),
        .o_final_dtx          (final_dtx), 
        .o_final_valid        (final_valid)
    );

    // --- Clock Generation ---
    initial clk = 0;
    always #4.069 clk = ~clk;

    reg [23:0] adc_buf [0:MAX_SAMPLES-1];
    reg [1:0]  res_harq [0:2];
    reg        res_sr   [0:2], res_dtx [0:2];
    
    // Flags for Verification
    reg        s1_pass, s2_pass, s3_pass;

    // =================================================================
    // 3. TASKS
    // =================================================================

    task automatic load_file;
        input  [640:0] fname;
        output integer n_loaded;
        integer fd, ret; reg [23:0] tmp;
        begin
            n_loaded = 0; fd = $fopen(fname, "r");
            if (fd == 0) begin $display("[ERR] No file %s", fname); $finish; end
            while (!$feof(fd) && n_loaded < MAX_SAMPLES) begin
                ret = $fscanf(fd, "%h\n", tmp);
                if (ret == 1) begin adc_buf[n_loaded] = tmp; n_loaded++; end
            end
            $fclose(fd);
            $display("[FILE] Loaded %0d samples", n_loaded);
        end
    endtask

    task configure_nid;
        input [9:0] t_pci, t_hop; input t_rrc, t_gh, t_2bit;
        input [3:0] t_m0; input [11:0] t_re; input [3:0] t_alpha;
        begin
            PCI <= t_pci; hoppingID <= t_hop; RRC_configured <= t_rrc;
            groupHopping <= t_gh; is_2bit_mode <= t_2bit; m0 <= t_m0;
            start_re_idx <= t_re; alpha_shift <= t_alpha;
            nid_change_en <= 1'b1; decode_cfg_en <= 1'b1;
            repeat(2) @(posedge clk); #1;
            nid_change_en <= 1'b0; decode_cfg_en <= 1'b0;
        end
    endtask

    task configure_decode_only;
        input t_gh, t_2bit; input [3:0] t_m0;
        input [11:0] t_re; input [3:0] t_alpha;
        begin
            groupHopping <= t_gh; is_2bit_mode <= t_2bit; m0 <= t_m0;
            start_re_idx <= t_re; alpha_shift <= t_alpha;
            decode_cfg_en <= 1'b1; nid_change_en <= 1'b1; 
            repeat(2) @(posedge clk); #1;
            decode_cfg_en <= 1'b0; nid_change_en <= 1'b0;
        end
    endtask

    task wait_pre_cal;
        begin
            $display("[WAIT] Waiting for ST_READY via o_adc_tready ...");
            fork
                begin : b_wait
                    wait(s_axis_adc_tready == 1'b1);
                end
                begin : b_timeout
                    repeat(200000) @(posedge clk);
                    $display("[TIMEOUT] System never became READY!"); $finish;
                end
            join_any
            disable fork;
            @(posedge clk);
            $display("[READY] System is ready to receive samples at t=%0t", $time);
        end
    endtask

    task stream_symbol;
        input integer n_samples;
        integer i;
        begin
            @(posedge clk); #1; s_axis_adc_tvalid <= 1'b1;
            i = 0;
            while (i < n_samples) begin
                s_axis_adc_tdata <= adc_buf[i];
                @(posedge clk);
                if (s_axis_adc_tready) begin i++; #1; end
            end
            s_axis_adc_tvalid <= 1'b0;
            $display("[STREAM] Done.");
        end
    endtask

    task wait_result;
        input integer id;
        output [1:0] h; output s, d;
        begin
            fork
                begin : b_valid
                    wait(final_valid == 1'b1);
                    @(posedge clk); #1;
                    h = final_harq; s = final_sr; d = final_dtx;
                end
                begin : b_timeout
                    repeat(1000000) @(posedge clk);
                    $display("[TIMEOUT] Result Scenario %0d", id);
                end
            join_any
            disable fork;
            $display("[RESULT S%0d] HARQ=%b SR=%b DTX=%b", id, h, s, d);
        end
    endtask

    

    // =================================================================
    // 4. STIMULUS & AUTO VERIFICATION
    // =================================================================
    integer n_loaded;
    reg [1:0] fsm_prev;

    initial begin
        rst_n = 0; nid_change_en = 0; decode_cfg_en = 0;
        s_axis_adc_tvalid = 0; s_axis_adc_tdata = 0;
        tb_decode_done = 1'b0;
        fsm_prev = 0;
        s1_pass = 0; s2_pass = 0; s3_pass = 0;

        repeat(20) @(posedge clk); #1; rst_n = 1;
        $display("[SYS] Global Reset Released.");

        // SCENARIO 1
        $display("\n========== SCENARIO 1 ==========");
        load_file(FILE1, n_loaded);
        curr_slot = S1_SLOT; curr_symbol = S1_SYMBOL;
        configure_nid(10'd0, 10'd120, 1'b1, 1'b1, 1'b0, 4'd3, 12'd120, 4'd1);
        wait_pre_cal();
        stream_symbol((S1_SYMBOL == 0) ? SYM0_SAMPLES : SYMN_SAMPLES);
        wait_result(1, res_harq[0], res_sr[0], res_dtx[0]);
        
        tb_decode_done = 1'b1; @(posedge clk); #1; tb_decode_done = 1'b0;

        repeat(200) @(posedge clk);

        // SCENARIO 2
        $display("\n========== SCENARIO 2 ==========");
        load_file(FILE2, n_loaded);
        curr_slot = S2_SLOT; curr_symbol = S2_SYMBOL;
        configure_decode_only(1'b1, 1'b1, 4'd6, 12'd300, 4'd1);
        wait_pre_cal();
        stream_symbol((S2_SYMBOL == 0) ? SYM0_SAMPLES : SYMN_SAMPLES);
        wait_result(2, res_harq[1], res_sr[1], res_dtx[1]);
        tb_decode_done = 1'b1; @(posedge clk); #1; tb_decode_done = 1'b0;

        repeat(200) @(posedge clk);

        // SCENARIO 3
        $display("\n========== SCENARIO 3 ==========");
        load_file(FILE3, n_loaded);
        curr_slot = S3_SLOT; curr_symbol = S3_SYMBOL;
        configure_nid(10'd300, 10'd0, 1'b0, 1'b0, 1'b1, 4'd0, 12'd400, 4'd1);
        wait_pre_cal();
        stream_symbol((S3_SYMBOL == 0) ? SYM0_SAMPLES : SYMN_SAMPLES);
        wait_result(3, res_harq[2], res_sr[2], res_dtx[2]);
        
        tb_decode_done = 1'b1; @(posedge clk); #1; tb_decode_done = 1'b0;

        // =============================================================
        // 5. SELF-CHECKING VERIFICATION LOGIC
        // =============================================================
        s1_pass = (res_harq[0] == 2'b01) && (res_sr[0] == 1'b0) && (res_dtx[0] == 1'b0);
        s2_pass = (res_harq[1] == 2'b11) && (res_sr[1] == 1'b1) && (res_dtx[1] == 1'b0);
        s3_pass = (res_harq[2] == 2'b10) && (res_sr[2] == 1'b1) && (res_dtx[2] == 1'b0);

        $display("\n==================================================");
        $display("======= FINAL SUMMARY & VALIDATION REPORT ========");
        $display("==================================================");
        $display("S1: HARQ=%b SR=%b DTX=%b | Expected: HARQ=01 SR=0 -> %s", res_harq[0], res_sr[0], res_dtx[0], s1_pass ? "PASS" : "FAIL");
        $display("S2: HARQ=%b SR=%b DTX=%b | Expected: HARQ=11 SR=1 -> %s", res_harq[1], res_sr[1], res_dtx[1], s2_pass ? "PASS" : "FAIL");
        $display("S3: HARQ=%b SR=%b DTX=%b | Expected: HARQ=10 SR=1 -> %s", res_harq[2], res_sr[2], res_dtx[2], s3_pass ? "PASS" : "FAIL");
        $display("--------------------------------------------------");
        
        if (s1_pass && s2_pass && s3_pass) begin
            $display(">>>> GLOBAL VERDICT: SUCCESS - ALL SCENARIOS PASSED! <<<<");
        end else begin
            $display(">>>> GLOBAL VERDICT: FAILED - MISMATCH DETECTED! <<<<");
        end
        $display("==================================================\n");
        
        $finish;
    end

    initial begin #100_000_000; $display("[WATCHDOG] Global Timeout!"); $finish; end

endmodule