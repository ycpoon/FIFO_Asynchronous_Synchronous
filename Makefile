
# reference table of all make targets:

# make           <- runs the default target, set explicitly below as 'make sim'
.DEFAULT_GOAL = sim
# ^ this overrides using the first listed target as the default

# make sim         <- execute the simulation testbench (simv)
# make build/simv  <- compiles simv from the testbench and SOURCES

# make syn             <- execute the synthesized module testbench (syn.simv)
# make build/syn.simv  <- compiles syn.simv from the testbench and *.vg SYNTH_FILES
# make synth/*.vg      <- synthesize the top level module in SOURCES for use in syn.simv
# make slack           <- a phony command to print the slack of any synthesized modules

# make verdi     <- runs the Verdi GUI debugger for simulation
# make syn.verdi <- runs the Verdi GUI debugger for synthesis

# make clean     <- remove files created during compilations (but not synthesis)
# make nuke      <- remove all files created during compilation and synthesis
# make clean_run_files <- remove per-run output files
# make clean_exe       <- remove compiled executable files
# make clean_synth     <- remove generated synthesis files

######################################################
# ---- Compilation Commands and Other Variables ---- #
######################################################

# this is a global clock period variable used in the tcl script and referenced in testbenches
export CLOCK_PERIOD = 10.0

# remove certain warnings that generate MB of text but can be safely ignored
VCS_BAD_WARNINGS = +warn=noTFIPC +warn=noDEBUG_DEP +warn=noENUMASSIGN +warn=noLCA_FEATURES_ENABLED

# the Verilog Compiler command and arguments
VCS = vcs -sverilog -xprop=tmerge +vc -Mupdate -Mdir=build/csrc -line -full64 -kdb -lca -nc \
      -debug_access+all+reverse $(VCS_BAD_WARNINGS) +define+CLOCK_PERIOD=$(CLOCK_PERIOD)
# a SYNTH define is added when compiling for synthesis that can be used in testbenches

# a reference library of standard structural cells that we link against when synthesizing
LIB = /usr/caen/misc/class/eecs470/lib/verilog/lec25dscc25.v

TCL_SCRIPT = synth.tcl

# Set the shell's pipefail option: causes return values through pipes to match the last non-zero value
# (useful for, i.e. piping to `tee`)
SHELL := $(SHELL) -o pipefail

#####################################
# ---- Modules with Parameters ---- #
#####################################

# for designs with parameters, we need to create custom synthesis rules
# and add new macro definitions to VCS
# these changes are organized in this section, the rest of the file is untouched

DEPTH = 16
WIDTH = 32
MAX_CNT = 3
VCS += +define+DEPTH=$(DEPTH) +define+WIDTH=$(WIDTH) +define+MAX_CNT=$(MAX_CNT)

# synthesis will generate new filenames given parameters i.e. FIFO_DEPTH8, FIFO_DEPTH12
# we match that here:
FIFO_params = FIFO_DEPTH$(DEPTH)
SYNTH_FILES = synth/$(FIFO_params).vg synth/$(FIFO_params)_svsim.sv

# our SYNTH_FILES are named by the parameter values (i.e. FIFO_DEPTH8)
# so they won't re-synthesize unless the module source is updated
# it means designs can save multiple .vg files with different params concurrently
# though we use the same names for executable compilation (simv, syn_simv)
# but those are faster to compile and don't need the speed boost

# we need a custom synthesis rule for each .vg file with unique parameters
synth/$(FIFO_params).vg: $(SOURCES) $(TCL_SCRIPT) $(HEADERS) | synth
	@$(call PRINT_COLOR, 5, synthesizing the FIFO module with DEPTH=$(DEPTH))
	cd synth && \
	MODULE=FIFO SOURCES="$(SOURCES)" PARAMS="DEPTH=$(DEPTH)" \
	dc_shell-t -f ../$(TCL_SCRIPT) | tee $(FIFO_params).out
	@$(call PRINT_COLOR, 6, finished synthesizing $@)

# tell Make that making .vg files also generates matching _svsim.sv files
synth/%_svsim.sv: synth/%.vg ;

####################################
# ---- Executable Compilation ---- #
####################################

# TODO: Add sources and testbenches
TESTBENCH   = axi_stream_interconnect_tb.sv
SOURCES     = axi_stream_interconnect.sv encoder.sv psel_gen.sv FIFO.sv memDP.sv
HEADERS     = 

# the .vg rule is automatically generated below when the name of the file matches its top level module

# the normal simulation executable will run your testbench on the original modules
build/simv: $(TESTBENCH) $(SOURCES) $(HEADERS) | build
	@$(call PRINT_COLOR, 5, compiling the simulation executable $@)
	$(VCS) $(TESTBENCH) $(SOURCES) -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@)
# NOTE: we reference variables with $(VARIABLE), and can make use of the automatic variables: ^, @, <, etc
# see: https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html for explanations

# the synthesis executable runs your testbench on the synthesized versions of your modules
build/syn.simv: $(TESTBENCH) $(SYNTH_FILES) $(HEADERS) | build
	@$(call PRINT_COLOR, 5, compiling the synthesis executable $@)
	$(VCS) +define+SYNTH $(TESTBENCH) $(SYNTH_FILES) $(LIB) -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@)
# we need to link the synthesized modules against LIB, so this differs slightly from simv above
# but we still compile with the same non-synthesizable testbench

# a phony target to view the slack in the *.rep synthesis report file
slack:
	grep --color=auto "slack" synth/*.rep
.PHONY: slack

#####################################
# ---- Running the Executables ---- #
#####################################

# these targets run the compiled executable and save the output to a .out file
# their respective files are "build/program.out" or "build/program.syn.out"

sim: build/simv
	@$(call PRINT_COLOR, 5, running $<)
	cd build && ./simv | tee program.out
	@$(call PRINT_COLOR, 2, output saved to build/program.out)

syn: build/syn.simv
	@$(call PRINT_COLOR, 5, running $<)
	cd build && ./syn.simv | tee program.syn.out
	@$(call PRINT_COLOR, 2, output saved to build/program.syn.out)

# NOTE: phony targets don't create files matching their name, and make will always run their commands
# make doesn't know how files get created, so we tell it about these explicitly:
.PHONY: sim syn

###################
# ---- Verdi ---- #
###################

# Options to launch Verdi when running the executable
RUN_VERDI_OPTS = -gui=verdi -verdi_opts "-ultra" -no_save
# Not sure why no_save is needed right now. Otherwise prints an error
VERDI_DIR = /tmp/$(USER)470
VERDI_TEMPLATE = /usr/caen/misc/class/eecs470/verdi-config/initialnovas.rc

# verdi hates us: we must use the /tmp folder for all verdi files or it will crash
# this adds much unecessary complexity in the makefile
# A directory for verdi, specified in the build/novas.rc file.
$(VERDI_DIR) $(VERDI_DIR)/verdiLog:
	mkdir -p $@
# Symbolic link from the build folder to VERDI_DIR in /tmp
build/verdiLog: $(VERDI_DIR)/verdiLog build
	ln -s $(VERDI_DIR)/verdiLog build
# make a custom novas.rc for your username matching VERDI_DIR
build/novas.rc: $(VERDI_TEMPLATE) | build
	sed s/UNIQNAME/$${USER}/ $< > $@

# now the actual targets to launch verdi
verdi: build/simv build/novas.rc build/verdiLog $(VERDI_DIR)
	cd build && ./simv $(RUN_VERDI_OPTS)

syn.verdi: build/syn.simv build/novas.rc build/verdiLog $(VERDI_DIR)
	cd build && ./syn.simv $(RUN_VERDI_OPTS)

.PHONY: verdi syn.verdi

###############################
# ---- Build Directories ---- #
###############################

# Directories for holding build files or run outputs
# Targets that need these directories should add them after a pipe.
# ex: "target: dep1 dep2 ... | build"
build synth:
	mkdir -p $@
# Don't leave any files in these, they will be deleted by clean commands

#####################
# ---- Cleanup ---- #
#####################

# You should only clean your directory if you think something has built incorrectly
# or you want to prepare a clean directory for e.g. git (first check your .gitignore).
# Please avoid cleaning before every build. The point of a makefile is to
# automatically determine which targets have dependencies that are modified,
# and to re-build only those as needed; avoiding re-building everything everytime.

# 'make clean' removes build/output files, 'make nuke' removes all generated files
# clean_* commands clean certain groups of files

clean: clean_exe clean_run_files
	@$(call PRINT_COLOR, 6, note: clean is split into multiple commands that you can call separately: clean_exe and clean_run_files)

# use cautiously, this can cause hours of recompiling in later projects
nuke: clean clean_synth
	@$(call PRINT_COLOR, 6, note: nuke is split into multiple commands that you can call separately: clean_synth)

clean_exe:
	@$(call PRINT_COLOR, 3, removing compiled executable files)
	rm -rf build
	rm -rf *simv *.daidir csrc *.key vcdplus.vpd vc_hdrs.h
	rm -rf verdi* novas* *fsdb*

clean_run_files:
	@$(call PRINT_COLOR, 3, removing per-run outputs)
	rm -rf *.out *.dump

clean_synth:
	@$(call PRINT_COLOR, 1, removing synthesis files)
	rm -rf synth
	rm -rf *.vg *_svsim.sv *.res *.rep *.ddc *.chk *.syn *-synth.out *.mr *.pvl command.log

.PHONY: clean nuke clean_%

######################
# ---- Printing ---- #
######################

# this is a GNU Make function with two arguments: PRINT_COLOR(color: number, msg: string)
# it does all the color printing throughout the makefile
PRINT_COLOR = if [ -t 0 ]; then tput setaf $(1) ; fi; echo $(2); if [ -t 0 ]; then tput sgr0; fi
# colors: 0:black, 1:red, 2:green, 3:yellow, 4:blue, 5:magenta, 6:cyan, 7:white
# other numbers are valid, but aren't specified in the tput man page

# Make functions are called like this:
# $(call PRINT_COLOR,3,Hello World!)
# NOTE: adding '@' to the start of a line avoids printing the command itself, only the output