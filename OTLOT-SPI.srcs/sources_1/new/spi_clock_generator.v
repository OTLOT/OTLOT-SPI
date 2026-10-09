//=============================================================================
// File        : spi_clock_generator.v
// Project     : SPI_Master_Controller
// Language    : Verilog-2001 (synthesizable)
// Description : Generates the SPI shift clock (SCLK) from the system clock and
//               derives all internal edge qualifiers.
//
//  SCLK half-period = clk_divider * clk period.
//  Therefore        f_sclk = f_clk / (2 * clk_divider).
//
//  Edge numbering (edge_cnt):
//     0, 2, 4, ...  -> LEADING  edge  (first  edge after CS assertion)
//     1, 3, 5, ...  -> TRAILING edge  (second edge of each bit)
//
//  CPOL only changes the *polarity* of SCLK in idle state.  Because the first
//  toggle of SCLK is always the "leading" edge, the edge numbering is
//  independent of CPOL.  The data path uses CPHA to decide which of the two
//  edges performs "shift" and which performs "sample".
//
//     CPHA = 0 : sample on LEADING  edge, shift on TRAILING edge
//     CPHA = 1 : shift  on LEADING  edge, sample on TRAILING edge
//
//  Total number of SCLK edges in one transfer = 2 * DATA_WIDTH.
//  This guarantees SCLK finishes at its idle level (== CPOL) after the
//  last bit, so CS_N may be de-asserted safely.
//=============================================================================

`timescale 1ns/1ps

module spi_clock_generator #(
    parameter integer DATA_WIDTH = 8,       // 8 / 16 / 32
    parameter integer CNT_WIDTH  = 16       // clock divider counter width
) (
    input  wire                 clk,          // system clock
    input  wire                 rst_n,        // async active-low reset
    input  wire                 enable,       // high during TRANSFER state
    input  wire [CNT_WIDTH-1:0] clk_divider,  // SCLK half period in clk cycles
    input  wire                 cpol,         // clock polarity
    input  wire                 cpha,         // clock phase
    output reg                  sclk,         // SPI shift clock (registered)
    output wire                 shift_tick,   // 1 clk pulse : move MOSI / TX SR
    output wire                 sample_tick,  // 1 clk pulse : capture MISO
    output wire                 last_sample_tick, // 1 clk pulse : final MISO capture
    output wire                 last_edge     // 1 clk pulse : final SCLK edge
);

    // Constants
    localparam integer EDGE_LAST        = (2 * DATA_WIDTH) - 1; // last edge index
    localparam integer EDGE_LAST_SAMPLE = (2 * DATA_WIDTH) - 2; // >= last sample

    // Internal registers / wires
    reg  [CNT_WIDTH-1:0] div_cnt;    // half-period counter
    reg  [7:0]           edge_cnt;   // SCLK edge counter (0..2*DATA_WIDTH-1)

    wire [CNT_WIDTH-1:0] div_val;
    wire                 div_tick;      // half period expired
    wire                 leading_edge;
    wire                 trailing_edge;

    // Protect against clk_divider == 0 (treat as divide-by-1)
    assign div_val = (clk_divider == {CNT_WIDTH{1'b0}}) ?
                     { {(CNT_WIDTH-1){1'b0}}, 1'b1 } : clk_divider;

    // Half-period tick.  Registered logic reacts to this tick on the *next*
    // rising clock edge, which is exactly when SCLK toggles.
    assign div_tick = enable & (div_cnt == (div_val - 1'b1));

    // Programmable divider counter (free-running while enabled)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            div_cnt <= {CNT_WIDTH{1'b0}};
        else if (!enable)
            div_cnt <= {CNT_WIDTH{1'b0}};
        else if (div_tick)
            div_cnt <= {CNT_WIDTH{1'b0}};
        else
            div_cnt <= div_cnt + 1'b1;
    end

    // SCLK generation - registered output, always returns to CPOL when idle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sclk <= 1'b0;
        else if (!enable)
            sclk <= cpol;                 // idle level = CPOL
        else if (div_tick)
            sclk <= ~sclk;                // toggle every half period
    end

    // SCLK edge counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            edge_cnt <= 8'd0;
        else if (!enable)
            edge_cnt <= 8'd0;
        else if (div_tick)
            edge_cnt <= edge_cnt + 8'd1;
    end

    // Even index = leading edge, odd index = trailing edge
    assign leading_edge  = div_tick & ~edge_cnt[0];
    assign trailing_edge = div_tick &  edge_cnt[0];

    // CPHA controlled edge qualification
    assign shift_tick       = cpha ? leading_edge  : trailing_edge;
    assign sample_tick      = cpha ? trailing_edge : leading_edge;
    assign last_sample_tick = sample_tick & (edge_cnt >= EDGE_LAST_SAMPLE);
    assign last_edge        = div_tick   & (edge_cnt == EDGE_LAST);

endmodule