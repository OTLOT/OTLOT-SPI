#=============================================================================
# File        : spi_master.xdc
# Project     : SPI_Master_Controller
# Target      : Xilinx Vivado (7-series / UltraScale)
# Description : Physical + timing constraints.
#               System clock = 100 MHz  (10.000 ns period)
#
#   clk       -> W5
#   rst_n     -> V17
#   start     -> V16
#   spi_mosi  -> W16
#   spi_miso  -> W17
#   spi_sclk  -> W15
#   spi_cs_n  -> V15
#=============================================================================

#-----------------------------------------------------------------------------
# 1. Pin assignment + I/O standard
#-----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN W5  IOSTANDARD LVCMOS33} [get_ports clk]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports rst_n]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports start]

set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports spi_mosi]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33} [get_ports spi_miso]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33} [get_ports spi_sclk]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports spi_cs_n]

#-----------------------------------------------------------------------------
# 2. Primary clock : 100 MHz
#-----------------------------------------------------------------------------
create_clock -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports clk]

set_clock_uncertainty -setup 0.150 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.050 [get_clocks sys_clk]
set_clock_transition  -rise  0.100 [get_clocks sys_clk]
set_clock_transition  -fall  0.100 [get_clocks sys_clk]

#-----------------------------------------------------------------------------
# 3. Synchronous inputs to the core
#-----------------------------------------------------------------------------
set_input_delay -clock sys_clk -max 2.000 [get_ports {rst_n start}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {rst_n start}]

#-----------------------------------------------------------------------------
# 4. SPI interface timing
#    SCLK is derived from sys_clk.  The fastest possible SCLK is obtained
#    with clk_divider = 1 :  f_sclk = 100 MHz / (2*1) = 50 MHz (20 ns).
#    A virtual clock of 20 ns is used to constrain the SPI pins.
#-----------------------------------------------------------------------------
create_clock -name spi_sclk_virt -period 20.000

set_input_delay  -clock spi_sclk_virt -max 5.000 [get_ports spi_miso]
set_input_delay  -clock spi_sclk_virt -min 1.000 [get_ports spi_miso]

set_output_delay -clock spi_sclk_virt -max 5.000 \
                 [get_ports {spi_mosi spi_sclk spi_cs_n}]
set_output_delay -clock spi_sclk_virt -min 1.000 \
                 [get_ports {spi_mosi spi_sclk spi_cs_n}]

#-----------------------------------------------------------------------------
# 5. Quasi-static configuration ports
#    (tx_data / clk_divider / cpol / cpha are driven from logic or a
#     register file - they are not in the constraint list above because the
#     reference design pins only the 7 ports listed in the specification.)
#    If those ports are also pinned, enable the following lines:
#-----------------------------------------------------------------------------
# set_input_delay -clock sys_clk -max 3.000 [get_ports {tx_data[*] clk_divider[*] cpol cpha}]
# set_input_delay -clock sys_clk -min 1.000 [get_ports {tx_data[*] clk_divider[*] cpol cpha}]

#-----------------------------------------------------------------------------
# 6. Miscellaneous
#-----------------------------------------------------------------------------
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets spi_sclk]

set_false_path -from [get_ports rst_n]