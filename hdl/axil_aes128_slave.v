`timescale 1ns / 1ps
`default_nettype none

// ==============================================================================
// FILE: axil_aes128_slave.v
// Description: AXI4-Lite Slave wrapper for AES-128 Core.
// ==============================================================================
module axil_aes128_slave #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   aresetn,

    /* AXI-Lite Interface */
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    /* UPDATE: NEW AES-128 Core Interface */
    inout  wire [127:0]           data_bus,
    output wire                   start,
    output wire                   new_key,
    output wire                   enc_dec,
    input  wire                   busy,
    input  wire                   done,
    input  wire                   key_ready,
    output wire                   irq_out
);

    // Internal Wires
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [DATA_WIDTH-1:0] wr_data;
    wire [STRB_WIDTH-1:0] wr_strb;
    wire                  wr_en;
    wire                  wr_err;

    wire [ADDR_WIDTH-1:0] rd_addr;
    wire                  rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  rd_err;

    // --- Instantiate Write Block ---
    axil_aes128_wr #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_wr_ctrl (
        .clk(clk), .aresetn(aresetn),
        .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
        .wr_addr(wr_addr), .wr_data(wr_data), .wr_strb(wr_strb), .wr_en(wr_en), .wr_err(wr_err)
    );

    // --- Instantiate Read Block ---
    axil_aes128_rd #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_rd_ctrl (
        .clk(clk), .aresetn(aresetn),
        .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
        .rd_addr(rd_addr), .rd_en(rd_en), .rd_data(rd_data), .rd_err(rd_err)
    );

    // --- UPDATE: Instantiate Register File Block ---
    crypto_reg_file #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_reg_file (
        .clk        (clk), 
        .rst_n      (aresetn),      // Map AXI aresetn to reg file rst_n
        
        // Write port
        .wr_addr    (wr_addr), 
        .wr_data    (wr_data), 
        .wr_strb    (wr_strb), 
        .wr_en      (wr_en), 
        .wr_error   (wr_err),       // Map wr_error
        
        // Read port
        .rd_addr    (rd_addr), 
        .rd_en      (rd_en), 
        .rd_data    (rd_data), 
        .rd_error   (rd_err),       // Map rd_error
        
        // Crypto Core port
        .data_bus   (data_bus),
        .start      (start), 
        .new_key    (new_key),
        .enc_dec    (enc_dec),
        .busy       (busy), 
        .done       (done),
        .key_ready  (key_ready),
        .irq_out    (irq_out)
    );

endmodule
`default_nettype wire