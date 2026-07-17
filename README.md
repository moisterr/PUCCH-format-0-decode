# 5G NR PUCCH Format 0 Decoder - Hardware Implementation

## 📌 Project Overview
This repository contains the RTL implementation and verification environment for a **5G New Radio (NR) Physical Uplink Control Channel (PUCCH) Format 0 Decoder**. The project bridges complex telecommunication algorithms with synthesizable hardware, specifically targeting the **Xilinx Virtex UltraScale+ VCU118 FPGA** platform.

This project was developed as a graduation thesis to demonstrate advanced digital IC design methodologies, focusing on digital signal processing (DSP) datapath optimization and rigorous functional verification.

## 🛠️ Technologies & Tools
*   **Hardware Description Language:** SystemVerilog / Verilog
*   **Target FPGA:** Xilinx Virtex UltraScale+ VCU118
*   **Synthesis & Simulation:** Xilinx Vivado
*   **Golden Model & Data Analysis:** MATLAB

## 🏗️ System Architecture
The decoder architecture is designed to accurately extract the Uplink Control Information (UCI) bits (ACK/NACK, SR) from the received baseband signals.

<img width="1190" height="472" alt="ARCHITECTURE" src="[https://github.com/user-attachments/assets/a6c00ad8-5773-418e-89a3-cad30770fe24](https://github.com/user-attachments/assets/a6c00ad8-5773-418e-89a3-cad30770fe24)" />

### ⚙️ Implemented Algorithms
1.  **Input Buffer & Control Logic:** Manages the incoming I/Q data streams and synchronizes the processing pipeline.
2.  **XOR Matrix for Fast State Jumping:** Integrated a parallel XOR matrix logic to accelerate sequence generation and hopping mechanisms. This architecture allows the system to compute rapid state transitions in a single clock cycle, significantly reducing datapath latency compared to traditional serial shift registers.
3.  **Goertzel Algorithm Branch:** Efficiently computes specific Discrete Fourier Transform (DFT) terms to detect the presence of sequence cyclic shifts. Optimized for MAC (Multiply-Accumulate) operations to minimize DSP slice utilization.
4.  **Peak Detector:** Analyzes the output from the Goertzel branches to identify the index of the maximum energy, mapping it back to the transmitted UCI bits.

## 📁 Directory Structure
```text 
├── src/pucch_vcu118_wrapper                  # Synthesizable RTL source files (SystemVerilog/Verilog)
│   └── pucch_playback_ctrl.v
│   ├── pucch_top.v
    │   ├── pucch_controller.v
    │   ├── pucch_datapath.v
        │   ├── pucch_pre_cal_top.v
        │   ├── pucch_decode_top.v
            │   ├── pucch_cp_remover.v
            │   ├── pucch_goertzel_top.v
                │   ├── pucch_goertzel_branch.v
            │   ├── pucch_de_spreader.v
            │   ├── pucch_idft_top.v
                │   ├── pucch_idft_branch.v
            │   ├── pucch_peak_detector
                │   ├── pucch_threshold_decision.v
                │   ├── pucch_cmp_sum_unit.v
            │   ├── pucch_logic_decoder.v
├── tb/                   # Testbenches for module-level and system-level simulation
│   └── tb_pucch_top.sv
