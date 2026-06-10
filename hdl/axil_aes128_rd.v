`timescale 1ns / 1ps
`default_nettype none

// ==============================================================================
// MODULE: Read Controller (Xilinx registered-ready pattern)
//
// Thiet ke:
//   - ARREADY la registered (flip-flop output), pulse HIGH 1 cycle
//   - Khi ARVALID va ar_en=1: detect -> latch addr, set ready (NBA)
//   - rd_en = arready_reg (combinational, high sau detect NBA)
//   - RVALID + RDATA len 1 cycle sau rd_en (registered)
//   - rd_data tu reg_file la combinational => valid khi rd_addr stable
//   - Khong co glitch tren ready signal
//
// Timing:
//   Posedge N  : TB set ARVALID=1 -> detect -> arready<=1, latch addr (NBA)
//   N + #1     : arready=1, rd_en=1, rd_addr=latched
//   Posedge N+1: RVALID<=1, RDATA<=rd_data (registered capture)
//   Posedge N+2: RVALID consumed (RREADY=1), ar_en re-enabled
//
// Ref: Xilinx AXI-Lite Slave Template (Vivado IP Packager)
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

    // Interface with Register File
    output wire [ADDR_WIDTH-1:0]  rd_addr,
    output wire                   rd_en,
    input  wire [DATA_WIDTH-1:0]  rd_data,
    input  wire                   rd_err
);

    reg                  arready_reg;
    reg                  rvalid_reg;
    reg [1:0]            rresp_reg;
    reg [DATA_WIDTH-1:0] rdata_reg;
    reg                  ar_en;
    reg [ADDR_WIDTH-1:0] rd_addr_reg;

    // Registered outputs
    assign s_axil_arready = arready_reg;
    assign s_axil_rvalid  = rvalid_reg;
    assign s_axil_rdata   = rdata_reg;
    assign s_axil_rresp   = rresp_reg;

    // -------------------------------------------------------------------------
    // Detect: AR valid, controller ready, ready not yet asserted
    // -------------------------------------------------------------------------
    wire ar_detect = ~arready_reg && s_axil_arvalid && ar_en;

    // -------------------------------------------------------------------------
    // ARREADY: Registered, pulse 1 cycle khi detect
    // ar_en: cho phep nhan read moi, re-enable khi R consumed
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn) begin
            arready_reg <= 1'b0;
            ar_en       <= 1'b1;
        end else if (ar_detect) begin
            arready_reg <= 1'b1;
            ar_en       <= 1'b0;
        end else if (rvalid_reg && s_axil_rready) begin
            ar_en       <= 1'b1;
            arready_reg <= 1'b0;
        end else begin
            arready_reg <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Latch address khi detect (cung posedge, NBA)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (ar_detect)
            rd_addr_reg <= s_axil_araddr;
    end

    // -------------------------------------------------------------------------
    // Register File interface
    // rd_en: high khi arready_reg=1 (sau detect NBA)
    // rd_addr: tu latched register
    // rd_data: combinational output tu reg_file
    // -------------------------------------------------------------------------
    assign rd_en   = arready_reg;
    assign rd_addr = rd_addr_reg;

    // -------------------------------------------------------------------------
    // RVALID + RDATA: registered, 1 cycle sau rd_en
    // Capture rd_data (combinational tu reg_file) khi arready_reg=1
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn) begin
            rvalid_reg <= 1'b0;
            rdata_reg  <= {DATA_WIDTH{1'b0}};
            rresp_reg  <= 2'b00;
        end else if (arready_reg) begin
            rvalid_reg <= 1'b1;
            rdata_reg  <= rd_data;
            rresp_reg  <= rd_err ? 2'b10 : 2'b00;
        end else if (s_axil_rready) begin
            rvalid_reg <= 1'b0;
        end
    end

endmodule
`default_nettype wire