// AES-128 RTL source files
hdl/sub_bytes.v
hdl/shift_rows.v
hdl/mix_columns.v
hdl/add_round_key.v
hdl/encrypt_round.v
hdl/encrypt_final_round.v
hdl/expand_key_core_fix.v
hdl/axi4_lite_slave.v
hdl/aes128_axi_top.v
hdl/aes128_datapath.v
hdl/aes128_top.v
hdl/key_gen.v

// Testbench
sim/tb_aes128_axi.v
sim/tb_aes128_datapath.v
sim/tb_encrypt_round.v
sim/tb_encrypt_final_round.v
sim/tb_key_gen.v
