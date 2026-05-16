module pucch_playback_ctrl (
    input  wire        clk, rst_n,
    input  wire [1:0]  i_scenario_sel,
    input  wire        i_start_pulse,  
    output wire        o_rom_ena,
    output reg  [13:0] o_rom_addr,
    input  wire [23:0] i_rom_data,
    output reg         o_playback_done,
    output wire [23:0] o_adc_tdata,
    output reg         o_adc_tvalid,
    input  wire        i_adc_tready
);
    reg [13:0] start_addr, end_addr;
    reg is_playing, addr_loaded, last_sample_wait;

    // --- 1. ??a ch? Scenario (Kh?p v?i file .coe) ---
    always @(*) begin
        case(i_scenario_sel)
            2'd0: begin start_addr = 14'd0;    end_addr = 14'd4383;  end // S1: 4384 samples
            2'd1: begin start_addr = 14'd4384; end_addr = 14'd8831;  end // S2: 4448 samples
            2'd2: begin start_addr = 14'd8832; end_addr = 14'd13279; end // S3: 4448 samples
            default: begin start_addr = 14'd0; end_addr = 14'd0;     end
        endcase
    end

    // --- 2. FSM Playback ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {o_rom_addr, o_adc_tvalid, is_playing, o_playback_done, addr_loaded, last_sample_wait} <= 0;
        end else begin
            o_playback_done <= 0;

            if (i_start_pulse && !is_playing) begin
                o_rom_addr <= start_addr; is_playing <= 1; addr_loaded <= 1;
            end 
            else if (addr_loaded) begin
                o_adc_tvalid <= 1; addr_loaded <= 0;
            end 
            else if (is_playing && o_adc_tvalid) begin
                if (i_adc_tready) begin
                    if (o_rom_addr == end_addr) begin
                        is_playing <= 0; last_sample_wait <= 1; // ??i m?u cu?i thoát kh?i BRAM
                    end else begin
                        o_rom_addr <= o_rom_addr + 1;
                    end
                end
            end
            else if (last_sample_wait && i_adc_tready) begin
                o_adc_tvalid <= 0; last_sample_wait <= 0; o_playback_done <= 1;
            end
        end
    end

    assign o_adc_tdata = i_rom_data;
    assign o_rom_ena   = is_playing || addr_loaded || last_sample_wait;

endmodule