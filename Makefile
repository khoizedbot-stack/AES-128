################################################################################
# FLEXIBLE MAKEFILE FOR AES-128
# Usage:
#   1. make all                  -> Chạy tất cả các testbench trong danh sách
#   2. make tb_aes128_optimized  -> Chỉ chạy testbench này
#   3. make tb_aes128_axi        -> Chỉ chạy testbench kia
################################################################################

# --- CẤU HÌNH DANH SÁCH TESTBENCH (Thêm tên module testbench vào đây) ---
# Lưu ý: Đây là tên MODULE trong file Verilog, không phải tên file .v
TEST_LIST = tb_aes128_axi_optimized tb_aes128_optimized

# --- CÁC BIẾN MẶC ĐỊNH ---
COMPILE_LIST = compile.f
LOG_DIR      = log
LIB_NAME     = work

# --- MỤC TIÊU CHÍNH (ALL) ---
# Khi gõ 'make all', nó sẽ gọi target 'compile' trước, sau đó gọi list các test
all: compile $(TEST_LIST)

# --- BƯỚC 1: BIÊN DỊCH (COMPILE) ---
compile:
	@echo "========================================"
	@echo "      COMPILING DESIGN & TESTBENCH      "
	@echo "========================================"
	mkdir -p $(LOG_DIR)
	if [ ! -d "$(LIB_NAME)" ]; then vlib.exe $(LIB_NAME); fi
	vmap.exe $(LIB_NAME) $(LIB_NAME)
	vlog.exe -coveropt 3 +cover +acc -f $(COMPILE_LIST)

# --- BƯỚC 2: CHẠY TESTBENCH (DYNAMIC RULE) ---
# Đây là phần quan trọng nhất.
# Nó định nghĩa quy tắc cho tất cả các tên nằm trong biến $(TEST_LIST)
$(TEST_LIST): compile
	@echo "----------------------------------------"
	@echo " RUNNING TEST: $@"
	@echo "----------------------------------------"
	# $@ chính là tên target bạn gõ (ví dụ: tb_aes128_optimized)
	vsim.exe -l $(LOG_DIR)/$@.log \
             -voptargs=+acc -assertdebug \
             -c $@ \
             -do "log -r /*; run -all; quit"
	
	@# Lưu waveform
	cp -rf vsim.wlf $(LOG_DIR)/$@.wlf
	@echo "Log saved to: $(LOG_DIR)/$@.log"

# --- TIỆN ÍCH KHÁC ---

# Mở sóng (Waveform) cho file cụ thể. VD: make wave TEST=tb_aes128_optimized
wave:
	vsim.exe -i -view $(LOG_DIR)/$(TEST).wlf -do "add wave vsim:/$(TEST)/*; radix -hex"

clean:
	rm -rf $(LIB_NAME)
	rm -rf $(LOG_DIR)
	rm -rf *.ini *.log *.wlf transcript coverage *.ucdb

# Báo cáo nhanh kết quả Pass/Fail
report:
	@echo "--- SUMMARY REPORT ---"
	@grep -E "PASS|FAIL|Error" $(LOG_DIR)/*.log || echo "No logs found."