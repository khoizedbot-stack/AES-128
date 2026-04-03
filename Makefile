################################################################################
# AES-128 Simulation Makefile — ModelSim (vlog / vsim)
#
# Usage:
#   make all                  — compile + run all testbenches
#   make compile              — compile only (skips if sources unchanged)
#   make tb_key_schedule      — compile if needed, then run one testbench
#   make wave TEST=tb_xxx     — open waveform viewer for a saved .wlf
#   make report               — print PASS/FAIL summary from all logs
#   make clean                — remove build artefacts
################################################################################

LIB_NAME  = work
LOG_DIR   = log
COMPILE_F = compile.f

# Sentinel file: rebuilt only when HDL or TB sources change
COMPILED  = $(LIB_NAME)/.compiled

# --------------------------------------------------------------------------
# Tool Configuration
# --------------------------------------------------------------------------
# If the tools are not in your PATH, specify the directory here:
BIN_DIR   = D:/Questasim/win64

VLIB = $(BIN_DIR)/vlib.exe
VMAP = $(BIN_DIR)/vmap.exe
VLOG = $(BIN_DIR)/vlog.exe
VSIM = $(BIN_DIR)/vsim.exe

# --------------------------------------------------------------------------
# Testbench list (Verilog module names, one per line)
# --------------------------------------------------------------------------
TEST_LIST = \
	tb_inv_shift_rows  \
	tb_decrypt_round   \
	tb_encrypt_round   \
	tb_key_schedule    \
	tb_aes128_datapath \
	tb_aes128_top      \
	tb_axi4_lite_slave     \
	tb_aes128_axi_optimized

# Note: The following testbenches are missing from sim/ directory:
# tb_inv_sub_bytes, tb_inv_mix_columns, tb_sub_bytes, tb_shift_rows, tb_mix_columns

# --------------------------------------------------------------------------
.PHONY: all compile clean report wave $(TEST_LIST)
# --------------------------------------------------------------------------

# --- all: compile once, then run every testbench --------------------------
all: $(COMPILED) $(TEST_LIST)

# --- compile target (alias for the sentinel) ------------------------------
compile: $(COMPILED)

# --- Sentinel: rebuild only when sources or compile.f change --------------
$(COMPILED): $(COMPILE_F) $(wildcard hdl/*.v) $(wildcard sim/*.v)
	@echo "========================================"
	@echo "   COMPILING DESIGN + TESTBENCHES"
	@echo "========================================"
	@if [ ! -d "$(LOG_DIR)" ]; then mkdir $(LOG_DIR); fi
	@if [ ! -d "$(LIB_NAME)" ]; then $(VLIB) $(LIB_NAME); fi
	@$(VMAP) $(LIB_NAME) $(LIB_NAME)
	$(VLOG) -coveropt 3 +cover +acc -f $(COMPILE_F)
	@touch $(COMPILED)
	@echo "========================================"
	@echo "   COMPILE DONE"
	@echo "========================================"

# --- Per-testbench rule (shared by all names in TEST_LIST) ----------------
$(TEST_LIST): $(COMPILED)
	@echo ""
	@echo "========================================"
	@echo "  RUNNING: $@"
	@echo "========================================"
	$(VSIM) -l $(LOG_DIR)/$@.log \
	         -voptargs="+acc" \
	         -c $@ \
	         -do "add wave -recursive /$@/dut/*; log -r /*; run -all; quit"
	@-cp vsim.wlf $(LOG_DIR)/$@.wlf 2>/dev/null || true
	@echo ""
	@grep -E "(PASS|FAIL|Summary)" $(LOG_DIR)/$@.log 2>/dev/null | tail -5 || true
	@echo "  Log saved: $(LOG_DIR)/$@.log"

# --- wave: open waveform for a specific test ------------------------------
wave:
	@[ -n "$(TEST)" ] || (echo "Usage: make wave TEST=<tb_name>" && exit 1)
	$(VSIM) -i -view $(LOG_DIR)/$(TEST).wlf \
	         -do "add wave -r /*; radix -hex"

# --- report: PASS/FAIL summary across all logs ----------------------------
report:
	@echo ""
	@echo "========================================"
	@echo "         SIMULATION REPORT"
	@echo "========================================"
	@for tb in $(TEST_LIST); do \
		log="$(LOG_DIR)/$$tb.log"; \
		if [ -f "$$log" ]; then \
			pass=$$(grep -c " PASS" "$$log" 2>/dev/null || echo 0); \
			fail=$$(grep -c " FAIL" "$$log" 2>/dev/null || echo 0); \
			printf "  %-28s  PASS=%-3s  FAIL=%-3s\n" "$$tb" "$$pass" "$$fail"; \
		else \
			printf "  %-28s  (not run)\n" "$$tb"; \
		fi; \
	done
	@echo "========================================"

# --- clean ----------------------------------------------------------------
clean:
	rm -rf $(LIB_NAME) $(LOG_DIR)
	rm -f *.ini *.log *.wlf transcript *.ucdb
