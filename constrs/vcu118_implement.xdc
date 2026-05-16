# =================================================================
# Constraint File: vcu118_pucch.xdc
# Board  : Xilinx VCU118 (XCVU9P-L2FLGA2104)
# Ref    : UG1224 (v1.5) March 15, 2023 - Table 3-7, Table 3-29
# Design : PUCCH Format 0 Receiver
# =================================================================

# -----------------------------------------------------------------
# 1. SYSTEM CLOCK - SYSCLK1_300 (300 MHz, LVDS)
#    Ref UG1224 Table 3-7:
#      SYSCLK1_300_P ? Bank 47 GC pin G31
#      SYSCLK1_300_N ? Bank 47 GC pin F31
#    IOSTANDARD: DIFF_SSTL12 (Bank 47 Vccio = 1.2V)
#    C?n MMCM/PLL ?? t?o ra 122.88 MHz t? 300 MHz
# -----------------------------------------------------------------
set_property PACKAGE_PIN G31 [get_ports i_sysclk_p]
set_property PACKAGE_PIN F31 [get_ports i_sysclk_n]
set_property IOSTANDARD LVDS [get_ports i_sysclk_p]
set_property IOSTANDARD LVDS [get_ports i_sysclk_n]

# Clock g?c 300 MHz
#create_clock -period 3.333 -name clk_300 [get_ports i_sysclk_p]

# Clock 122.88 MHz output t? MMCM (Clocking Wizard)
# S?a ???ng net b?n d??i cho kh?p v?i t?n instance MMCM trong design
# V? d? n?u Clocking Wizard instance t?n l? "i_clk_wiz":
#create_generated_clock -name clk_122m88 #    -source [get_ports i_sysclk_p] #    -multiply_by 4096 #    -divide_by 10000 #    [get_pins i_clk_wiz/inst/mmcme4_adv_inst/CLKOUT0]

# -----------------------------------------------------------------
# 2. CPU RESET PUSHBUTTON - SW5 (Active HIGH)
#    Ref UG1224 Table 3-29:
#      CPU_RESET ? Bank 73, Pin L19, LVCMOS12
#    L?u ?: Active HIGH (nh?n = 1) ? c?n invert trong HDL n?u
#    design d?ng active-low reset
# -----------------------------------------------------------------
set_property PACKAGE_PIN L19 [get_ports i_cpu_reset]
set_property IOSTANDARD LVCMOS12 [get_ports i_cpu_reset]

# -----------------------------------------------------------------
# 3. USER PUSHBUTTONS - Directional (Active HIGH)
#    Ref UG1224 Table 3-29:
#      GPIO_SW_N ? Bank 64, Pin BB24, LVCMOS18  ? nid_change_en
#      GPIO_SW_E ? Bank 64, Pin BE23, LVCMOS18  ? decode_cfg_en
#      GPIO_SW_W ? Bank 64, Pin BF22, LVCMOS18  ? stream_trigger
#      GPIO_SW_S ? Bank 64, Pin BE22, LVCMOS18  ? spare
#      GPIO_SW_C ? Bank 64, Pin BD23, LVCMOS18  ? spare
#    QUAN TR?NG: Bank 64 Vccio = 1.8V ? LVCMOS18
#    File c? d?ng LVCMOS12 cho Bank 64 ? SAI
# -----------------------------------------------------------------
#set_property PACKAGE_PIN  BB24         [get_ports i_nid_change_en]
#set_property IOSTANDARD   LVCMOS18     [get_ports i_nid_change_en]

#set_property PACKAGE_PIN  BE23         [get_ports i_decode_cfg_en]
#set_property IOSTANDARD   LVCMOS18     [get_ports i_decode_cfg_en]

#set_property PACKAGE_PIN  BF22         [get_ports i_stream_trigger]
#set_property IOSTANDARD   LVCMOS18     [get_ports i_stream_trigger]

#set_property PACKAGE_PIN  BE22         [get_ports i_sw_s]
#set_property IOSTANDARD   LVCMOS18     [get_ports i_sw_s]

#set_property PACKAGE_PIN  BD23         [get_ports i_sw_c]
#set_property IOSTANDARD   LVCMOS18     [get_ports i_sw_c]

# -----------------------------------------------------------------
# 4. GPIO LEDs - DS7..DS18 (Active HIGH)
#    Ref UG1224 Table 3-29:
#      GPIO_LED_0 ? Bank 40, Pin AT32, LVCMOS12  ? FSM IDLE
#      GPIO_LED_1 ? Bank 40, Pin AV34, LVCMOS12  ? FSM CALC
#      GPIO_LED_2 ? Bank 40, Pin AY30, LVCMOS12  ? FSM READY
#      GPIO_LED_3 ? Bank 40, Pin BB32, LVCMOS12  ? pre_cal_done
#      GPIO_LED_4 ? Bank 40, Pin BF32, LVCMOS12  ? final_valid
#      GPIO_LED_5 ? Bank 42, Pin AU37, LVCMOS12  ? final_sr
#                   (File c? d?ng AV36 cho LED5 ? SAI, ??ng l? AU37)
#      GPIO_LED_6 ? Bank 42, Pin AV36, LVCMOS12  ? final_dtx
#      GPIO_LED_7 ? Bank 42, Pin BA37, LVCMOS12  ? final_harq[0]
# -----------------------------------------------------------------
set_property PACKAGE_PIN AT32 [get_ports {o_led[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[0]}]

set_property PACKAGE_PIN AV34 [get_ports {o_led[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[1]}]

set_property PACKAGE_PIN AY30 [get_ports {o_led[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[2]}]

set_property PACKAGE_PIN BB32 [get_ports {o_led[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[3]}]

set_property PACKAGE_PIN BF32 [get_ports {o_led[4]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[4]}]

set_property PACKAGE_PIN AU37 [get_ports {o_led[5]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[5]}]

set_property PACKAGE_PIN AV36 [get_ports {o_led[6]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[6]}]

set_property PACKAGE_PIN BA37 [get_ports {o_led[7]}]
set_property IOSTANDARD LVCMOS12 [get_ports {o_led[7]}]

# -----------------------------------------------------------------
# 5. GPIO DIP SWITCH - SW12 (Active HIGH, c? th? d?ng cho PCI bits)
#    Ref UG1224 Table 3-29:
#      GPIO_DIP_SW1 ? Bank 73, Pin B17, LVCMOS12
#      GPIO_DIP_SW2 ? Bank 73, Pin G16, LVCMOS12
#      GPIO_DIP_SW3 ? Bank 73, Pin J16, LVCMOS12
#      GPIO_DIP_SW4 ? Bank 72, Pin D21, LVCMOS12
# -----------------------------------------------------------------
#set_property PACKAGE_PIN  B17          [get_ports {i_dip_sw[0]}]
#set_property IOSTANDARD   LVCMOS12     [get_ports {i_dip_sw[0]}]

#set_property PACKAGE_PIN  G16          [get_ports {i_dip_sw[1]}]
#set_property IOSTANDARD   LVCMOS12     [get_ports {i_dip_sw[1]}]

#set_property PACKAGE_PIN  J16          [get_ports {i_dip_sw[2]}]
#set_property IOSTANDARD   LVCMOS12     [get_ports {i_dip_sw[2]}]

#set_property PACKAGE_PIN  D21          [get_ports {i_dip_sw[3]}]
#set_property IOSTANDARD   LVCMOS12     [get_ports {i_dip_sw[3]}]

# -----------------------------------------------------------------
# 6. TIMING EXCEPTIONS
# -----------------------------------------------------------------
# Pushbuttons v? DIP switch: async input, kh?ng c?n timing analysis
set_false_path -from [get_ports i_cpu_reset]
#set_false_path -from [get_ports i_nid_change_en]
#set_false_path -from [get_ports i_decode_cfg_en]
#set_false_path -from [get_ports i_stream_trigger]
#set_false_path -from [get_ports i_sw_s]
#set_false_path -from [get_ports i_sw_c]
#set_false_path -from [get_ports {i_dip_sw[*]}]

# LED outputs: kh?ng c?n timing
set_false_path -to [get_ports {o_led[*]}]

# -----------------------------------------------------------------
# 7. BITSTREAM CONFIGURATION
# -----------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]



create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 1 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list i_clk_wiz/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 2 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {i_pucch_core/i_pucch_controller/state[0]} {i_pucch_core/i_pucch_controller/state[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 4 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_decoder/i_n_cs[0]} {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_decoder/i_n_cs[1]} {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_decoder/i_n_cs[2]} {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_decoder/i_n_cs[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 4 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_peak_det/o_peak_index[0]} {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_peak_det/o_peak_index[1]} {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_peak_det/o_peak_index[2]} {i_pucch_core/i_pucch_datapath/i_pucch_decode_top/i_peak_det/o_peak_index[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list i_pucch_core/i_pucch_controller/w_nid_changed]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list w_final_valid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_122m88]
