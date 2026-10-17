# Analysis of Finite Word Length Effects and Coefficient Quantization on Fixed-Point IIR Filter Stability

BAEVD204 Signal Processing lab project, Vellore Institute of Technology.

Authors: Vrinda Pandey (25BVD0126), Ayush Krishna Balabadra (25BVD0112)

## What this project does
We round the coefficients of a 4th-order Butterworth low-pass IIR filter (fs = 10 kHz, fc = 1 kHz) to 16 and 8 bits and study the effect on its poles, zeros, frequency response, stability and SQNR. We then compare the direct form with a cascade of biquads over a word-length sweep, build the cascade on a Cyclone IV E FPGA (Terasic DE2-115), and run a short experiment on rounding the weights of a small CNN (MNIST).

## Main results
- 16-bit and 8-bit coefficients: largest pole radius 0.7955 and 0.7968 (ideal 0.7954), both stable. SQNR 69.32 dB and 41.01 dB.
- The direct form is unstable at 4 and 5 bits. The cascade is stable at every word length and reaches 83.11 dB at 16 bits.
- FPGA: 79.31 dB SQNR, 541 logic elements, +12.646 ns slack at 50 MHz, Fmax 135.98 MHz.
- CNN: 97.81% accuracy with INT4 weights against 97.89% in FP32, with a model 8 times smaller. It fails below 4 bits.

## Folders
- `matlab/` : `main_quantization.m` (design, rounding, stability, SQNR) and `sweep_wordlength.m` (direct form vs cascade)
- `fpga/` : Verilog filter (`iir_biquad_cascade.v`, `iir_top.v`) and the timing constraint `sp_project.sdc`
- `cnn/` : `train_mnist.py` and `quantize_eval.py`
- `docs/` : project report and IEEE-style paper
- `results/` : figures

## How to run
- MATLAB: run `matlab/main_quantization.m`, then `matlab/sweep_wordlength.m`.
- FPGA: make a Quartus Prime project for the EP4CE115F29C7, set `iir_top` as the top level, add the `.v` files and `sp_project.sdc`, and import the DE2-115 pin assignments. The design also needs `sine_lut.hex` (1024 x 16-bit sine table), which is not in this repo yet.
- CNN: `pip install torch torchvision matplotlib`, then in the `cnn` folder run `python train_mnist.py` and `python quantize_eval.py`.
