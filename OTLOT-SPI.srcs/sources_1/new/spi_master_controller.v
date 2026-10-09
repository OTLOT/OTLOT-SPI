//=============================================================================
// File        : spi_master_controller.v
// Project     : SPI_Master_Controller
// Language    : Verilog-2001 (synthesizable)
// Description : SPI Master core.  Instantiates the controller (FSM), the
//               clock generator and the datapath (shift registers).
//
//   Supported SPI modes
//     Mode 0 : CPOL=0 CPHA=0
//     Mode 1 : CPOL=0 CPHA=1
//     Mode 2 : CPOL=1 CPHA=0
//     Mode 3 : CPOL=1 CPHA=1
//
//   Data width (parameter) : 8, 16 or 32 bits.  MSB first.
//   Clock divider          : f_sclk = f_clk / (2 * clk_divider)
//
//   Hand-shake
//     - pulse/hold `start` while `busy` = 0
//     - `busy` goes high for the duration of the transfer
//     - `done` pulses for exactly one clk cycle
//     - `rx_data` is valid from `done` until the next `start`
//=============================================================================

`timescale 1ns/1ps

module spi_master_controller #(
    parameter integer DATA_WIDTH = 8,       // 8 / 16 / 32
    parameter integer CNT_WIDTH  = 16       // clk divider counter width
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire [CNT_WIDTH-1:0]  clk_divider,
    input  wire                  cpol,
    input  wire                  cpha,
    input  wire                  spi_miso,
    output wire                  busy,
    output wire                  done,
    output wire [DATA_WIDTH-1:0] rx_data,
    output wire                  spi_sclk,
    output wire                  spi_mosi,
    output wire                  spi_cs_n
);

    // Internal interconnect
    wire load;
    wire enable;
    wire cs_n_int;
    wire shift_tick;
    wire sample_tick;
    wire last_sample_tick;
    wire last_edge;

    // Controller
    spi_fsm u_spi_fsm (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .last_edge (last_edge),
        .cs_n      (cs_n_int),
        .load      (load),
        .enable    (enable),
        .busy      (busy),
        .done      (done)
    );

    // Serial clock generator
    spi_clock_generator #(
        .DATA_WIDTH (DATA_WIDTH),
        .CNT_WIDTH  (CNT_WIDTH)
    ) u_spi_clock_generator (
        .clk              (clk),
        .rst_n            (rst_n),
        .enable           (enable),
        .clk_divider      (clk_divider),
        .cpol             (cpol),
        .cpha             (cpha),
        .sclk             (spi_sclk),
        .shift_tick       (shift_tick),
        .sample_tick      (sample_tick),
        .last_sample_tick (last_sample_tick),
        .last_edge        (last_edge)
    );

    // Datapath
    spi_shift_register #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_spi_shift_register (
        .clk              (clk),
        .rst_n            (rst_n),
        .load             (load),
        .shift_tick       (shift_tick),
        .sample_tick      (sample_tick),
        .last_sample_tick (last_sample_tick),
        .cpha             (cpha),
        .tx_data          (tx_data),
        .spi_miso         (spi_miso),
        .rx_data          (rx_data),
        .spi_mosi         (spi_mosi)
    );

    // Chip-select output
    assign spi_cs_n = cs_n_int;

endmodule