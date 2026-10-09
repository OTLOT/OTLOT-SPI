//=============================================================================
// File        : spi_master_top.v
// Project     : SPI_Master_Controller
// Language    : Verilog-2001 (synthesizable)
// Description : Pad-facing top level for synthesis / place & route.
//
//   This is the module that is given to
//       * Vivado   (Xilinx FPGA flow)          -> spi_master.xdc
//       * Genus    (Cadence ASIC synthesis)    -> spi_master.sdc
//       * Innovus  (Cadence P&R)
//
//   Hierarchy
//       spi_master_top
//         +-- spi_master_controller
//               +-- spi_fsm
//               +-- spi_clock_generator
//               +-- spi_shift_register
//
//   NOTE : spi_miso is NOT re-synchronised.  The external slave launches
//          MISO on the SCLK edge opposite to the master sampling edge, so
//          MISO is already stable when it is captured.  Adding a 2-FF
//          synchroniser here would break the SPI timing relationship.
//=============================================================================

`timescale 1ns/1ps

module spi_master_top #(
    parameter integer DATA_WIDTH = 8,       // 8 / 16 / 32
    parameter integer CNT_WIDTH  = 16
) (
    // ---- system -------------------------------------------------------
    input  wire                  clk,
    input  wire                  rst_n,

    // ---- control / configuration --------------------------------------
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire [CNT_WIDTH-1:0]  clk_divider,
    input  wire                  cpol,
    input  wire                  cpha,

    // ---- SPI serial interface -----------------------------------------
    input  wire                  spi_miso,
    output wire                  spi_sclk,
    output wire                  spi_mosi,
    output wire                  spi_cs_n,

    // ---- status -------------------------------------------------------
    output wire                  busy,
    output wire                  done,
    output wire [DATA_WIDTH-1:0] rx_data
);

    // Core controller instantiation
    spi_master_controller #(
        .DATA_WIDTH (DATA_WIDTH),
        .CNT_WIDTH  (CNT_WIDTH)
    ) u_spi_master_controller (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .tx_data     (tx_data),
        .clk_divider (clk_divider),
        .cpol        (cpol),
        .cpha        (cpha),
        .spi_miso    (spi_miso),
        .busy        (busy),
        .done        (done),
        .rx_data     (rx_data),
        .spi_sclk    (spi_sclk),
        .spi_mosi    (spi_mosi),
        .spi_cs_n    (spi_cs_n)
    );

endmodule