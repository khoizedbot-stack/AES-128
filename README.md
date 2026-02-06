# AES-128 Encryption IP Core (AXI4-Lite)

Custom Xilinx IP core implementing AES-128 encryption with an AXI4-Lite slave interface, packaged for Vivado IP Integrator.

## Project Structure

```
AES-128/                          ← IP Repository Root
├── component.xml                 ← Vivado IP-XACT descriptor
├── hdl/                          ← RTL source (synthesis + simulation)
│   ├── aes128_axi_top.v          ← Top-level: AXI4-Lite wrapper
│   ├── axi4_lite_slave.v         ← AXI4-Lite slave register interface
│   ├── aes128_fsm_core.v         ← AES FSM controller (11-cycle latency)
│   ├── expand_key_top.v          ← Key expansion top
│   ├── expand_key_core_fix.v     ← Key expansion core
│   ├── encrypt_round.v           ← Standard AES round (rounds 1-9)
│   ├── encrypt_final_round.v     ← Final AES round (round 10)
│   ├── sub_bytes.v               ← SubBytes (S-Box lookup)
│   ├── shift_rows.v              ← ShiftRows
│   ├── mix_columns.v             ← MixColumns (GF(2^8))
│   └── add_round_key.v           ← AddRoundKey (XOR)
├── sim/                          ← Testbench (simulation only)
│   └── tb_aes128_axi.v           ← AXI4-Lite self-checking testbench
├── xgui/                         ← Vivado IP GUI customization
│   └── aes128_axi_top_v1_0.tcl
├── AES-128/                      ← Vivado IP packaging project (.xpr)
└── AES-128_SoC/                  ← Vivado SoC project (Zynq + Vitis)
    ├── AES-128_SoC.xpr           ← Vivado block design project
    ├── aes_128/src/              ← Vitis bare-metal application
    │   ├── main.c                ← HW/SW benchmark (performance test)
    │   └── aes.h                 ← SW AES-128 reference implementation
    └── aes/                      ← Vitis platform / BSP
```

## Register Map (AXI4-Lite, base + offset)

| Offset | Name         | Access | Description                    |
|--------|-------------|--------|--------------------------------|
| 0x00   | CTRL        | W      | [0]: start (auto-clear)        |
| 0x04   | STATUS      | R      | [0]: busy, [1]: done           |
| 0x08   | KEY_0       | R/W    | key[31:0]                      |
| 0x0C   | KEY_1       | R/W    | key[63:32]                     |
| 0x10   | KEY_2       | R/W    | key[95:64]                     |
| 0x14   | KEY_3       | R/W    | key[127:96]                    |
| 0x18   | PLAINTEXT_0 | R/W    | plaintext[31:0]                |
| 0x1C   | PLAINTEXT_1 | R/W    | plaintext[63:32]               |
| 0x20   | PLAINTEXT_2 | R/W    | plaintext[95:64]               |
| 0x24   | PLAINTEXT_3 | R/W    | plaintext[127:96]              |
| 0x28   | CIPHERTEXT_0| R      | ciphertext[31:0]               |
| 0x2C   | CIPHERTEXT_1| R      | ciphertext[63:32]              |
| 0x30   | CIPHERTEXT_2| R      | ciphertext[95:64]              |
| 0x34   | CIPHERTEXT_3| R      | ciphertext[127:96]             |

## Usage

1. Write `KEY_0` → `KEY_3` (128-bit key)
2. Write `PLAINTEXT_0` → `PLAINTEXT_3` (128-bit plaintext)
3. Write `0x1` to `CTRL` (trigger encryption)
4. Poll `STATUS` until `done` = 1 (~11 clock cycles)
5. Read `CIPHERTEXT_0` → `CIPHERTEXT_3`

## Parameters

| Parameter            | Default | Description            |
|----------------------|---------|------------------------|
| C_S_AXI_ADDR_WIDTH   | 6       | AXI address bus width  |
| C_S_AXI_DATA_WIDTH   | 32      | AXI data bus width     |

## Supported Families

Zynq-7000, Artix-7, Kintex-7, Virtex-7, Spartan-7, Zynq UltraScale+

## Tools

- Xilinx Vivado 2025.2
- Xilinx Vitis 2025.2
