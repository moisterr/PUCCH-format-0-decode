`timescale 1ns / 1ps

module pucch_pre_cal_top (
    input  wire        clk,
    input  wire        rst_n,
    
    // System Configuration
    input  wire [9:0]  i_pci,
    input  wire [9:0]  i_hopping_id,
    input  wire        i_rrc_configured,
    input  wire        i_run_en,      
    input  wire        i_param_en,    // nid_change_en
    
    // Status and Counters
    output wire [3:0]  o_bit_cnt,
    output wire [3:0]  o_symb_cnt,
    output reg  [4:0]  o_slot_cnt,
    output wire        o_done,
    
    // BRAM Interface
    output wire [8:0]  o_bram_addr,
    output wire [13:0] o_bram_din,
    output reg         o_bram_we
);

    // =========================================================
    // 1. COUNTERS
    // =========================================================
    reg [3:0] reg_bit_cnt, reg_symb_cnt;
    reg       reg_done;

    assign o_bit_cnt  = reg_bit_cnt;
    assign o_symb_cnt = reg_symb_cnt;
    assign o_done     = reg_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_bit_cnt <= 0; reg_symb_cnt <= 0; o_slot_cnt <= 0;
        end else if (i_param_en) begin 
            reg_bit_cnt <= 0; reg_symb_cnt <= 0; o_slot_cnt <= 0;
        end else if (i_run_en && !reg_done) begin
            if (reg_bit_cnt == 4'd13) begin
                reg_bit_cnt <= 0;
                if (reg_symb_cnt == 4'd13) begin
                    reg_symb_cnt <= 0;
                    o_slot_cnt <= (o_slot_cnt == 19) ? 0 : o_slot_cnt + 1;
                end else reg_symb_cnt <= reg_symb_cnt + 1;
            end else reg_bit_cnt <= reg_bit_cnt + 1;
        end
    end

    // =========================================================
    // 2. STAGGERED DELAYS (PURGED reg_en_d3)
    // =========================================================
    reg reg_en_d, reg_en_d2;
    always @(posedge clk) {reg_en_d, reg_en_d2} <= {i_param_en, reg_en_d};

    wire [9:0] w_hid_q, w_pci_q;
    pucch_param_reg #(.WIDTH(10)) i_hid_reg (.i_clk(clk), .i_rst_n(rst_n), .i_en(i_param_en), .i_data(i_hopping_id), .o_data(w_hid_q));
    pucch_param_reg #(.WIDTH(10)) i_pci_reg (.i_clk(clk), .i_rst_n(rst_n), .i_en(i_param_en), .i_data(i_pci),        .o_data(w_pci_q));

    wire [9:0] w_nid = i_rrc_configured ? w_hid_q : w_pci_q;

    wire [4:0] w_uf_comb;
    pucch_modulo #(.IN_WIDTH(10), .MOD_VALUE(30), .OUT_WIDTH(5)) i_uf_mod (.i_data(w_nid), .o_data(w_uf_comb));
    
    reg [4:0] reg_uf;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      reg_uf <= 5'd0;
        else if (reg_en_d) reg_uf <= w_uf_comb;
    end

    // =========================================================
    // 3. GOLD SEQUENCE ENGINES
    // =========================================================
    wire [30:0] w_j_n1, w_j_n2, w_j_f1, w_j_f2;
    pucch_xor_matrix_x1 i_mat_n1 (.i_state(31'd1),            .o_state_next(w_j_n1));
    pucch_xor_matrix_x2 i_mat_n2 (.i_state({21'b0, w_nid}),    .o_state_next(w_j_n2));
    pucch_xor_matrix_x1 i_mat_f1 (.i_state(31'd1),            .o_state_next(w_j_f1));
    pucch_xor_matrix_x2 i_mat_f2 (.i_state({25'b0, w_nid/30}), .o_state_next(w_j_f2));

    wire w_shift_en_gen = i_run_en && (reg_bit_cnt <= 7);
    wire w_n1, w_n2, w_f1, w_f2;
    wire [7:0] w_ncs_byte, w_fgh_byte;

    pucch_lfsr_x1 i_lfsr1_ncs (.i_clk(clk), .i_rst_n(rst_n), .i_load_en(reg_en_d2), .i_shift_en(w_shift_en_gen), .i_seed(w_j_n1), .o_bit(w_n1));
    pucch_lfsr_x2 i_lfsr2_ncs (.i_clk(clk), .i_rst_n(rst_n), .i_load_en(reg_en_d2), .i_shift_en(w_shift_en_gen), .i_seed(w_j_n2), .o_bit(w_n2));
    pucch_sipo_reg_8b i_sipo_ncs (.i_clk(clk), .i_rst_n(rst_n), .i_shift_en(w_shift_en_gen), .i_bit(w_n1 ^ w_n2), .o_data(w_ncs_byte));

    wire w_fgh_active = (reg_symb_cnt == 0 || reg_symb_cnt == 13);
    pucch_lfsr_x1 i_lfsr1_fgh (.i_clk(clk), .i_rst_n(rst_n), .i_load_en(reg_en_d2), .i_shift_en(w_shift_en_gen && w_fgh_active), .i_seed(w_j_f1), .o_bit(w_f1));
    pucch_lfsr_x2 i_lfsr2_fgh (.i_clk(clk), .i_rst_n(rst_n), .i_load_en(reg_en_d2), .i_shift_en(w_shift_en_gen && w_fgh_active), .i_seed(w_j_f2), .o_bit(w_f2));
    pucch_sipo_reg_8b i_sipo_fgh (.i_clk(clk), .i_rst_n(rst_n), .i_shift_en(w_shift_en_gen && reg_symb_cnt == 0), .i_bit(w_f1 ^ w_f2), .o_data(w_fgh_byte));

    // =========================================================
    // 4. HOPPING LOGIC 
    // =========================================================
    wire [8:0] w_fgh_sum;
    wire [4:0] w_fgh_mod;
    wire [3:0] w_ncs_hop_mod;

    pucch_adder_param #(.WIDTH_A(8), .WIDTH_B(5), .WIDTH_SUM(9)) i_fgh_add (.i_data_a(w_fgh_byte), .i_data_b(reg_uf), .o_sum(w_fgh_sum));
    pucch_modulo #(.IN_WIDTH(9), .MOD_VALUE(30), .OUT_WIDTH(5)) i_fgh_mod (.i_data(w_fgh_sum), .o_data(w_fgh_mod));
    pucch_modulo #(.IN_WIDTH(8), .MOD_VALUE(12), .OUT_WIDTH(4)) i_ncs_mod (.i_data(w_ncs_byte), .o_data(w_ncs_hop_mod));

    // =========================================================
    // 5. U_LATCH & BRAM DIN
    // =========================================================
    reg [4:0] reg_u_latch;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                            reg_u_latch <= 5'd0;
        else if (reg_bit_cnt == 9 && reg_symb_cnt == 0) reg_u_latch <= w_fgh_mod;
    end

    wire [4:0] w_curr_u = (reg_symb_cnt == 0) ? w_fgh_mod : reg_u_latch;
    assign o_bram_din = {w_curr_u, w_ncs_hop_mod, reg_uf};

    // =========================================================
    // 6. BRAM WRITE CONTROL
    // =========================================================
    reg [8:0] reg_addr;
    assign o_bram_addr = reg_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_bram_we <= 0; reg_addr <= 0; reg_done <= 0;
        end else if (i_param_en) begin
            reg_done <= 0; reg_addr <= 0; o_bram_we <= 0;
        end else begin
            if (i_run_en && reg_bit_cnt == 4'd10 && !reg_done) 
                o_bram_we <= 1'b1;
            else 
                o_bram_we <= 1'b0;

            if (o_bram_we) begin
                if (reg_addr == 9'd279) reg_done <= 1'b1;
                else                    reg_addr <= reg_addr + 1;
            end
        end
    end

endmodule