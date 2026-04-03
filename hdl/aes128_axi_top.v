//==============================================================================
// Module: aes128_axi_top  (v2)
// Description: AES-128 IP with AXI4-Lite, supports enc and dec
//   Usage: write key → CTRL[2]=new_key → wait key_ready → write data
//          → CTRL[0]=start → wait done → read result
//==============================================================================
`timescale 1ns / 1ps

module aes128_axi_top #(
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire [2:0]                        S_AXI_AWPROT,
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
    input  wire [2:0]                        S_AXI_ARPROT,
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

    axi4_lite_slave #(
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) u_axi_slave (
        .S_AXI_ACLK    (S_AXI_ACLK),   .S_AXI_ARESETN (S_AXI_ARESETN),
        .S_AXI_AWADDR  (S_AXI_AWADDR),  .S_AXI_AWPROT  (S_AXI_AWPROT),
        .S_AXI_AWVALID (S_AXI_AWVALID), .S_AXI_AWREADY (S_AXI_AWREADY),
        .S_AXI_WDATA   (S_AXI_WDATA),   .S_AXI_WSTRB   (S_AXI_WSTRB),
        .S_AXI_WVALID  (S_AXI_WVALID),  .S_AXI_WREADY  (S_AXI_WREADY),
        .S_AXI_BRESP   (S_AXI_BRESP),   .S_AXI_BVALID  (S_AXI_BVALID),
        .S_AXI_BREADY  (S_AXI_BREADY),
        .S_AXI_ARADDR  (S_AXI_ARADDR),  .S_AXI_ARPROT  (S_AXI_ARPROT),
        .S_AXI_ARVALID (S_AXI_ARVALID), .S_AXI_ARREADY (S_AXI_ARREADY),
        .S_AXI_RDATA   (S_AXI_RDATA),   .S_AXI_RRESP   (S_AXI_RRESP),
        .S_AXI_RVALID  (S_AXI_RVALID),  .S_AXI_RREADY  (S_AXI_RREADY),
        .data_bus      (data_bus),
        .start         (start),
        .new_key       (new_key),
        .enc_dec       (enc_dec),
        .busy          (busy),
        .done          (done),
        .key_ready     (key_ready),
        .irq_out       (irq_done)
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