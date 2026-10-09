//=============================================================================
// File        : spi_shift_register.v
// Project     : SPI_Master_Controller
// Language    : Verilog-2001 (synthesizable)
// Description : SPI TX / RX shift registers (MSB first).
//
//  TX path
//  -------
//   CPHA = 0 : the MSB is driven on MOSI at LOAD time.  On every shift_tick
//              (trailing edge) MOSI moves to the next bit.
//   CPHA = 1 : MOSI is "don't care" before the first leading edge.  On every
//              shift_tick (leading edge) the current MSB is driven on MOSI.
//
//   Both cases are unified with a registered MOSI output:
//        shift_tick :  mosi <= cpha ? tx_sr[MSB] : tx_sr[MSB-1]
//
//  RX path
//  -------
//   MISO is sampled on `sample_tick` and shifted in MSB-first.  The final
//   result is captured into `rx_data` on `last_sample_tick`, which coincides
//   with the last sampling edge, so rx_data is already valid when `done`
//   is asserted by the controller.
//=============================================================================

`timescale 1ns/1ps

module spi_shift_register #(
    parameter integer DATA_WIDTH = 8
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  load,             // parallel load (LOAD state)
    input  wire                  shift_tick,       // 1 clk pulse : shift out
    input  wire                  sample_tick,      // 1 clk pulse : capture MISO
    input  wire                  last_sample_tick, // 1 clk pulse : last capture
    input  wire                  cpha,
    input  wire [DATA_WIDTH-1:0] tx_data,          // parallel TX data
    input  wire                  spi_miso,         // serial input from slave
    output reg  [DATA_WIDTH-1:0] rx_data,          // parallel RX data
    output reg                   spi_mosi          // serial output to slave
);

    reg [DATA_WIDTH-1:0] tx_sr;   // transmit shift register
    reg [DATA_WIDTH-1:0] rx_sr;   // receive  shift register

    // TX shift register + registered MOSI
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_sr    <= {DATA_WIDTH{1'b0}};
            spi_mosi <= 1'b0;
        end
        else if (load) begin
            tx_sr    <= tx_data;
            // CPHA=0 : MSB must already be present before the 1st leading edge
            // CPHA=1 : MOSI is don't-care until the 1st leading edge
            spi_mosi <= cpha ? 1'b0 : tx_data[DATA_WIDTH-1];
        end
        else if (shift_tick) begin
            tx_sr    <= {tx_sr[DATA_WIDTH-2:0], 1'b0};
            // CPHA=1 : present old MSB now (it becomes the bit for this phase)
            // CPHA=0 : present next bit (old bit MSB-1) after the trailing edge
            spi_mosi <= cpha ? tx_sr[DATA_WIDTH-1] : tx_sr[DATA_WIDTH-2];
        end
    end

    // RX shift register (MSB first)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sr <= {DATA_WIDTH{1'b0}};
        else if (load)
            rx_sr <= {DATA_WIDTH{1'b0}};
        else if (sample_tick)
            rx_sr <= {rx_sr[DATA_WIDTH-2:0], spi_miso};
    end

    // Final RX capture - same clock edge as the last sample, therefore
    // rx_data is stable at the same time `done` becomes visible.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_data <= {DATA_WIDTH{1'b0}};
        else if (last_sample_tick)
            rx_data <= {rx_sr[DATA_WIDTH-2:0], spi_miso};
    end

endmodule