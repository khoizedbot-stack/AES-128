`timescale 1ns / 1ps
`default_nettype none
// ==============================================================================
// MODULE: Khoi Dieu khien Kenh Doc (Read Controller)
// ==============================================================================
module axil_aes128_rd #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6
)
(
    input  wire                   clk,
    input  wire                   aresetn,

    // AXI-Lite Read Channels
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    // Giao tiep voi Register File
    output wire [ADDR_WIDTH-1:0]  rd_addr,
    output wire                   rd_en,
    input  wire [DATA_WIDTH-1:0]  rd_data,
    input  wire                   rd_err
);

    reg ar_latched = 0;
    reg rvalid_reg = 0;
    reg [1:0] rresp_reg = 2'b00;

    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg [DATA_WIDTH-1:0] rdata_reg;

    assign s_axil_arready = !ar_latched;
    assign s_axil_rvalid  = rvalid_reg;
    assign s_axil_rresp   = rresp_reg;
    assign s_axil_rdata   = rdata_reg;

    assign rd_en   = ar_latched && !rvalid_reg;
    assign rd_addr = araddr_reg;

    always @(posedge clk) begin
        if (!aresetn) begin
            ar_latched <= 1'b0;
            rvalid_reg <= 1'b0;
            rresp_reg  <= 2'b00;
        end else begin
            
            if (s_axil_arvalid && !ar_latched) begin
                ar_latched <= 1'b1;
                araddr_reg <= s_axil_araddr;
            end

            if (rd_en) begin
                ar_latched <= 1'b0;
                
                rvalid_reg <= 1'b1;
                rdata_reg  <= rd_data; 
                rresp_reg  <= rd_err ? 2'b10 : 2'b00;
            end
            else if (rvalid_reg && s_axil_rready) begin
                rvalid_reg <= 1'b0;
            end

        end
    end

endmodule
`default_nettype wire
