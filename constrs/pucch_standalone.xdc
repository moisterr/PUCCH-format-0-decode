# =================================================================
# Constraint File: pucch_standalone.xdc (V2 - RAM OPTIMIZED)
# Purpose: Pure Logic Implementation for Reporting (OOC Mode)
# =================================================================

# -----------------------------------------------------------------
# 1. PRIMARY CLOCK (B?t bu?c ph?i gi?)
#    Xác ??nh "áp l?c" th?i gian ?? tính toán Timing (WNS/Fmax).
# -----------------------------------------------------------------
create_clock -period 8.138 -name pucch_core_clk [get_ports i_clk]

# -----------------------------------------------------------------
# 2. TIMING EXCEPTIONS (Gi? l?i ?? s?ch báo cáo)
#    Lo?i b? các chân I/O kh?i phân tích Timing ?? Vivado ch? t?p trung
#    vào các ???ng ch?y bên trong lõi (Register-to-Register).
# -----------------------------------------------------------------
set_false_path -from [get_ports i_rst_n]
set_false_path -to [get_ports o_final_valid]
set_false_path -to [get_ports o_final_sr]
set_false_path -to [get_ports o_final_dtx]
set_false_path -to [get_ports o_final_harq[*]]
set_false_path -to [get_ports o_adc_gate_en]
set_false_path -to [get_ports o_adc_tready]

# -----------------------------------------------------------------
# 3. BITSTREAM & OOC CONFIGURATION (Quan tr?ng nh?t)
#    Cho phép Vivado không gán chân v?t lý mà v?n ch?y ???c Implementation.
# -----------------------------------------------------------------
set_property BITSTREAM.General.UnconstrainedPins {Allow} [current_design]

# Các c?u hình n?p chip (Có th? gi? ho?c b?, không ?nh h??ng RAM)
set_property BITSTREAM.GENERAL.COMPRESS      TRUE  [current_design]
set_property CONFIG_VOLTAGE                  1.8   [current_design]
set_property CFGBVS                          GND   [current_design]