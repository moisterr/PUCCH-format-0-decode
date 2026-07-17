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
The decoder architecture is designed to accurately extract the Uplink Control Information (UCI) bits (ACK/NACK, SR) from the received baseband signals. The core hardware modules include:

1.  **Input Buffer & Control Logic:** Manages the incoming I/Q data streams and synchronizes the processing pipeline.
2.  **Goertzel Algorithm Branch:** Efficiently computes specific Discrete Fourier Transform (DFT) terms to detect the presence of sequence cyclic shifts. Optimized for MAC (Multiply-Accumulate) operations to minimize DSP slice utilization.
3.  **Peak Detector:** Analyzes the output from the Goertzel branches to identify the index of the maximum energy, mapping it back to the transmitted UCI bits.



🧪 Verification Strategy
The verification process employs a strict Co-simulation approach to ensure bit-true and cycle-true accuracy:
Golden Model: MATLAB is used to generate realistic 5G NR baseband I/Q test vectors (including noise models) and compute the expected output.
RTL Simulation: The test vectors are fed into the SystemVerilog testbench and simulated using Xilinx Vivado.
Result Analysis: The RTL outputs (waveforms and text dumps) are compared against the MATLAB golden model to verify functional correctness and timing constraints.

📊 Synthesis & Performance Results
Target Clock Frequency: 122.88 MHz
LUTs Utilization: 5485 (0.46%)
DSP Slices: 104
BRAM: 18.50
