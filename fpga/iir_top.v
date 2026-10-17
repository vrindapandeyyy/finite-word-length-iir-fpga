// =============================================================================
// iir_top.v  -  Top level for Terasic DE2-115 (Cyclone IV E EP4CE115F29C7)
//
//   Two-tone test source  ->  4th-order Butterworth (2 biquads)  ->  LED bars
//
//   Test source : 0.5*sin(2*pi*400*n/fs) + 0.25*sin(2*pi*3000*n/fs)   (fs = 10 kHz)
//   Filter      : fc = 1 kHz, so the 400 Hz tone passes and the 3 kHz tone is
//                 attenuated by about 50 dB.
//
//   KEY[0]  : reset (active low)
//   SW[0]   : 0 = real time, fs = 10 kHz     (use SignalTap / simulation to look)
//             1 = slow motion, fs = 10 Hz    (tones appear at 0.4 Hz and 3 Hz)
//   LEDG[8:0]  : bar graph of the filter INPUT  (two tones: wobble visible)
//   LEDR[17:0] : bar graph of the filter OUTPUT (clean slow sine)
//
//   Needs sine_lut.hex in the Quartus project folder (1024 x 16-bit, hex).
// =============================================================================
module iir_top #(
    parameter integer FAST_DIV = 5000,      // 50 MHz / 5000      = 10 kHz
    parameter integer SLOW_DIV = 5000000    // 50 MHz / 5,000,000 = 10 Hz
)(
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire [17:0] LEDR,
    output wire [8:0]  LEDG
);
    // ---- Synchronise the asynchronous inputs ---------------------------------
    reg [1:0] rst_sync, slow_sync;
    always @(posedge CLOCK_50) begin
        rst_sync  <= {rst_sync[0],  KEY[0]};
        slow_sync <= {slow_sync[0], SW[0]};
    end
    wire rst_n = rst_sync[1];
    wire slow  = slow_sync[1];

    // ---- Sample tick generator ------------------------------------------------
    reg [22:0] cnt;
    reg        tick;
    wire [22:0] div_m1 = slow ? (SLOW_DIV - 1) : (FAST_DIV - 1);
    always @(posedge CLOCK_50) begin
        if (!rst_n) begin
            cnt <= 23'd0; tick <= 1'b0;
        end else if (cnt >= div_m1) begin
            cnt <= 23'd0; tick <= 1'b1;
        end else begin
            cnt <= cnt + 23'd1; tick <= 1'b0;
        end
    end

    // ---- Two-tone source: two phase accumulators + one sine ROM ---------------
    localparam [31:0] INC1 = 32'd171798692;     // 0.04 * 2^32  -> 400 Hz  at fs = 10 kHz
    localparam [31:0] INC2 = 32'd1288490189;    // 0.30 * 2^32  -> 3000 Hz at fs = 10 kHz
    reg [31:0] ph1, ph2;
    always @(posedge CLOCK_50) begin
        if (!rst_n) begin ph1 <= 32'd0; ph2 <= 32'd0; end
        else if (tick) begin ph1 <= ph1 + INC1; ph2 <= ph2 + INC2; end
    end

    reg signed [15:0] lut [0:1023];
    initial $readmemh("sine_lut.hex", lut);

    reg signed [15:0] s1, s2, x_mix;
    always @(posedge CLOCK_50) begin
        s1    <= lut[ph1[31:22]];
        s2    <= lut[ph2[31:22]];
        x_mix <= (s1 >>> 1) + (s2 >>> 2);       // 0.5*tone1 + 0.25*tone2 (Q1.15)
    end

    // Delay the tick by 3 clocks so x_mix is valid when the filter latches it.
    reg [2:0] tick_sr;
    always @(posedge CLOCK_50) tick_sr <= {tick_sr[1:0], tick};
    wire sample_en = tick_sr[2];

    // ---- The filter -----------------------------------------------------------
    wire signed [15:0] y_out;
    wire               y_valid;
    iir_biquad_cascade u_iir (
    .clk(CLOCK_50), .rst_n(rst_n),
    .sample_en(sample_en), .x_in(x_mix),
    .y_out(y_out), .y_valid(y_valid)
    );

    // ---- LED bar graphs (offset-binary, then scale to 0..17 / 0..8) -----------
    wire [15:0] y_u = y_out ^ 16'h8000;
    wire [15:0] x_u = x_mix ^ 16'h8000;
    wire [20:0] y_scaled = y_u * 5'd18;
    wire [19:0] x_scaled = x_u * 4'd9;
    wire [4:0]  y_lvl = y_scaled[20:16];        // 0..17
    wire [3:0]  x_lvl = x_scaled[19:16];        // 0..8

    genvar i;
    generate
        for (i = 0; i < 18; i = i + 1) begin : g_r
            assign LEDR[i] = (y_lvl >= i);
        end
        for (i = 0; i < 9; i = i + 1) begin : g_g
            assign LEDG[i] = (x_lvl >= i);
        end
    endgenerate
endmodule
