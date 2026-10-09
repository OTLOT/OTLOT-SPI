//=============================================================================
// File        : spi_fsm.v
// Project     : SPI_Master_Controller
// Language    : Verilog-2001 (synthesizable)
// Description : SPI protocol controller (Moore style state machine).
//
//   IDLE     : CS_N = 1, SCLK = CPOL, waiting for `start`
//   LOAD     : CS_N = 0, shift register parallel-load, busy = 1
//   TRANSFER : CS_N = 0, clock generator enabled, busy = 1
//   DONE     : CS_N = 1, done = 1 (single cycle pulse)
//
//   The FSM is a pure controller - it contains no datapath.
//=============================================================================

`timescale 1ns/1ps

module spi_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire start,        // pulse/high level request for a new transfer
    input  wire last_edge,    // from spi_clock_generator : final SCLK edge
    output reg  cs_n,         // chip select (active low)
    output reg  load,         // parallel load enable for shift registers
    output reg  enable,       // enables the clock generator
    output reg  busy,         // transfer in progress
    output reg  done          // single-cycle completion pulse
);

    // State encoding (binary - small, fast, easy to decode)
    localparam [1:0] S_IDLE     = 2'b00;
    localparam [1:0] S_LOAD     = 2'b01;
    localparam [1:0] S_TRANSFER = 2'b10;
    localparam [1:0] S_DONE     = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // Next-state logic (fully combinational, no latches - default assigned)
    always @(*) begin
        next_state = state;                 // default : hold
        case (state)
            S_IDLE     : if (start)     next_state = S_LOAD;
            S_LOAD     :                next_state = S_TRANSFER;
            S_TRANSFER : if (last_edge) next_state = S_DONE;
            S_DONE     :                next_state = S_IDLE;
            default    :                next_state = S_IDLE;
        endcase
    end

    // Output logic (Moore - all outputs are a function of `state` only)
    always @(*) begin
        cs_n   = 1'b1;
        load   = 1'b0;
        enable = 1'b0;
        busy   = 1'b0;
        done   = 1'b0;

        case (state)
            S_IDLE     : begin
                cs_n = 1'b1;
            end
            S_LOAD     : begin
                cs_n = 1'b0;
                load = 1'b1;
                busy = 1'b1;
            end
            S_TRANSFER : begin
                cs_n   = 1'b0;
                enable = 1'b1;
                busy   = 1'b1;
            end
            S_DONE     : begin
                cs_n = 1'b1;
                done = 1'b1;
            end
            default    : begin
                cs_n = 1'b1;
            end
        endcase
    end

endmodule