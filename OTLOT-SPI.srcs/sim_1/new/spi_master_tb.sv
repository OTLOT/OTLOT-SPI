//=============================================================================
// File        : spi_master_tb.sv
// Project     : SPI_Master_Controller
// Language    : SystemVerilog (verification only - NOT synthesizable)
// Description : Self-checking testbench.
//
//   * behavioural SPI slave model (drives MISO, samples MOSI)
//   * scoreboard (automatic pass/fail)
//   * SVA assertions
//   * functional coverage
//   * 11 test cases as required
//=============================================================================

`timescale 1ns/1ps

//=============================================================================
// SPI SLAVE MODEL
//   Mirrors the master exactly:
//     CPHA=0 : sample MOSI on leading  edge, drive MISO on trailing edge
//              first MISO bit driven when CS_N falls
//     CPHA=1 : drive MISO on leading  edge, sample MOSI on trailing edge
//=============================================================================
module spi_slave_model #(
    parameter integer DW = 8
) (
    input  wire             sclk,
    input  wire             cs_n,
    input  wire             cpol,
    input  wire             cpha,
    input  wire             mosi,
    input  wire [DW-1:0]    slave_tx_data,
    output wire [DW-1:0]    slave_rx_data,
    output reg              miso
);

    reg [DW-1:0] sr_tx;
    reg [DW-1:0] sr_rx;

    assign slave_rx_data = sr_rx;    // combinational view - no capture race

    // Drive the next MISO bit
    task automatic drive_next_bit;
        begin
            if (cpha == 1'b1) begin
                miso  <= sr_tx[DW-1];
                sr_tx <= {sr_tx[DW-2:0], 1'b0};
            end
            else begin
                sr_tx <= {sr_tx[DW-2:0], 1'b0};
                miso  <= sr_tx[DW-2];
            end
        end
    endtask

    // Sample MOSI into the RX shift register
    task automatic sample_mosi;
        begin
            sr_rx <= {sr_rx[DW-2:0], mosi};
        end
    endtask

    // CS assertion : pre-load, pre-drive first bit for CPHA = 0
    always @(negedge cs_n) begin
        sr_tx <= slave_tx_data;
        sr_rx <= {DW{1'b0}};
        if (cpha == 1'b0)
            miso <= slave_tx_data[DW-1];
        else
            miso <= 1'b0;
    end

    // SCLK rising edge
    always @(posedge sclk) begin
        if (cs_n == 1'b0) begin
            if (cpol == 1'b0) begin         // rising = leading
                if (cpha == 1'b1) drive_next_bit;
                else              sample_mosi;
            end
            else begin                      // rising = trailing
                if (cpha == 1'b1) sample_mosi;
                else              drive_next_bit;
            end
        end
    end

    // SCLK falling edge
    always @(negedge sclk) begin
        if (cs_n == 1'b0) begin
            if (cpol == 1'b1) begin         // falling = leading
                if (cpha == 1'b1) drive_next_bit;
                else              sample_mosi;
            end
            else begin                      // falling = trailing
                if (cpha == 1'b1) sample_mosi;
                else              drive_next_bit;
            end
        end
    end

endmodule


// SPI AGENT : DUT + slave model + transfer task + assertions
module spi_agent #(
    parameter integer DW = 8
) (
    input  logic clk,
    input  logic rst_n
);

    // DUT interface signals
    logic              start;
    logic [DW-1:0]     tx_data;
    logic [15:0]       clk_divider;
    logic              cpol;
    logic              cpha;
    logic              busy;
    logic              done;
    logic [DW-1:0]     rx_data;
    logic              sclk;
    logic              mosi;
    logic              cs_n;
    logic              miso;

    logic [DW-1:0]     slave_tx_data;
    logic [DW-1:0]     slave_rx_data;

    // DUT
    spi_master_top #(
        .DATA_WIDTH (DW),
        .CNT_WIDTH  (16)
    ) u_dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .tx_data     (tx_data),
        .clk_divider (clk_divider),
        .cpol        (cpol),
        .cpha        (cpha),
        .spi_miso    (miso),
        .spi_sclk    (sclk),
        .spi_mosi    (mosi),
        .spi_cs_n    (cs_n),
        .busy        (busy),
        .done        (done),
        .rx_data     (rx_data)
    );

    // Slave model
    spi_slave_model #(
        .DW (DW)
    ) u_slave (
        .sclk          (sclk),
        .cs_n          (cs_n),
        .cpol          (cpol),
        .cpha          (cpha),
        .mosi          (mosi),
        .slave_tx_data (slave_tx_data),
        .slave_rx_data (slave_rx_data),
        .miso          (miso)
    );

    //------------------------------------------------------------------
    // Re-usable transfer task
    //   tx      : master transmit data
    //   slv_tx  : slave  transmit data (= expected master receive data)
    //   div     : clk_divider value
    //   m_cpol  : CPOL
    //   m_cpha  : CPHA
    //   ok      : 1 if both directions matched
    //------------------------------------------------------------------
    task automatic run_transfer (
        input  logic [DW-1:0] tx,
        input  logic [DW-1:0] slv_tx,
        input  logic [15:0]   div,
        input  logic          m_cpol,
        input  logic          m_cpha,
        output logic          ok
    );
        logic [DW-1:0] exp_rx;
        begin
            exp_rx        = slv_tx;

            tx_data       = tx;
            slave_tx_data = slv_tx;
            clk_divider   = div;
            cpol          = m_cpol;
            cpha          = m_cpha;
            start         = 1'b0;

            repeat (2) @(posedge clk);

            start <= 1'b1;              // NBA - avoids TB/DUT race
            @(posedge clk);
            start <= 1'b0;
            @(posedge clk);

            wait (done === 1'b1);       // wait for completion pulse
            repeat (4) @(posedge clk);  // settle

            ok = (rx_data       === exp_rx) &&
                 (slave_rx_data === tx)     &&
                 (cs_n          === 1'b1);
        end
    endtask

    // SVA assertions
    property p_done_not_busy;
        @(posedge clk) disable iff (!rst_n) done |-> !busy;
    endproperty

    property p_start_busy;
        @(posedge clk) disable iff (!rst_n) (start && !busy) |=> busy;
    endproperty

    property p_cs_low_when_busy;
        @(posedge clk) disable iff (!rst_n) busy |-> !cs_n;
    endproperty

    property p_cs_high_when_idle;
        @(posedge clk) disable iff (!rst_n) (!busy && !done) |-> cs_n;
    endproperty

    property p_done_pulse;
        @(posedge clk) disable iff (!rst_n) done |=> !done;
    endproperty

    property p_sclk_idle_level;
        @(posedge clk) disable iff (!rst_n) (!busy && !done) |-> (sclk == cpol);
    endproperty

    A_DONE_NOT_BUSY  : assert property (p_done_not_busy)
        else $error("[%m] done asserted while busy is high");
    A_START_BUSY     : assert property (p_start_busy)
        else $error("[%m] busy did not assert after start");
    A_CS_LOW_BUSY    : assert property (p_cs_low_when_busy)
        else $error("[%m] cs_n high while busy");
    A_CS_HIGH_IDLE   : assert property (p_cs_high_when_idle)
        else $error("[%m] cs_n low while idle");
    A_DONE_PULSE     : assert property (p_done_pulse)
        else $error("[%m] done is not a single-cycle pulse");
    A_SCLK_IDLE      : assert property (p_sclk_idle_level)
        else $error("[%m] sclk not at CPOL while idle");

endmodule


// TOP TESTBENCH
module spi_master_tb;

    // Clock / reset
    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5 clk = ~clk;              // 100 MHz  (10 ns period)

    // Scoreboard
    int pass_cnt = 0;
    int fail_cnt = 0;

    // Coverage sampling variables
    int  width_cp = 8;
    int  div_cp   = 4;
    int  mode_cp  = 0;
    int  data_cp  = 0;

    covergroup cg_spi;
        option.per_instance = 1;

        cp_mode : coverpoint mode_cp {
            bins mode0 = {0};
            bins mode1 = {1};
            bins mode2 = {2};
            bins mode3 = {3};
        }
        cp_div : coverpoint div_cp {
            bins div_1      = {1};
            bins div_2      = {2};
            bins div_small  = {[3:8]};
            bins div_medium = {[9:32]};
            bins div_large  = {[33:256]};
        }
        cp_width : coverpoint width_cp {
            bins w8  = {8};
            bins w16 = {16};
            bins w32 = {32};
        }
        cp_data : coverpoint data_cp {
            bins all_zero = {8'h00};
            bins all_one  = {8'hFF};
            bins alt_aa   = {8'hAA};
            bins alt_55   = {8'h55};
            bins others   = default;
        }
        cx_mode_div   : cross cp_mode, cp_div;
        cx_mode_width : cross cp_mode, cp_width;
    endgroup

    cg_spi cg_inst = new();

    // Agents (one per supported data width)
    spi_agent #(8)  u_ag8  (.clk(clk), .rst_n(rst_n));
    spi_agent #(16) u_ag16 (.clk(clk), .rst_n(rst_n));
    spi_agent #(32) u_ag32 (.clk(clk), .rst_n(rst_n));

    // Helper : scoreboard check
    task automatic check (input string name, input logic ok);
        if (ok) begin
            pass_cnt++;
            $display("[%0t] PASS : %s", $time, name);
        end
        else begin
            fail_cnt++;
            $display("[%0t] FAIL : %s", $time, name);
        end
    endtask

    // Global watchdog
    initial begin
        #20_000_000;
        $display("[%0t] ERROR : simulation timeout", $time);
        $finish;
    end

    // Main test sequence
    logic t_ok;
    int   i;
    byte unsigned tx_b;
    byte unsigned rx_b;
    int   div_r;
    int   mode_r;

    initial begin
        $display("");
        $display("================================================================");
        $display(" SPI MASTER CONTROLLER - SELF CHECKING TESTBENCH");
        $display("================================================================");

        // Defaults for all agents
        u_ag8.start         = 1'b0;  u_ag8.tx_data       = 8'h00;
        u_ag8.clk_divider   = 16'd4; u_ag8.cpol          = 1'b0;
        u_ag8.cpha          = 1'b0;  u_ag8.slave_tx_data = 8'h00;

        u_ag16.start        = 1'b0;  u_ag16.tx_data      = 16'h0000;
        u_ag16.clk_divider  = 16'd4; u_ag16.cpol         = 1'b0;
        u_ag16.cpha         = 1'b0;  u_ag16.slave_tx_data= 16'h0000;

        u_ag32.start        = 1'b0;  u_ag32.tx_data      = 32'h0000_0000;
        u_ag32.clk_divider  = 16'd4; u_ag32.cpol         = 1'b0;
        u_ag32.cpha         = 1'b0;  u_ag32.slave_tx_data= 32'h0000_0000;

        // TEST 1 : Reset Test
        $display("\n--- TEST 1 : Reset Test ---");
        rst_n = 1'b0;
        repeat (10) @(posedge clk);

        check("TEST1 : cs_n high during reset", u_ag8.cs_n  === 1'b1);
        check("TEST1 : busy low during reset",  u_ag8.busy  === 1'b0);
        check("TEST1 : done low during reset",  u_ag8.done  === 1'b0);
        check("TEST1 : sclk = CPOL during reset", u_ag8.sclk === 1'b0);
        check("TEST1 : rx_data cleared",        u_ag8.rx_data === 8'h00);
        check("TEST1 : mosi low",               u_ag8.mosi  === 1'b0);

        rst_n = 1'b1;
        repeat (5) @(posedge clk);
        $display("  -> reset released");

        // TEST 2 : SPI Mode 0
        $display("\n--- TEST 2 : SPI Mode 0 (CPOL=0, CPHA=0) ---");
        u_ag8.run_transfer(8'hA5, 8'h3C, 16'd4, 1'b0, 1'b0, t_ok);
        check("TEST2 : Mode 0 8'hA5 <-> 8'h3C", t_ok);
        mode_cp = 0; div_cp = 4; width_cp = 8; data_cp = 8'hA5; cg_inst.sample();

        // TEST 3 : SPI Mode 1
        $display("\n--- TEST 3 : SPI Mode 1 (CPOL=0, CPHA=1) ---");
        u_ag8.run_transfer(8'h5A, 8'hC3, 16'd4, 1'b0, 1'b1, t_ok);
        check("TEST3 : Mode 1 8'h5A <-> 8'hC3", t_ok);
        mode_cp = 1; div_cp = 4; data_cp = 8'h5A; cg_inst.sample();

        // TEST 4 : SPI Mode 2
        $display("\n--- TEST 4 : SPI Mode 2 (CPOL=1, CPHA=0) ---");
        u_ag8.run_transfer(8'hFF, 8'h00, 16'd4, 1'b1, 1'b0, t_ok);
        check("TEST4 : Mode 2 8'hFF <-> 8'h00", t_ok);
        mode_cp = 2; div_cp = 4; data_cp = 8'hFF; cg_inst.sample();

        // TEST 5 : SPI Mode 3
        $display("\n--- TEST 5 : SPI Mode 3 (CPOL=1, CPHA=1) ---");
        u_ag8.run_transfer(8'h0F, 8'hF0, 16'd4, 1'b1, 1'b1, t_ok);
        check("TEST5 : Mode 3 8'h0F <-> 8'hF0", t_ok);
        mode_cp = 3; div_cp = 4; data_cp = 8'h0F; cg_inst.sample();

        // TEST 6 : Multiple back-to-back transfers
        $display("\n--- TEST 6 : Back-to-Back Transfers (8 x Mode 0) ---");
        for (i = 0; i < 8; i++) begin
            tx_b = i * 8'h11;
            rx_b = 8'hF0 + i;
            u_ag8.run_transfer(tx_b, rx_b, 16'd4, 1'b0, 1'b0, t_ok);
            check($sformatf("TEST6 : back-to-back #%0d tx=%02h rx=%02h",
                            i, tx_b, rx_b), t_ok);
        end
        cg_inst.sample();

        // TEST 7 : Random data transfers
        $display("\n--- TEST 7 : Random Data / Mode / Divider Transfers ---");
        for (i = 0; i < 24; i++) begin
            tx_b   = $urandom_range(255, 0);
            rx_b   = $urandom_range(255, 0);
            div_r  = $urandom_range(8, 1);
            mode_r = $urandom_range(3, 0);

            u_ag8.run_transfer(tx_b, rx_b, div_r[15:0],
                               mode_r[1], mode_r[0], t_ok);
            check($sformatf("TEST7 : rand #%0d mode=%0d div=%0d tx=%02h rx=%02h",
                            i, mode_r, div_r, tx_b, rx_b), t_ok);

            mode_cp = mode_r; div_cp = div_r; data_cp = tx_b; width_cp = 8;
            cg_inst.sample();
        end

        // TEST 8 : Clock divider variations
        $display("\n--- TEST 8 : Clock Divider Variations ---");
        u_ag8.run_transfer(8'h96, 8'h69, 16'd1,   1'b0, 1'b0, t_ok);
        check("TEST8 : clk_divider = 1",   t_ok); div_cp = 1;   cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd2,   1'b1, 1'b0, t_ok);
        check("TEST8 : clk_divider = 2",   t_ok); div_cp = 2;   cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd3,   1'b0, 1'b1, t_ok);
        check("TEST8 : clk_divider = 3",   t_ok); div_cp = 3;   cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd4,   1'b1, 1'b1, t_ok);
        check("TEST8 : clk_divider = 4",   t_ok); div_cp = 4;   cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd8,   1'b0, 1'b0, t_ok);
        check("TEST8 : clk_divider = 8",   t_ok); div_cp = 8;   cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd16,  1'b0, 1'b1, t_ok);
        check("TEST8 : clk_divider = 16",  t_ok); div_cp = 16;  cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd64,  1'b1, 1'b0, t_ok);
        check("TEST8 : clk_divider = 64",  t_ok); div_cp = 64;  cg_inst.sample();
        u_ag8.run_transfer(8'h96, 8'h69, 16'd128, 1'b1, 1'b1, t_ok);
        check("TEST8 : clk_divider = 128", t_ok); div_cp = 128; cg_inst.sample();

        // TEST 9 / 10 / 11 : 8 / 16 / 32-bit transfers, all modes
        $display("\n--- TEST 9 : 8-bit Transfers (all 4 modes) ---");
        width_cp = 8;
        u_ag8.run_transfer(8'h81, 8'h18, 16'd4, 1'b0, 1'b0, t_ok);
        check("TEST9 : 8-bit Mode 0", t_ok); mode_cp = 0; cg_inst.sample();
        u_ag8.run_transfer(8'h42, 8'h24, 16'd4, 1'b0, 1'b1, t_ok);
        check("TEST9 : 8-bit Mode 1", t_ok); mode_cp = 1; cg_inst.sample();
        u_ag8.run_transfer(8'h24, 8'h42, 16'd4, 1'b1, 1'b0, t_ok);
        check("TEST9 : 8-bit Mode 2", t_ok); mode_cp = 2; cg_inst.sample();
        u_ag8.run_transfer(8'h18, 8'h81, 16'd4, 1'b1, 1'b1, t_ok);
        check("TEST9 : 8-bit Mode 3", t_ok); mode_cp = 3; cg_inst.sample();

        $display("\n--- TEST 10 : 16-bit Transfers (all 4 modes) ---");
        width_cp = 16;
        u_ag16.run_transfer(16'hDEAD, 16'hBEEF, 16'd4, 1'b0, 1'b0, t_ok);
        check("TEST10 : 16-bit Mode 0", t_ok); mode_cp = 0; cg_inst.sample();
        u_ag16.run_transfer(16'hBEEF, 16'hDEAD, 16'd4, 1'b0, 1'b1, t_ok);
        check("TEST10 : 16-bit Mode 1", t_ok); mode_cp = 1; cg_inst.sample();
        u_ag16.run_transfer(16'h1234, 16'h5678, 16'd4, 1'b1, 1'b0, t_ok);
        check("TEST10 : 16-bit Mode 2", t_ok); mode_cp = 2; cg_inst.sample();
        u_ag16.run_transfer(16'h5678, 16'h1234, 16'd4, 1'b1, 1'b1, t_ok);
        check("TEST10 : 16-bit Mode 3", t_ok); mode_cp = 3; cg_inst.sample();

        $display("\n--- TEST 11 : 32-bit Transfers (all 4 modes) ---");
        width_cp = 32;
        u_ag32.run_transfer(32'hDEADBEEF, 32'hCAFEBABE, 16'd4, 1'b0, 1'b0, t_ok);
        check("TEST11 : 32-bit Mode 0", t_ok); mode_cp = 0; cg_inst.sample();
        u_ag32.run_transfer(32'hCAFEBABE, 32'hDEADBEEF, 16'd4, 1'b0, 1'b1, t_ok);
        check("TEST11 : 32-bit Mode 1", t_ok); mode_cp = 1; cg_inst.sample();
        u_ag32.run_transfer(32'h00000001, 32'h80000000, 16'd4, 1'b1, 1'b0, t_ok);
        check("TEST11 : 32-bit Mode 2", t_ok); mode_cp = 2; cg_inst.sample();
        u_ag32.run_transfer(32'h80000000, 32'h00000001, 16'd4, 1'b1, 1'b1, t_ok);
        check("TEST11 : 32-bit Mode 3", t_ok); mode_cp = 3; cg_inst.sample();

        // Extra : walking-1 / walking-0 patterns (corner cases)
        $display("\n--- EXTRA : Walk-1 / Walk-0 patterns ---");
        for (i = 0; i < 8; i++) begin
            tx_b = 8'h01 << i;
            rx_b = ~(8'h01 << i);
            u_ag8.run_transfer(tx_b, rx_b, 16'd4, 1'b0, 1'b0, t_ok);
            check($sformatf("EXTRA : walk-1 bit %0d", i), t_ok);
        end

        // Coverage report + summary
        $display("");
        $display("================================================================");
        $display(" FUNCTIONAL COVERAGE");
        $display("================================================================");
        $display(" Overall coverage = %0.2f %%", cg_inst.get_coverage());
        cg_inst.cp_mode.  get_coverage();
        $display("  mode coverage    = %0.2f %%", cg_inst.cp_mode.get_coverage());
        $display("  divider coverage = %0.2f %%", cg_inst.cp_div.get_coverage());
        $display("  width coverage   = %0.2f %%", cg_inst.cp_width.get_coverage());
        $display("  data coverage    = %0.2f %%", cg_inst.cp_data.get_coverage());

        $display("");
        $display("================================================================");
        $display(" TEST SUMMARY");
        $display("================================================================");
        $display("  PASSED : %0d", pass_cnt);
        $display("  FAILED : %0d", fail_cnt);
        if (fail_cnt == 0)
            $display("  RESULT : *** ALL TESTS PASSED ***");
        else
            $display("  RESULT : *** %0d TEST(S) FAILED ***", fail_cnt);
        $display("================================================================");
        $display("");

        $finish;
    end

endmodule