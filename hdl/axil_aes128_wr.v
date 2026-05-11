`timescale 1ns / 1ps
`default_nettype none

module axil_aes128_wr #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6,
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                   clk,
    input  wire                   aresetn,

    // AXI-Lite Write Channels
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

    // Giao tiếp với Register File
    output wire [ADDR_WIDTH-1:0]  wr_addr,
    output wire [DATA_WIDTH-1:0]  wr_data,
    output wire [STRB_WIDTH-1:0]  wr_strb,
    output wire                   wr_en,
    input  wire                   wr_err
);

    reg aw_latched = 0;
    reg w_latched  = 0;
    reg bvalid_reg = 0;
    reg [1:0] bresp_reg = 2'b00;
    reg wr_en_reg  = 0;

    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg [STRB_WIDTH-1:0] wstrb_reg;

    assign s_axil_awready = !aw_latched; 
    assign s_axil_wready  = !w_latched;  

    assign s_axil_bvalid  = bvalid_reg;
    assign s_axil_bresp   = bresp_reg;

    assign wr_en = wr_en_reg;

    assign wr_addr = awaddr_reg;
    assign wr_data = wdata_reg;
    assign wr_strb = wstrb_reg;

    always @(posedge clk) begin
        if (!aresetn) begin
            aw_latched <= 1'b0;
            w_latched  <= 1'b0;
            wr_en_reg  <= 1'b0;
            bvalid_reg <= 1'b0;
            bresp_reg  <= 2'b00;
        end else begin
            
            if (s_axil_awvalid && !aw_latched) begin
                aw_latched <= 1'b1;
                awaddr_reg <= s_axil_awaddr;
            end
            
            if (s_axil_wvalid && !w_latched) begin
                w_latched <= 1'b1;
                wdata_reg <= s_axil_wdata;
                wstrb_reg <= s_axil_wstrb; 
            end

            if (aw_latched && w_latched && !wr_en_reg && !bvalid_reg) begin
                wr_en_reg <= 1'b1;
            end else if (wr_en_reg) begin
                wr_en_reg  <= 1'b0;
                aw_latched <= 1'b0; 
                w_latched  <= 1'b0; 
                
                bvalid_reg <= 1'b1;
                bresp_reg  <= wr_err ? 2'b10 : 2'b00;
            end else if (bvalid_reg && s_axil_bready) begin
                bvalid_reg <= 1'b0;
            end

        end
    end

endmodule
`default_nettype wire