//==============================================================================
// Module: axi4_lite_slave
// Description: AXI4-Lite Slave Interface (Standard Compliant)
//              
// Register Map:
//   0x00: CTRL_REG      [W]   [0]:start (auto-clear)
//   0x04: STATUS_REG    [R]   [0]:busy, [1]:done
//   0x08: KEY_0         [R/W] key[31:0]
//   0x0C: KEY_1         [R/W] key[63:32]
//   0x10: KEY_2         [R/W] key[95:64]
//   0x14: KEY_3         [R/W] key[127:96]
//   0x18: PLAINTEXT_0   [R/W] plaintext[31:0]
//   0x1C: PLAINTEXT_1   [R/W] plaintext[63:32]
//   0x20: PLAINTEXT_2   [R/W] plaintext[95:64]
//   0x24: PLAINTEXT_3   [R/W] plaintext[127:96]
//   0x28: CIPHERTEXT_0  [R]   ciphertext[31:0]
//   0x2C: CIPHERTEXT_1  [R]   ciphertext[63:32]
//   0x30: CIPHERTEXT_2  [R]   ciphertext[95:64]
//   0x34: CIPHERTEXT_3  [R]   ciphertext[127:96]
//
// AXI4-Lite Compliance:
//   - All 5 channels implemented (AW, W, B, AR, R)
//   - Proper handshaking (valid/ready)
//   - 32-bit data width (standard for Lite)
//   - No burst support (as per Lite spec)
//==============================================================================

`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter C_S_AXI_ADDR_WIDTH = 6,   // 64 bytes address space
    parameter C_S_AXI_DATA_WIDTH = 32
)(
    //--------------------------------------------------------------------------
    // Global Signals
    //--------------------------------------------------------------------------
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    
    //--------------------------------------------------------------------------
    // Write Address Channel (AW)
    //--------------------------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,   // Ignored for simple slave
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    
    //--------------------------------------------------------------------------
    // Write Data Channel (W)
    //--------------------------------------------------------------------------
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]   S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    
    //--------------------------------------------------------------------------
    // Write Response Channel (B)
    //--------------------------------------------------------------------------
    output wire [1:0]                        S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    
    //--------------------------------------------------------------------------
    // Read Address Channel (AR)
    //--------------------------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire [2:0]                        S_AXI_ARPROT,   // Ignored for simple slave
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    
    //--------------------------------------------------------------------------
    // Read Data Channel (R)
    //--------------------------------------------------------------------------
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,
    
    //--------------------------------------------------------------------------
    // User Interface (to AES Core)
    //--------------------------------------------------------------------------
    output wire [127:0]                      key,
    output wire [127:0]                      plaintext,
    output wire                              start,
    
    input  wire                              busy,
    input  wire                              done,
    input  wire [127:0]                      ciphertext
);

    //==========================================================================
    // Local Parameters
    //==========================================================================
    
    // Register addresses (byte addresses, aligned to 4-byte boundary)
    localparam ADDR_CTRL        = 6'h00;
    localparam ADDR_STATUS      = 6'h04;
    localparam ADDR_KEY_0       = 6'h08;
    localparam ADDR_KEY_1       = 6'h0C;
    localparam ADDR_KEY_2       = 6'h10;
    localparam ADDR_KEY_3       = 6'h14;
    localparam ADDR_PLAINTEXT_0 = 6'h18;
    localparam ADDR_PLAINTEXT_1 = 6'h1C;
    localparam ADDR_PLAINTEXT_2 = 6'h20;
    localparam ADDR_PLAINTEXT_3 = 6'h24;
    localparam ADDR_CIPHER_0    = 6'h28;
    localparam ADDR_CIPHER_1    = 6'h2C;
    localparam ADDR_CIPHER_2    = 6'h30;
    localparam ADDR_CIPHER_3    = 6'h34;
    
    // AXI Response codes
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;
    
    //==========================================================================
    // Internal Registers
    //==========================================================================
    
    // Configuration registers
    reg [31:0] reg_ctrl;
    reg [31:0] reg_status;  // Sticky status: [0]:busy, [1]:done
    reg [31:0] reg_key_0, reg_key_1, reg_key_2, reg_key_3;
    reg [31:0] reg_pt_0, reg_pt_1, reg_pt_2, reg_pt_3;
    
    // AXI internal signals
    reg        axi_awready;
    reg        axi_wready;
    reg [1:0]  axi_bresp;
    reg        axi_bvalid;
    reg        axi_arready;
    reg [31:0] axi_rdata;
    reg [1:0]  axi_rresp;
    reg        axi_rvalid;
    
    // Latched addresses
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    
    // Write state
    reg aw_en;  // Write address enable
    
    //==========================================================================
    // AXI Output Assignments
    //==========================================================================
    
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;
    
    //==========================================================================
    // User Interface Assignments
    //==========================================================================
    
    assign key       = {reg_key_3, reg_key_2, reg_key_1, reg_key_0};
    assign plaintext = {reg_pt_3, reg_pt_2, reg_pt_1, reg_pt_0};
    assign start     = reg_ctrl[0];
    
    //==========================================================================
    // Write Address Channel (AW) - Ready Logic
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awready <= 1'b0;
            aw_en       <= 1'b1;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                // Accept write address when both address and data are valid
                axi_awready <= 1'b1;
                aw_en       <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                // Re-enable after response is accepted
                aw_en       <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end
    
    //==========================================================================
    // Write Address Latch
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_awaddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awaddr <= S_AXI_AWADDR;
            end
        end
    end
    
    //==========================================================================
    // Write Data Channel (W) - Ready Logic
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end
    
    //==========================================================================
    // Register Write Logic (with byte strobes)
    //==========================================================================
    
    // Helper function for byte-enable writes
    function [31:0] apply_wstrb;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0]  wstrb;
        begin
            apply_wstrb[7:0]   = wstrb[0] ? new_data[7:0]   : old_data[7:0];
            apply_wstrb[15:8]  = wstrb[1] ? new_data[15:8]  : old_data[15:8];
            apply_wstrb[23:16] = wstrb[2] ? new_data[23:16] : old_data[23:16];
            apply_wstrb[31:24] = wstrb[3] ? new_data[31:24] : old_data[31:24];
        end
    endfunction
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            reg_ctrl   <= 32'h0;
            reg_status <= 32'h0;
            reg_key_0  <= 32'h0;
            reg_key_1  <= 32'h0;
            reg_key_2  <= 32'h0;
            reg_key_3  <= 32'h0;
            reg_pt_0   <= 32'h0;
            reg_pt_1   <= 32'h0;
            reg_pt_2   <= 32'h0;
            reg_pt_3   <= 32'h0;
        end else begin
            // Auto-clear start bit & clear sticky status on new start
            if (reg_ctrl[0]) begin
                reg_ctrl[0]   <= 1'b0;
                reg_status    <= 32'h0;  // Clear status when start is issued
            end
            
            // Sticky latch: capture done/busy pulses from core
            if (busy) reg_status[0] <= 1'b1;
            if (done) reg_status[1] <= 1'b1;
            // When core finishes (done=1), busy should clear
            if (done) reg_status[0] <= 1'b0;
            
            // Register writes
            if (axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID) begin
                case (axi_awaddr)
                    ADDR_CTRL:        reg_ctrl  <= apply_wstrb(reg_ctrl,  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_0:       reg_key_0 <= apply_wstrb(reg_key_0, S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_1:       reg_key_1 <= apply_wstrb(reg_key_1, S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_2:       reg_key_2 <= apply_wstrb(reg_key_2, S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_KEY_3:       reg_key_3 <= apply_wstrb(reg_key_3, S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_PLAINTEXT_0: reg_pt_0  <= apply_wstrb(reg_pt_0,  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_PLAINTEXT_1: reg_pt_1  <= apply_wstrb(reg_pt_1,  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_PLAINTEXT_2: reg_pt_2  <= apply_wstrb(reg_pt_2,  S_AXI_WDATA, S_AXI_WSTRB);
                    ADDR_PLAINTEXT_3: reg_pt_3  <= apply_wstrb(reg_pt_3,  S_AXI_WDATA, S_AXI_WSTRB);
                    // CIPHERTEXT registers are read-only
                    default: ; // Ignore writes to undefined addresses
                endcase
            end
        end
    end
    
    //==========================================================================
    // Write Response Channel (B)
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= RESP_OKAY;
        end else begin
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= RESP_OKAY;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end
    
    //==========================================================================
    // Read Address Channel (AR) - Ready Logic
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_araddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end
    
    //==========================================================================
    // Read Data Channel (R) - Valid and Data Logic
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rresp  <= RESP_OKAY;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= RESP_OKAY;
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end
    
    //==========================================================================
    // Read Data Mux
    //==========================================================================
    
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rdata <= 32'h0;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                case (axi_araddr)
                    ADDR_CTRL:        axi_rdata <= reg_ctrl;
                    ADDR_STATUS:      axi_rdata <= reg_status;
                    ADDR_KEY_0:       axi_rdata <= reg_key_0;
                    ADDR_KEY_1:       axi_rdata <= reg_key_1;
                    ADDR_KEY_2:       axi_rdata <= reg_key_2;
                    ADDR_KEY_3:       axi_rdata <= reg_key_3;
                    ADDR_PLAINTEXT_0: axi_rdata <= reg_pt_0;
                    ADDR_PLAINTEXT_1: axi_rdata <= reg_pt_1;
                    ADDR_PLAINTEXT_2: axi_rdata <= reg_pt_2;
                    ADDR_PLAINTEXT_3: axi_rdata <= reg_pt_3;
                    ADDR_CIPHER_0:    axi_rdata <= ciphertext[31:0];
                    ADDR_CIPHER_1:    axi_rdata <= ciphertext[63:32];
                    ADDR_CIPHER_2:    axi_rdata <= ciphertext[95:64];
                    ADDR_CIPHER_3:    axi_rdata <= ciphertext[127:96];
                    default:          axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end
        end
    end

endmodule
