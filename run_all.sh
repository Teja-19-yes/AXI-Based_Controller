#!/bin/bash
# Compile and run every testbench of the structural design with Icarus Verilog.
# Usage: bash run_all.sh
run() {  # run <name> <files...>
    name=$1; shift
    echo "=== $name ==="
    iverilog -o sim_$name "$@" || { echo "COMPILE ERROR in $name"; return; }
    vvp sim_$name | grep -E "PASS|FAIL|Tests|TIMEOUT"
}
CELLS="cells.v"
SIF="axi_lite_slave_if.v"
run master $CELLS axi_lite_master.v tb_axi_lite_master.v
run regs   $CELLS $SIF axi_lite_master.v axi_lite_regs.v  tb_axi_lite_regs.v
run gpio   $CELLS $SIF axi_lite_master.v axi_lite_gpio.v  tb_axi_lite_gpio.v
run timer  $CELLS $SIF axi_lite_master.v axi_lite_timer.v tb_axi_lite_timer.v
run ic     $CELLS axi_lite_master.v axi_lite_interconnect.v axi_lite_mem_slave.v tb_axi_lite_interconnect.v
run rom    sync_rom.v tb_sync_rom.v
run soc    $CELLS $SIF axi_lite_master.v axi_lite_interconnect.v axi_lite_regs.v axi_lite_gpio.v \
           axi_lite_timer.v sync_rom.v boot_sequencer.v axi_lite_soc_top.v tb_axi_lite_soc_top.v
