//==============================================================================
// Module: aes128_axi_top
// Description: AES-128 IP with AXI4-Lite Interface
//              Top-level wrapper connecting AXI4-Lite slave to AES core
//
// Memory Map:
//   0x00: CTRL        [W]   [0]:start (auto-clear)
//   0x04: STATUS      [R]   [0]:busy, [1]:done
//   0x08: KEY_0       [R/W] key[31:0]
//   0x0C: KEY_1       [R/W] key[63:32]
//   0x10: KEY_2       [R/W] key[95:64]
//   0x14: KEY_3       [R/W] key[127:96]
//   0x18: PLAINTEXT_0 [R/W] plaintext[31:0]
//   0x1C: PLAINTEXT_1 [R/W] plaintext[63:32]
//   0x20: PLAINTEXT_2 [R/W] plaintext[95:64]
//   0x24: PLAINTEXT_3 [R/W] plaintext[127:96]
//   0x28: CIPHERTEXT_0[R]   ciphertext[31:0]
//   0x2C: CIPHERTEXT_1[R]   ciphertext[63:32]
//   0x30: CIPHERTEXT_2[R]   ciphertext[95:64]
//   0x34: CIPHERTEXT_3[R]   ciphertext[127:96]
//
// Usage:
//   1. Write KEY_0 to KEY_3
//   2. Write PLAINTEXT_0 to PLAINTEXT_3
//   3. Write 0x1 to CTRL (start)
//   4. Poll STATUS until done=1 (or wait ~12 cycles)
//   5. Read CIPHERTEXT_0 to CIPHERTEXT_3
//==============================================================================

`timescale 1ns / 1ps

module aes128_axi_top #(
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32
)(
    //--------------------------------------------------------------------------
    // AXI4-Lite Slave Interface
    //--------------------------------------------------------------------------
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    
    // Write Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    
    // Write Data Channel
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]   S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    
    // Write Response Channel
    output wire [1:0]                        S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    
    // Read Address Channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    
    // Read Data Channel
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,
    
    //--------------------------------------------------------------------------
    // Optional: Interrupt output
    //--------------------------------------------------------------------------
    output wire                              irq_done
);

    //==========================================================================
    // Internal Signals
    //==========================================================================
    
    // AXI Slave to AES Core
    wire [127:0] key;
    wire [127:0] plaintext;
    wire         start;
    
    // AES Core to AXI Slave
    wire         busy;
    wire         done;
    wire [127:0] ciphertext;
    
    //==========================================================================
    // Interrupt output
    //==========================================================================
    assign irq_done = done;
    
    //==========================================================================
    // AXI4-Lite Slave Instance
    //==========================================================================
    
    axi4_lite_slave #(
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) u_axi_slave (
        // AXI Interface
        .S_AXI_ACLK    (S_AXI_ACLK),
        .S_AXI_ARESETN (S_AXI_ARESETN),
        
        .S_AXI_AWADDR  (S_AXI_AWADDR),
        .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID),
        .S_AXI_AWREADY (S_AXI_AWREADY),
        
        .S_AXI_WDATA   (S_AXI_WDATA),
        .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),
        .S_AXI_WREADY  (S_AXI_WREADY),
        
        .S_AXI_BRESP   (S_AXI_BRESP),
        .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),
        
        .S_AXI_ARADDR  (S_AXI_ARADDR),
        .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID),
        .S_AXI_ARREADY (S_AXI_ARREADY),
        
        .S_AXI_RDATA   (S_AXI_RDATA),
        .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),
        .S_AXI_RREADY  (S_AXI_RREADY),
        
        // User Interface
        .key           (key),
        .plaintext     (plaintext),
        .start         (start),
        .busy          (busy),
        .done          (done),
        .ciphertext    (ciphertext)
    );
    
    //==========================================================================
    // AES-128 Core Instance
    //==========================================================================
    
    aes128_fsm_core u_aes_core (
        .clk        (S_AXI_ACLK),
        .rst_n      (S_AXI_ARESETN),
        
        .key        (key),
        .plain_text (plaintext),
        .start      (start),
        
        .busy       (busy),
        .done       (done),
        .cipher_text(ciphertext)
    );

endmodule
