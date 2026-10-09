
# SPI Master Controller — RTL + Verification Project

A parameterized SPI Master Controller implemented in Verilog-2001, with a SystemVerilog verification environment and implementation support for FPGA and ASIC design flows.

**Target tools:** Xilinx Vivado, Cadence Genus, and Cadence Innovus.

> Project status: RTL and verification deliverables are specified below. Simulation, synthesis, timing closure, and physical-design results must be confirmed by running the project in the target tools.

---

## Table of Contents

1. Project Overview
2. Feature Summary
3. Project File Structure
4. Port Description
5. SPI Protocol Overview
6. Block Diagram
7. FSM State Diagram
8. Timing Diagrams
9. Resource Utilization Estimates
10. Critical Path Analysis
11. Simulation Using Vivado XSim
12. Vivado Synthesis and Implementation
13. Cadence Genus Synthesis
14. Cadence Innovus Place and Route
15. Timing Constraints
16. Verification Plan
17. Expected Results
18. Troubleshooting
19. Limitations and Assumptions
20. Future Enhancements
21. Final-Year Project Deliverables

---

## 1. Project Overview

The SPI Master Controller is a synchronous digital design that communicates with an SPI slave using four standard SPI signals.

The controller supports all four SPI operating modes, configurable clock division, and parameterized data widths of 8, 16, and 32 bits.

The design is divided into a finite-state machine (FSM), a serial clock generator, and transmit/receive shift registers.

The project is intended to demonstrate RTL design, functional verification, logic synthesis, static timing analysis, and physical implementation.

### Project objectives

- Implement a synthesizable SPI Master Controller.
- Support SPI Modes 0, 1, 2, and 3.
- Implement MSB-first serial data transmission and reception.
- Create a self-checking SystemVerilog testbench.
- Verify reset, transfer completion, clock division, and data integrity.
- Synthesize the design using Vivado and Cadence Genus.
- Implement the synthesized ASIC netlist using Cadence Innovus.
- Analyze area, timing, and physical-design reports.

---

## 2. Feature Summary

| Feature | Specification |
|---|---|
| Design name | `SPI_Master_Controller` |
| RTL language | Verilog-2001 |
| Testbench language | SystemVerilog |
| SPI role | Master |
| SPI modes | 0, 1, 2, 3 |
| Data widths | 8, 16, 32 bits |
| Bit order | MSB first |
| Clock input | 100 MHz design target |
| Clock divider | Programmable |
| Reset | Asynchronous active-low |
| Controller | FSM-based |
| Datapath | TX/RX shift registers |
| Verification | Self-checking testbench |
| FPGA flow | Xilinx Vivado |
| ASIC synthesis | Cadence Genus |
| ASIC physical design | Cadence Innovus |
| Timing constraints | XDC and SDC |

### SPI clock frequency

The intended SCLK frequency is:

\[
f_{\mathrm{SCLK}}=\frac{f_{\mathrm{CLK}}}{2D}
\]

where:

- \(f_{\mathrm{CLK}}\) is the system clock frequency.
- \(D\) is the clock-divider value.
- \(D \geq 1\).

For a 100 MHz system clock:

| Divider | SCLK frequency | SCLK period |
|---:|---:|---:|
| 1 | 50 MHz | 20 ns |
| 2 | 25 MHz | 40 ns |
| 4 | 12.5 MHz | 80 ns |
| 8 | 6.25 MHz | 160 ns |
| 16 | 3.125 MHz | 320 ns |

These values are theoretical frequencies based on the intended divider behavior. Confirm the generated waveform in simulation.

---

## 3. Project File Structure

Organize the project as follows:

```text
SPI_Master_Controller/
|
+-- rtl/
|   +-- spi_clock_generator.v
|   +-- spi_fsm.v
|   +-- spi_shift_register.v
|   +-- spi_master_controller.v
|   +-- spi_master_top.v
|
+-- tb/
|   +-- spi_master_tb.sv
|
+-- constraints/
|   +-- spi_master.xdc
|   +-- spi_master.sdc
|
+-- scripts/
|   +-- run_simulation.tcl
|   +-- synthesis.tcl
|
+-- reports/
|   +-- simulation/
|   +-- synthesis/
|   +-- timing/
|   +-- physical_design/
|
+-- README.md
```

The directory structure is a recommended organization. Update script paths if the files are stored in separate directories.

### File descriptions

| File | Purpose |
|---|---|
| `spi_clock_generator.v` | Generates SCLK and edge qualifiers |
| `spi_fsm.v` | Controls transfer sequencing |
| `spi_shift_register.v` | Implements serial transmit and receive |
| `spi_master_controller.v` | Integrates the SPI core |
| `spi_master_top.v` | Top-level module for implementation |
| `spi_master_tb.sv` | Functional verification testbench |
| `spi_master.xdc` | Vivado pin and timing constraints |
| `spi_master.sdc` | ASIC timing constraints |
| `run_simulation.tcl` | Automates behavioral simulation |
| `synthesis.tcl` | Automates Vivado synthesis and reporting |
| `README.md` | Project documentation |

---

## 4. Port Description

### Top-level module: `spi_master_top`

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low reset |
| `start` | Input | 1 | Requests a transfer |
| `tx_data` | Input | `DATA_WIDTH` | Parallel transmit data |
| `clk_divider` | Input | 16 | SCLK half-period divider |
| `cpol` | Input | 1 | SPI clock polarity |
| `cpha` | Input | 1 | SPI clock phase |
| `spi_miso` | Input | 1 | Master-in, slave-out |
| `spi_sclk` | Output | 1 | SPI serial clock |
| `spi_mosi` | Output | 1 | Master-out, slave-in |
| `spi_cs_n` | Output | 1 | Active-low slave select |
| `busy` | Output | 1 | Transfer in progress |
| `done` | Output | 1 | Transfer-completion pulse |
| `rx_data` | Output | `DATA_WIDTH` | Received parallel data |

### Handshake behavior

1. Apply `tx_data`, `clk_divider`, `cpol`, and `cpha`.
2. Assert `start` when the controller is idle.
3. The controller enters the load and transfer states.
4. `busy` indicates an active transfer.
5. `spi_cs_n` selects the slave during transfer.
6. After the required SCLK edges, `done` indicates completion.
7. `rx_data` contains the received word.

Keep configuration inputs stable throughout a transfer unless the RTL is specifically modified to latch them at transaction start.

---

## 5. SPI Protocol Overview

SPI uses four primary signals:

- **SCLK:** Serial clock generated by the master.
- **MOSI:** Data transmitted from master to slave.
- **MISO:** Data transmitted from slave to master.
- **CS_N:** Active-low chip select.

### SPI modes

| Mode | CPOL | CPHA | Idle SCLK | Sampling edge |
|---|---:|---:|---|---|
| Mode 0 | 0 | 0 | Low | Rising / leading |
| Mode 1 | 0 | 1 | Low | Falling / trailing |
| Mode 2 | 1 | 0 | High | Falling / leading |
| Mode 3 | 1 | 1 | High | Rising / trailing |

The physical rising or falling edge depends on CPOL. The protocol distinction is between the **leading edge**, which moves SCLK away from its idle level, and the **trailing edge**, which returns it toward the idle level.

| CPHA | Data sampling | Data shifting |
|---|---|---|
| 0 | Leading edge | Trailing edge |
| 1 | Trailing edge | Leading edge |

For CPHA = 0, the first data bit must be available before the first leading edge.

For CPHA = 1, the first data bit is prepared during the first leading edge and sampled on the trailing edge.

The controller transmits the most significant bit first.

---

## 6. Block Diagram

```text
                     SPI MASTER CONTROLLER
                  +--------------------------+
                  |                          |
 clk ------------>|                          |
 rst_n ---------->|                          |
 start ---------->|        FSM               |
                  |   IDLE / LOAD / TRANSFER |
                  |          / DONE          |
                  +-----+--------------+-----+
                        |              |
                  load/enable       last_edge
                        |              ^
                        v              |
                  +--------------------------+
                  |    SPI CLOCK GENERATOR  |
 clk_divider ---->|    Divider counter      |
 cpol ----------->|    SCLK generation      |----> spi_sclk
 cpha ----------->|    Edge qualifiers      |
                  +-------------+------------+
                                |
                      shift_tick / sample_tick
                                |
                                v
                  +--------------------------+
 tx_data -------->| TX Shift Register        |
 spi_miso ------->| RX Shift Register        |
                  |                          |
                  | Registered MOSI           |----> spi_mosi
                  | Parallel RX Data          |----> rx_data
                  +--------------------------+

 FSM status ------------------------------------> busy
 FSM status ------------------------------------> done
 FSM chip select --------------------------------> spi_cs_n
```

### Architectural description

**FSM:** Controls the transfer lifecycle and generates load and enable signals.

**Clock generator:** Divides the system clock and produces leading-edge, trailing-edge, sample, shift, and final-edge qualifiers.

**TX datapath:** Loads parallel transmit data and shifts it out serially.

**RX datapath:** Samples incoming MISO data and assembles the received word.

**Top-level module:** Connects the internal blocks to the external interface.

---

## 7. FSM State Diagram

The controller uses four states.

```text
              +----------------+
              |      IDLE      |
              | busy = 0       |
              | CS_N = 1        |
              +-------+--------+
                      |
                  start = 1
                      |
                      v
              +----------------+
              |      LOAD      |
              | load = 1       |
              | busy = 1       |
              | CS_N = 0       |
              +-------+--------+
                      |
                      | One system-clock cycle
                      v
              +----------------+
              |    TRANSFER    |
              | enable = 1     |
              | busy = 1       |
              | CS_N = 0       |
              +-------+--------+
                      |
                  last_edge
                      |
                      v
              +----------------+
              |      DONE      |
              | done = 1       |
              | CS_N = 1        |
              +-------+--------+
                      |
                      v
                     IDLE
```

### State behavior

| State | Load | Enable | Busy | Done | CS_N |
|---|---:|---:|---:|---:|---:|
| IDLE | 0 | 0 | 0 | 0 | 1 |
| LOAD | 1 | 0 | 1 | 0 | 0 |
| TRANSFER | 0 | 1 | 1 | 0 | 0 |
| DONE | 0 | 0 | 0 | 1 | 1 |

These outputs reflect the intended state decoding. Verify the actual RTL behavior, particularly the timing of the final SCLK edge and the `done` pulse.

---

## 8. Timing Diagrams

### 8.1 Mode 0

Configuration:

- CPOL = 0
- CPHA = 0
- Data width = 8 bits
- Divider = 2

```text
CS_N   ‾‾‾‾‾‾‾\____________________________/‾‾‾‾‾
                 Active transfer

SCLK   __________/‾‾\__/‾‾\__/‾‾\__/‾‾\________
                  L T  L T  L T  L T

MOSI   -----------<b7><b6><b5><b4> ... <b0>-----
                  ^    ^    ^              ^
                Sample on leading edges

MISO   -----------<s7><s6><s5><s4> ... <s0>-----

DONE   __________________________________/‾\____
```

`L` means leading edge; `T` means trailing edge.

The first bit is established before the first sampling edge. Subsequent bits are shifted on trailing edges.

### 8.2 Mode 3

Configuration:

- CPOL = 1
- CPHA = 1
- Data width = 8 bits
- Divider = 2

```text
CS_N   ‾‾‾‾‾‾‾\____________________________/‾‾‾‾‾

SCLK   ‾‾‾‾‾‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾‾‾‾‾‾‾
                  L T  L T  L T  L T

MOSI   -----------<b7><b6><b5><b4> ... <b0>-----

MISO   -----------<s7><s6><s5><s4> ... <s0>-----

DONE   __________________________________/‾\____
```

In Mode 3, the clock idles high, and the trailing edge is the sampling edge.

These diagrams are conceptual, not simulation-generated waveforms. Use the simulator to verify the exact edge count and timing.

---

## 9. Resource Utilization Estimates

Resource utilization depends on the target FPGA, synthesis options, RTL implementation, and parameter values.

The following values are **illustrative planning estimates only**, not measured synthesis results.

| Resource | 8-bit design | Notes |
|---|---:|---|
| LUTs | Approximately 70–110 | FSM, counters, multiplexers |
| Flip-flops | Approximately 55–70 | Shift registers, counters, state |
| BRAM | 0 expected | No large memory inferred |
| DSP | 0 expected | No arithmetic DSP blocks required |

Do not use these estimates as actual project results.

### ASIC metrics

For Genus and Innovus, record:

| Metric | Actual result |
|---|---|
| Standard-cell area | To be measured |
| Sequential cell count | To be measured |
| Combinational cell count | To be measured |
| Worst setup slack | To be measured |
| Worst hold slack | To be measured |
| Maximum transition violations | To be measured |
| Maximum capacitance violations | To be measured |
| Routed signal-metal area | To be measured, if reported |

ASIC standard-cell area and FPGA LUT/FF utilization are different metrics and should not be compared directly.

---

## 10. Critical Path Analysis

The divider and edge-qualification logic are candidate critical paths, but the actual critical path must be identified from synthesis and timing reports.

A possible register-to-register path is:

```text
Divider counter
      |
      v
Divider comparison
      |
      v
Edge qualification
      |
      v
Shift/sample enable logic
      |
      v
Shift-register input mux
      |
      v
Destination flip-flop
```

### Timing equation

For a register-to-register setup path, a simplified timing condition is:

\[
T_{\mathrm{clk}}
\geq T_{\mathrm{cq}}+
T_{\mathrm{comb}}+
T_{\mathrm{setup}}+
T_{\mathrm{uncertainty}}
\]

where:

- \(T_{\mathrm{cq}}\) is clock-to-Q delay.
- \(T_{\mathrm{comb}}\) is combinational propagation delay.
- \(T_{\mathrm{setup}}\) is the destination register setup time.
- \(T_{\mathrm{uncertainty}}\) accounts for the applicable timing uncertainty.

At 100 MHz, the system-clock period is 10 ns. The design must meet the timing requirements of the selected library and constraints.

### Reports to inspect

- Setup timing report
- Hold timing report
- Worst negative slack (WNS)
- Total negative slack (TNS)
- Maximum transition violations
- Maximum capacitance violations
- Cell area report
- Post-route timing report

Do not claim a specific critical-path delay or timing margin until these reports have been generated.

---

## 11. Simulation Using Vivado XSim

### 11.1 GUI flow

1. Open Vivado.
2. Create or open a project.
3. Add the five RTL files.
4. Add `spi_master_tb.sv` under Simulation Sources.
5. Set `spi_master_tb` as the simulation top.
6. Run **Behavioral Simulation**.
7. Inspect the waveform and simulator transcript.

The testbench uses SystemVerilog features, so compile it as SystemVerilog rather than plain Verilog.

### 11.2 Tcl flow

From the Vivado Tcl console, navigate to the directory containing the simulation script and run:

```tcl
source run_simulation.tcl
```

Check the `PART` setting and file paths in the script before running it.

### 11.3 Expected test coverage

The provided testbench is intended to test:

- Reset behavior
- SPI Mode 0
- SPI Mode 1
- SPI Mode 2
- SPI Mode 3
- Back-to-back transfers
- Random data
- Clock-divider variations
- 8-bit transfers
- 16-bit transfers
- 32-bit transfers
- Walking-one data patterns

### 11.4 Passing criteria

A successful verification run should demonstrate:

- Correct transmitted data at the slave model.
- Correct received data at the master.
- Correct SPI mode timing.
- Correct completion behavior.
- No unexpected assertion failures.
- No simulation timeout.
- A final failure count of zero.

The testbench must be run to establish whether these criteria pass. The presence of checks in the testbench does not itself prove the RTL is correct.

---

## 12. Vivado Synthesis and Implementation

### 12.1 Create the project

Create a new RTL project and select the exact FPGA part installed on your target board.

Do not assume the example device in a script matches your hardware.

### 12.2 Add RTL sources

Add:

```text
spi_clock_generator.v
spi_fsm.v
spi_shift_register.v
spi_master_controller.v
spi_master_top.v
```

Set `spi_master_top` as the synthesis top.

### 12.3 Add constraints

Add:

```text
spi_master.xdc
```

The example XDC contains sample pin assignments. Replace them with pins appropriate for the actual FPGA board and verify the supported I/O voltage standards.

The top-level interface includes `tx_data`, `clk_divider`, `cpol`, and `cpha`. The sample pin list does not assign pins for these ports, so the constraints are incomplete for direct hardware use until those ports are connected or assigned appropriately.

### 12.4 Run implementation

Run these steps in order:

1. Run Synthesis.
2. Review synthesis warnings and utilization.
3. Run Implementation.
4. Review placement and routing reports.
5. Review timing summary.
6. Generate a bitstream only after constraints and implementation are valid.

### 12.5 Example Tcl commands

```tcl
read_verilog {
    spi_clock_generator.v
    spi_fsm.v
    spi_shift_register.v
    spi_master_controller.v
    spi_master_top.v
}

read_xdc spi_master.xdc

synth_design -top spi_master_top

report_utilization
report_timing_summary
```

These commands illustrate the core steps; they do not replace the full implementation and bitstream-generation flow.

---

## 13. Cadence Genus Synthesis

Cadence Genus converts the RTL into a technology-mapped standard-cell netlist.

### 13.1 Required inputs

- RTL source files
- Liberty timing libraries (`.lib`)
- ASIC timing constraints (`.sdc`)
- Correct target library and process corner
- Optional technology-specific synthesis settings

Use the extracted or supplied Liberty files supported by your PDK. Do not assume that a generic cell name exists in every library.

### 13.2 Example synthesis script

The following is a starting-point template. Exact command syntax and library setup can vary with the installed Genus version.

```tcl
# Read RTL
read_hdl {
    spi_clock_generator.v
    spi_fsm.v
    spi_shift_register.v
    spi_master_controller.v
    spi_master_top.v
}

# Elaborate top-level design
elaborate spi_master_top

# Apply timing constraints
read_sdc spi_master.sdc

# Generic synthesis
syn_generic

# Technology mapping
syn_map

# Optimization
syn_opt

# Reports
report_area
report_timing

# Export mapped netlist
write_hdl > spi_master_netlist.v
```

Configure the library search path and target library according to your PDK and installed Genus version before running the flow.

### 13.3 Review the results

Confirm that:

- Elaboration completes without unresolved modules.
- No unintended latches are inferred.
- The mapped netlist contains valid standard cells.
- The timing constraints are applied correctly.
- Setup and hold reports are generated.
- Area and timing results are saved.

The script is a starting point, not a guarantee of execution without environment-specific changes.

---

## 14. Cadence Innovus Place and Route

Innovus implements the synthesized design physically using the target technology.

### 14.1 Required inputs

- Genus mapped netlist
- ASIC SDC
- Technology LEF
- Standard-cell LEF
- Liberty timing libraries
- RC extraction technology files or supported extraction setup
- Foundry-specific physical-design configuration

### 14.2 Implementation stages

**1. Floorplanning**

Define the core and die dimensions, placement rows, and required utilization.

**2. Power planning**

Create power and ground connections using the appropriate power-grid strategy.

**3. Placement**

Place the standard cells and optimize the design for timing and congestion.

**4. Clock-tree synthesis**

Build the clock distribution network for the system clock and analyze skew and insertion delay.

**5. Routing**

Perform global and detailed routing, followed by the required optimization steps.

**6. Static timing analysis**

Analyze setup and hold timing after placement, clock-tree synthesis, and routing.

**7. Physical verification**

Run the available design-rule, connectivity, and other checks required by the PDK.

**8. Final database and layout export**

Save the final Innovus database and generate the required layout deliverables, such as GDSII, using the appropriate foundry flow.

### 14.3 Example flow outline

```text
Read technology and cell libraries
              |
              v
Read mapped netlist and SDC
              |
              v
Initialize floorplan
              |
              v
Power planning
              |
              v
Placement and optimization
              |
              v
Clock-tree synthesis
              |
              v
Routing and optimization
              |
              v
Post-route timing analysis
              |
              v
Physical verification
              |
              v
Final layout export
```

This is a flow outline, not a directly executable Innovus Tcl script. The exact commands and configuration depend on the Innovus version, PDK, and project setup.

### 14.4 Final reports

Save the following reports where available:

- Floorplan summary
- Placement summary
- Clock-tree synthesis report
- Routing report
- Cell area report
- Setup timing report
- Hold timing report
- DRC report
- Connectivity report
- Final layout-generation status

---

## 15. Timing Constraints

The project contains two constraint files for different implementation environments.

### 15.1 Vivado XDC

File:

```text
spi_master.xdc
```

The example targets a 100 MHz system clock:

```tcl
create_clock -name sys_clk \
    -period 10.000 \
    -waveform {0.000 5.000} \
    [get_ports clk]
```

The example also contains I/O standards, pin assignments, and sample input/output delay constraints.

**Important:** Verify the selected FPGA part, pin assignments, I/O bank voltage, and board-level timing before programming hardware.

### 15.2 ASIC SDC

File:

```text
spi_master.sdc
```

The example system-clock constraint is:

```tcl
create_clock -name clk \
    -period 10.000 \
    -waveform {0.000 5.000} \
    [get_ports clk]

set_clock_uncertainty -setup 0.150 [get_clocks clk]
set_clock_uncertainty -hold  0.050 [get_clocks clk]
```

The complete SDC also requires appropriate input/output delays, clock assumptions, and electrical constraints for the selected implementation.

### 15.3 SDC review checklist

Before using the constraints for sign-off:

- Confirm the system clock period.
- Define realistic input and output delays.
- Check clock uncertainty and latency assumptions.
- Use a driving cell that exists in the selected library.
- Verify output loads and transition limits.
- Review timing exceptions carefully.
- Confirm that all relevant ports are constrained.
- Check timing reports for unconstrained paths.

The sample SDC includes a false-path exception to `spi_sclk`. Review this exception carefully: excluding a path from timing analysis can hide a real timing requirement. Do not retain an exception simply because it appears in a template.

SPI interface timing should reflect the actual external slave timing and board-level delays, rather than treating the example virtual-clock period as universally valid.

---

## 16. Verification Plan

### 16.1 Functional tests

| Test | Purpose | Expected outcome |
|---|---|---|
| Reset | Verify reset state | Controller returns to idle |
| Mode 0 | Verify CPOL=0, CPHA=0 | Correct serial transfer |
| Mode 1 | Verify CPOL=0, CPHA=1 | Correct serial transfer |
| Mode 2 | Verify CPOL=1, CPHA=0 | Correct serial transfer |
| Mode 3 | Verify CPOL=1, CPHA=1 | Correct serial transfer |
| Back-to-back | Verify repeated transactions | No data corruption |
| Random data | Exercise different data patterns | Scoreboard matches |
| Divider variation | Exercise divider values | Correct SCLK period |
| 8-bit transfer | Check 8-bit configuration | Correct TX/RX data |
| 16-bit transfer | Check 16-bit configuration | Correct TX/RX data |
| 32-bit transfer | Check 32-bit configuration | Correct TX/RX data |
| Walking-one | Exercise individual bits | Correct TX/RX data |

### 16.2 Self-checking testbench

The SystemVerilog testbench includes a behavioral slave model, transfer tasks, a scoreboard, assertions, and functional coverage.

The scoreboard should compare:

- Master transmit data against the slave's received data.
- Slave transmit data against the master's received data.
- Completion and chip-select behavior against the expected protocol.

### 16.3 Verification limitations

The testbench must be compiled and executed to confirm that all tests work correctly. Review assertion sampling, simulator support, and slave-model edge behavior if a test fails.

Functional coverage is not a substitute for correct scoreboarding or passing assertions.

---

## 17. Expected Results

The following table defines the results to collect after running the design.

| Stage | Result to record |
|---|---|
| RTL compilation | Compile status and warnings |
| Behavioral simulation | Pass/fail count |
| Functional verification | Test and coverage results |
| Vivado synthesis | LUT, FF, and utilization reports |
| Vivado implementation | Timing summary |
| Genus synthesis | Standard-cell area and timing |
| Innovus placement | Placement and congestion reports |
| Clock-tree synthesis | Clock skew and insertion delay |
| Post-route analysis | Setup and hold slack |
| Physical verification | DRC and connectivity status |
| Final export | GDSII generation status |

### Results template

Fill in this table after the tool runs.

| Metric | Measured result |
|---|---|
| Simulation | Pending |
| Functional tests passed | Pending |
| Functional tests failed | Pending |
| Coverage | Pending |
| FPGA LUT count | Pending |
| FPGA FF count | Pending |
| ASIC cell area | Pending |
| Post-route setup slack | Pending |
| Post-route hold slack | Pending |
| DRC status | Pending |
| GDSII generation | Pending |

Do not replace pending values with assumed results. Report only measurements obtained from the relevant tools.

---

## 18. Troubleshooting

### Simulation fails to compile

Check that the RTL files are included and the testbench is compiled as SystemVerilog.

### Elaboration fails

Check the selected top module, parameter values, module names, and source-file paths.

### SPI receive data is incorrect

Inspect the MISO waveform, CPOL/CPHA settings, bit order, and sampling-edge behavior. Check the slave model's first-bit handling.

### SCLK frequency is incorrect

Verify the system-clock period and divider implementation. Measure the SCLK period in the waveform and compare it with the intended divider equation.

### Vivado reports unconstrained ports

Review the XDC and ensure every physical input/output has the required pin assignment and applicable I/O timing constraints.

### Genus reports an invalid library cell

Check the library setup and replace example cell names with valid cells from the target library.

### Innovus reports setup or hold violations

Review the timing constraints, mapped cells, clock-tree implementation, parasitics, and timing reports before attempting optimization.

### Innovus reports routing or DRC violations

Review floorplan utilization, pin access, power-grid setup, routing constraints, and PDK requirements.

---

## 19. Limitations and Assumptions

- This project implements an SPI master, not a complete SPI slave.
- The supported data widths are 8, 16, and 32 bits.
- The master uses MSB-first transmission.
- The clock-divider and SPI mode settings must remain stable during a transfer unless configuration latching is added.
- The example XDC pin assignments are board-dependent.
- The example SDC values require review for the selected PDK and external interface.
- The testbench is a simulation environment and is not synthesizable RTL.
- The sample scripts may need modifications for the installed EDA-tool version.
- No measured timing, area, coverage, or physical-verification results are claimed in this README.

**Reset note:** An asynchronous active-low reset does not automatically provide synchronized deassertion. If asynchronous assertion with synchronous release is required, add an appropriate reset synchronizer and verify its implementation.

---

## 20. Future Enhancements

Possible extensions include:

1. SPI slave controller.
2. APB register interface.
3. Programmable register map.
4. Multiple chip-select outputs.
5. Configurable bit order.
6. FIFO-based transmit and receive buffers.
7. Interrupt support.
8. SystemVerilog assertions and expanded coverage.
9. UVM-based verification.
10. Low-power implementation.
11. Multi-corner, multi-mode timing analysis.
12. Post-route timing optimization.
13. DRC-clean GDSII generation.
14. Power analysis and reporting.

These enhancements can extend the project from an SPI peripheral controller into a more complete ASIC subsystem.

---

## 21. Final-Year Project Deliverables

The intended submission package consists of:

- Verilog RTL source files
- SystemVerilog testbench
- Vivado XDC constraints
- ASIC SDC constraints
- Simulation and synthesis scripts
- Simulation transcript and waveform
- Vivado synthesis and implementation reports
- Genus synthesis reports
- Innovus placement and routing reports
- Setup and hold timing reports
- Physical-verification results
- Final README and project documentation

### Conclusion

The SPI Master Controller project provides a practical foundation for studying RTL design, serial communication protocols, functional verification, FPGA implementation, ASIC synthesis, and physical design.

The final project report should include the actual simulation and implementation results, explain any design changes, and distinguish estimated metrics from measured results.

