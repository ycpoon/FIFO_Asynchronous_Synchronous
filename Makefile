# Icarus Verilog Makefile
# Change SOURCES, TESTBENCH, TOP_LEVEL_MODULE, and TOP_EXECUTABLE to match project

# Should include all the source files
SOURCES ?= Simple_FIFO.sv

# Should include the testbench file
TESTBENCH ?= FIFO_test.sv

# Name of the top level module
TOP_LEVEL_MODULE ?= FIFO_test

# Name of the top level executable (.out extension automatically appended)
TOP_EXECUTABLE ?= FIFO

# Default target
all: $(TOP_EXECUTABLE)

# Compilation command
$(TOP_EXECUTABLE): $(SOURCES) $(TESTBENCH)
	iverilog -o $(TOP_EXECUTABLE).out -s $(TOP_LEVEL_MODULE) $(TESTBENCH) $(SOURCES)

# Simulation command
sim: $(TOP_EXECUTABLE)
	vvp ./$(TOP_EXECUTABLE).out

# Clean up all .out and .vcd files
clean:
	rm -f *.out
	rm -f *.vcd

# Phony targets
.PHONY: all clean