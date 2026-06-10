//==============================================================================
// Module: aes128_axi_top  (v2)
// Description: AES-128 IP with AXI4-Lite, supports enc and dec
//   Usage: write key -> CTRL[2]=new_key -> wait key_ready -> write data
//          -> CTRL[0]=start -> wait done -> read result
//==============================================================================
`timescale 1ns / 1ps
`default_nettype none

module aes128_axi_top #(
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]   S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    output wire [1:0]                        S_AXI_BRESP,
    output wire                              S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output wire [1:0]                        S_AXI_RRESP,
    output wire                              S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,

    output wire                              irq_done
);

    wire [127:0] data_bus;
    wire         start, new_key, enc_dec;
    wire         busy, done, key_ready;

    // Instantiate AXI4-Lite Wrapper (Module name and parameter fixed)
    axil_aes128_slave #(
        .ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) u_axi_slave (
        .clk             (S_AXI_ACLK),    
        .aresetn         (S_AXI_ARESETN),
        
        .s_axil_awaddr   (S_AXI_AWADDR),  
        .s_axil_awvalid  (S_AXI_AWVALID), 
        .s_axil_awready  (S_AXI_AWREADY),
        .s_axil_wdata    (S_AXI_WDATA),   
        .s_axil_wstrb    (S_AXI_WSTRB),
        .s_axil_wvalid   (S_AXI_WVALID),  
        .s_axil_wready   (S_AXI_WREADY),
        .s_axil_bresp    (S_AXI_BRESP),   
        .s_axil_bvalid   (S_AXI_BVALID),
        .s_axil_bready   (S_AXI_BREADY),
        
        .s_axil_araddr   (S_AXI_ARADDR),  
        .s_axil_arvalid  (S_AXI_ARVALID), 
        .s_axil_arready  (S_AXI_ARREADY),
        .s_axil_rdata    (S_AXI_RDATA),   
        .s_axil_rresp    (S_AXI_RRESP),
        .s_axil_rvalid   (S_AXI_RVALID),  
        .s_axil_rready   (S_AXI_RREADY),
        
        // Interface with AES Core
        .data_bus        (data_bus),
        .start           (start),
        .new_key         (new_key),
        .enc_dec         (enc_dec),
        .busy            (busy),
        .done            (done),
        .key_ready       (key_ready),
        .irq_out         (irq_done)
    );

    aes128_top u_aes_core (
        .clk       (S_AXI_ACLK),
        .rst_n     (S_AXI_ARESETN),
        .start     (start),
        .new_key   (new_key),
        .enc_dec   (enc_dec),
        .data_bus  (data_bus),
        .busy      (busy),
        .done      (done),
        .key_ready (key_ready)
    );

endmodule