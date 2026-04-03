// =============================================================================
// AES-128 RTL compile list — ModelSim vlog
// Order: leaf modules first, then higher-level modules
// =============================================================================

// --- Leaf transform modules (no RTL dependencies) ---
hdl/add_round_key.v
hdl/sub_bytes.v
hdl/inv_sub_bytes.v
hdl/shift_rows.v
hdl/inv_shift_rows.v
hdl/mix_columns.v
hdl/inv_mix_columns.v
hdl/expand_key_core_fix.v
hdl/axi4_lite_slave.v

// --- Round modules ---
hdl/encrypt_round.v
hdl/decrypt_round.v

// --- Key schedule ---
hdl/key_schedule.v

// --- Datapath FSM ---
hdl/aes128_datapath.v

// --- Top-level ---
hdl/aes128_top.v
hdl/aes128_axi_top.v

// =============================================================================
// Testbenches
// =============================================================================
// sim/tb_inv_sub_bytes.v
sim/tb_inv_shift_rows.v
// sim/tb_inv_mix_columns.v
// sim/tb_sub_bytes.v
// sim/tb_shift_rows.v
// sim/tb_mix_columns.v
sim/tb_decrypt_round.v
sim/tb_encrypt_round.v
sim/tb_key_schedule.v
sim/tb_aes128_datapath.v
sim/tb_aes128_top.v
sim/tb_axi4_lite_slave.v
sim/tb_aes128_axi.v
