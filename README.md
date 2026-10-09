# SPI Master Controller — RTL + Verification Project

Fully synthesizable **Verilog-2001** SPI Master Controller with a
self-checking **SystemVerilog** testbench. Target flows:

* Xilinx **Vivado** (FPGA) — `spi_master.xdc`
* Cadence **Genus** (ASIC synthesis) — `spi_master.sdc`
* Cadence **Innovus** (Place & Route) — `spi_master.sdc`

---

## 1. Feature Summary

| Feature | Value |
|---|---|
| Design name | `SPI_Master_Controller` |
| Language | Verilog-2001 (RTL) / SystemVerilog (TB) |
| SPI modes | 0, 1, 2, 3 (CPOL × CPHA) |
| Data width | 8 / 16 / 32 bits (parameter `DATA_WIDTH`) |
| Bit order | MSB first |
| Clock divider | `f_sclk = f_clk / (2 × clk_divider)` |
| Architecture | FSM + separate datapath (shift registers) |
| Reset | asynchronous assert, synchronous release behaviour |
| Synthesis | no `#` delays, no vendor primitives, no latches |

---

## 2. File List

| # | File | Description |
|---|---|---|
| 1 | `spi_master_controller.v` | SPI core (controller + datapath + clock gen) |
| 2 | `spi_clock_generator.v` | SCLK generation + edge qualifiers |
| 3 | `spi_fsm.v` | IDLE / LOAD / TRANSFER / DONE state machine |
| 4 | `spi_shift_register.v` | TX/RX shift registers, registered MOSI |
| 5 | `spi_master_top.v` | Pad-facing top level |
| 6 | `spi_master_tb.sv` | Self-checking testbench |
| 7 | `spi_master.xdc` | Vivado constraints |
| 8 | `spi_master.sdc` | ASIC timing constraints |
| 9 | `run_simulation.tcl` | XSim simulation script |
| 10 | `synthesis.tcl` | Vivado synthesis script |
| 11 | `README.md` | This document |

---

## 3. Port Description

### `spi_master_top`

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | System clock (100 MHz) |
| `rst_n` | in | 1 | Asynchronous active-low reset |
| `start` | in | 1 | Start a transfer (assert when `busy` = 0) |
| `tx_data` | in | `DATA_WIDTH` | Parallel transmit data (MSB first) |
| `clk_divider` | in | 16 | SCLK half period in clk cycles (min 1) |
| `cpol` | in | 1 | Clock polarity |
| `cpha` | in | 1 | Clock phase |
| `spi_miso` | in | 1 | Master-in / slave-out |
| `busy` | out | 1 | Transfer in progress |
| `done` | out | 1 | 1-cycle completion pulse |
| `rx_data` | out | `DATA_WIDTH` | Received data (valid from `done`) |
| `spi_sclk` | out | 1 | SPI clock |
| `spi_mosi` | out | 1 | Master-out / slave-in |
| `spi_cs_n` | out | 1 | Chip select (active low) |

---

## 4. Block Diagram
+-------------------------------------------------------------+
| spi_master_top |
| |
clk ------------->| +-------------------------------------------------------+ |
rst_n ------------->| | spi_master_controller | |
start ------------->| | | |
tx_data[DW-1:0] ------->| | +-----------------+ +--------------------+ | |
clk_divider[15:0] ------>| | | spi_fsm | | spi_clock_generator| | |
cpol ------------->| | | | | | | |
cpha ------------->| | | IDLE | | div_cnt[15:0] | | |
| | | LOAD | | edge_cnt[7:0] | | |
| | | TRANSFER | | | | |
| | | DONE | | sclk ----------------------> spi_sclk
| | +--------+--------+ | shift_tick | | |
| | | | sample_tick | | |
| | load | enable | last_sample_tick | | |
| | | | last_edge | | |
| | v +----------+---------+ | |
| | +---------------------------------+ | | |
| | | spi_shift_register |<---+ | |
spi_miso ------------->|--|-->| tx_sr (MSB first, left shift) | | |
| | | rx_sr (MSB first, left shift) |-----------------------> spi_mosi
| | | spi_mosi (registered) | | |
| | +---------------------------------+ | |
| | | |
busy <------------|--| | |
done <------------|--| | |
rx_data[DW-1:0] <-------|--| | |
| | |----> spi_cs_n
| +-------------------------------------------------------+ |
+-------------------------------------------------------------+

text

---

## 5. State Diagram
rst_n = 0
|
v
+---------------------+
+---------->| IDLE |
| | cs_n = 1 |
| | enable = 0 |
| | busy = 0 |
| +----------+----------+
| | start = 1
| v
| +---------------------+
| | LOAD |
| | cs_n = 0 |
| | load = 1 |
| | busy = 1 |
| +----------+----------+
| | (1 clk : parallel load of tx_data)
| v
| +---------------------+
| | TRANSFER |
| | cs_n = 0 |
| | enable = 1 |
| | busy = 1 |
| | 2*DATA_WIDTH edges |
| +----------+----------+
| | last_edge = 1
| v
| +---------------------+
+-----------+ DONE |
(1 clk) | cs_n = 1 |
| done = 1 (pulse) |
| busy = 0 |
+---------------------+

text

---

## 6. Expected Timing Diagram

### Mode 0 (CPOL = 0, CPHA = 0), 8-bit, `clk_divider = 2`
clk |-||-||-||-||-||-||-||-||-||-||-||-||-||-||-|
^ ^ ^ ^ ^ ^ ^ ^ ^
state |IDLE |LOAD | TRANSFER ................................|DONE |IDLE
cs_n ‾‾‾‾‾‾|_______________________________________|‾‾‾‾‾‾‾‾
sclk |‾‾‾‾‾||‾‾‾‾‾|_|‾‾‾‾‾||‾‾‾‾‾| ...
idle=0 ^ ^ ^ ^ ^ ^ ^
L0 T0 L1 T1 L2 T2 L3
MOSI =====< b7 >< b6 >< b5 >< b4 >< b3 >< b2 >< b1 > ...
^ ^ ^ ^ ^ ^
sample_tick L0 L1 L2 L3 L4 L5
shift_tick T0 T1 T2 T3 T4
MISO =====< s7 >< s6 >< s5 >< s4 >< s3 >< s2 >< s1 > ...
rx_data <-- valid
done ^

text

### Mode 3 (CPOL = 1, CPHA = 1), 8-bit, `clk_divider = 2`
cs_n ‾‾‾‾‾‾|_____________________________|‾‾‾‾‾‾‾‾
sclk ‾‾‾‾‾‾‾‾||‾‾‾‾‾|_|‾‾‾‾‾||‾‾‾‾‾|_|‾‾‾‾‾|‾‾‾‾
idle=1 ^ ^ ^ ^ ^ ^ ^
L0 T0 L1 T1 L2 T2 L3
MOSI ==============< b7 >< b6 >< b5 >< b4 >< b3 >< b2 > ...
sample_tick T0 T1 T2 T3 T4 T5
shift_tick L0 L1 L2 L3 L4 L5
MISO ==============< s7 >< s6 >< s5 >< s4 >< s3 >< s2 > ...

text

**Rule of thumb**

| CPHA | MOSI changes on | MISO sampled on |
|---|---|---|
| 0 | trailing edge | leading edge |
| 1 | leading edge | trailing edge |

---

## 7. Resource Utilisation Estimate (7-series / 28 nm, `DATA_WIDTH = 8`)

| Resource | Estimate | Notes |
|---|---|---|
| LUT | ~70 – 110 | FSM decode + comparators + shift logic |
| FF | ~55 – 70 | 2 × 8-bit SR + counters + state + FSM outputs |
| CARRY4 | 2 | divider counter |
| DSP / BRAM | 0 | — |
| Max frequency (est.) | > 250 MHz | 7-series, speed grade -1 |

Scaling with `DATA_WIDTH`:

| DATA_WIDTH | LUT (est.) | FF (est.) |
|---|---|---|
| 8 | ~110 | ~70 |
| 16 | ~160 | ~100 |
| 32 | ~260 | ~165 |

---

## 8. Critical Path Analysis

The dominant path is inside `spi_clock_generator`:
clk_divider[15:0] --> comparator (div_cnt == div_val-1)
--> div_tick
--> edge-qualifier (leading/trailing + CPHA mux)
--> shift_tick / sample_tick
--> spi_shift_register enable + MSB mux
--> spi_mosi (register D input)

text

Estimated delay (28 nm LP, typical):

| Stage | Delay |
|---|---|
| 16-bit comparator | ~0.55 ns |
| CPHA/edge mux tree | ~0.25 ns |
| Shift-register mux + setup | ~0.35 ns |
| **Total** | **~1.15 ns** |

The design closes timing at 100 MHz (10 ns) with a margin of **> 8 ns**.
The design is comfortably **timing-friendly**:

* No combinational paths from inputs directly to outputs.
* All outputs are register-driven (`spi_sclk`, `spi_mosi`, `spi_cs_n`).
* No ripple-carry structures wider than 16 bits.
* Reset is asynchronous-assert / synchronous-de-assert by construction.

**Hold analysis** — no `clk_divider` / `CPOL` / `CPHA` path is timing-critical
because they are quasi-static configuration inputs.

---

## 9. Running the Simulation (Vivado XSim)

### 9.1 GUI flow

```tcl
# In the Vivado Tcl console
cd <project_dir>
source run_simulation.tcl
