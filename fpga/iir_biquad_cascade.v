// =============================================================================
// iir_biquad_cascade.v
// 4th-order Butterworth low-pass (fs = 10 kHz, fc = 1 kHz) built as TWO cascaded
// 2nd-order sections (biquads), Direct Form I, 16-bit fixed point.
//
//   Data      : signed Q1.15  (1 sign bit, 15 fractional bits)   range [-1, 1)
//   Coeffs    : signed Q2.14  (2 integer bits incl. sign, 14 fractional bits)
//   Products  : Q3.29 (32 bit), accumulator 36 bit (no overflow possible)
//   Output    : round-to-nearest, then saturate to 16 bit
//
// One shared multiplier is reused for all 10 multiply-accumulates of a sample
// (resource sharing).  A sample takes 33 clock cycles, so any sample rate up to
// 50 MHz / 33 = 1.5 MHz is possible; the project uses 10 kHz (5000 cycles).
//
// y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]   (per section)
// =============================================================================
module iir_biquad_cascade (
    input  wire               clk,
    input  wire               rst_n,       // active-low synchronous reset
    input  wire               sample_en,   // 1-cycle pulse: x_in holds a new sample
    input  wire signed [15:0] x_in,        // Q1.15
    output reg  signed [15:0] y_out,       // Q1.15
    output reg                y_valid      // 1-cycle pulse: y_out is new
);
    localparam integer CF = 14;            // coefficient fractional bits

    // ---- Coefficients (Q2.14 integers = round(value * 2^14)) -----------------
    // Section 0: poles 0.6605 +/- 0.4433j   (a1 = -1.3209, a2 = 0.6327)
    localparam signed [15:0] S0_B0 =  16'sd1138;
    localparam signed [15:0] S0_B1 =  16'sd2276;
    localparam signed [15:0] S0_B2 =  16'sd1138;
    localparam signed [15:0] S0_A1 = -16'sd21642;
    localparam signed [15:0] S0_A2 =  16'sd10367;
    // Section 1: poles 0.5243 +/- 0.1458j   (a1 = -1.0486, a2 = 0.2961)
    localparam signed [15:0] S1_B0 =  16'sd1138;
    localparam signed [15:0] S1_B1 =  16'sd2276;
    localparam signed [15:0] S1_B2 =  16'sd1138;
    localparam signed [15:0] S1_A1 = -16'sd17180;
    localparam signed [15:0] S1_A2 =  16'sd4852;

    // ---- State (delay registers of each section) -----------------------------
    reg signed [15:0] x1_0, x2_0, y1_0, y2_0;   // section 0
    reg signed [15:0] x1_1, x2_1, y1_1, y2_1;   // section 1

    // ---- Control --------------------------------------------------------------
    localparam [1:0] IDLE = 2'd0, MAC = 2'd1, FIN = 2'd2;
    reg [1:0]  state;
    reg [1:0]  ph;          // MAC micro-phase: 0 load, 1 multiply, 2 accumulate
    reg [2:0]  k;           // tap index 0..4  (b0, b1, b2, a1, a2)
    reg        sec;         // section index 0/1
    reg signed [15:0] sec_in;   // input of the section being computed
    reg signed [15:0] op_r, cf_r;
    reg signed [31:0] prod_r;
    reg signed [35:0] acc;

    // ---- Operand and coefficient selection -----------------------------------
    wire signed [15:0] x1_s = sec ? x1_1 : x1_0;
    wire signed [15:0] x2_s = sec ? x2_1 : x2_0;
    wire signed [15:0] y1_s = sec ? y1_1 : y1_0;
    wire signed [15:0] y2_s = sec ? y2_1 : y2_0;

    wire signed [15:0] operand = (k == 3'd0) ? sec_in :
        (k == 3'd1) ? x1_s   :
        (k == 3'd2) ? x2_s   :
        (k == 3'd3) ? y1_s   : y2_s;

    reg signed [15:0] coef_sel;
    always @* begin
        case ({sec, k})
            4'b0_000: coef_sel = S0_B0;
            4'b0_001: coef_sel = S0_B1;
            4'b0_010: coef_sel = S0_B2;
            4'b0_011: coef_sel = S0_A1;
            4'b0_100: coef_sel = S0_A2;
            4'b1_000: coef_sel = S1_B0;
            4'b1_001: coef_sel = S1_B1;
            4'b1_010: coef_sel = S1_B2;
            4'b1_011: coef_sel = S1_A1;
            4'b1_100: coef_sel = S1_A2;
            default : coef_sel = 16'sd0;
        endcase
    end

    // ---- Round to nearest and saturate to Q1.15 ------------------------------
    wire signed [35:0] acc_rnd = acc + 36'sd8192;          // + 0.5 LSB (2^(CF-1))
    wire signed [35:0] acc_shr = acc_rnd >>> CF;           // drop 14 fractional bits
    wire signed [15:0] y_sat   = (acc_shr >  36'sd32767)  ?  16'sd32767 :
        (acc_shr < -36'sd32768)  ? -16'sd32768 :
        acc_shr[15:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE; ph <= 2'd0; k <= 3'd0; sec <= 1'b0;
            sec_in <= 16'sd0; op_r <= 16'sd0; cf_r <= 16'sd0;
            prod_r <= 32'sd0; acc <= 36'sd0;
            x1_0 <= 16'sd0; x2_0 <= 16'sd0; y1_0 <= 16'sd0; y2_0 <= 16'sd0;
            x1_1 <= 16'sd0; x2_1 <= 16'sd0; y1_1 <= 16'sd0; y2_1 <= 16'sd0;
            y_out <= 16'sd0; y_valid <= 1'b0;
        end else begin
            y_valid <= 1'b0;
            case (state)
                IDLE: if (sample_en) begin
                    sec <= 1'b0; k <= 3'd0; ph <= 2'd0;
                    acc <= 36'sd0; sec_in <= x_in; state <= MAC;
                end

                MAC: case (ph)
                    2'd0: begin                       // load operand + coefficient
                        op_r <= operand; cf_r <= coef_sel; ph <= 2'd1;
                    end
                    2'd1: begin                       // 16 x 16 signed multiply
                        prod_r <= op_r * cf_r; ph <= 2'd2;
                    end
                    default: begin                    // accumulate (feedback taps subtract)
                        acc <= (k < 3'd3) ? (acc + prod_r) : (acc - prod_r);
                        ph  <= 2'd0;
                        if (k == 3'd4) state <= FIN; else k <= k + 3'd1;
                    end
                endcase

                FIN: begin
                    if (sec == 1'b0) begin            // section 0 done -> start section 1
                        x2_0 <= x1_0; x1_0 <= sec_in;
                        y2_0 <= y1_0; y1_0 <= y_sat;
                        sec <= 1'b1; sec_in <= y_sat;
                        k <= 3'd0; ph <= 2'd0; acc <= 36'sd0; state <= MAC;
                    end else begin                    // section 1 done -> output
                        x2_1 <= x1_1; x1_1 <= sec_in;
                        y2_1 <= y1_1; y1_1 <= y_sat;
                        y_out <= y_sat; y_valid <= 1'b1; state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
