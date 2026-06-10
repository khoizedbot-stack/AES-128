`timescale 1ns / 1ps
`default_nettype none

// ==============================================================================
// MODULE: Write Controller (Xilinx registered-ready pattern)
//
// Thiet ke:
//   - AWREADY va WREADY la registered (flip-flop output), pulse HIGH 1 cycle
//   - Khi ca AW+W valid va aw_en=1: detect -> latch addr/data, set ready (NBA)
//   - wr_en = awready_reg && wready_reg (combinational, high sau detect NBA)
//   - BVALID len 1 cycle sau wr_en (registered)
//   - Khong co glitch tren ready signals (output hoan toan tu flip-flop)
//
// Timing (voi TB blocking-assignment pattern):
//   Posedge N  : TB set valid -> detect -> awready<=1, latch data (NBA)
//   N + #1     : awready=1, wr_en=1 (combinational)
//   Posedge N+1: Register file latch data, bvalid<=1 (NBA)
//   Posedge N+2: bvalid consumed (BREADY=1), aw_en re-enabled
//
// Ref: Xilinx AXI-Lite Slave Template (Vivado IP Packager)
// ==============================================================================
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

    // Interface with Register File
    output wire [ADDR_WIDTH-1:0]  wr_addr,
    output wire [DATA_WIDTH-1:0]  wr_data,
    output wire [STRB_WIDTH-1:0]  wr_strb,
    output wire                   wr_en,
    input  wire                   wr_err
);

    reg        awready_reg;
    reg        wready_reg;
    reg        bvalid_reg;
    reg [1:0]  bresp_reg;
    reg        aw_en;

    // Latch registers for addr/data/strb
    reg [ADDR_WIDTH-1:0] wr_addr_reg;
    reg [DATA_WIDTH-1:0] wr_data_reg;
    reg [STRB_WIDTH-1:0] wr_strb_reg;

    // Registered outputs
    assign s_axil_awready = awready_reg;
    assign s_axil_wready  = wready_reg;
    assign s_axil_bvalid  = bvalid_reg;
    assign s_axil_bresp   = bresp_reg;

    // -------------------------------------------------------------------------
    // Detect: AW+W both valid, controller ready, ready not yet asserted
    // -------------------------------------------------------------------------
    wire aw_w_detect = ~awready_reg && s_axil_awvalid && s_axil_wvalid && aw_en;

    // -------------------------------------------------------------------------
    // AWREADY: Registered, pulse 1 cycle khi detect
    // aw_en: cho phep nhan write moi, re-enable khi B consumed
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn) begin
            awready_reg <= 1'b0;
            aw_en       <= 1'b1;
        end else if (aw_w_detect) begin
            awready_reg <= 1'b1;
            aw_en       <= 1'b0;
        end else if (bvalid_reg && s_axil_bready) begin
            aw_en       <= 1'b1;
            awready_reg <= 1'b0;
        end else begin
            awready_reg <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // WREADY: Registered, pulse 1 cycle dong bo voi AWREADY
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn)
            wready_reg <= 1'b0;
        else if (aw_w_detect)
            wready_reg <= 1'b1;
        else
            wready_reg <= 1'b0;
    end

    // -------------------------------------------------------------------------
    // Latch AW+W data khi detect (cung posedge, NBA)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (aw_w_detect) begin
            wr_addr_reg <= s_axil_awaddr;
            wr_data_reg <= s_axil_wdata;
            wr_strb_reg <= s_axil_wstrb;
        end
    end

    // -------------------------------------------------------------------------
    // Register File interface
    // wr_en: combinational tu registered ready (cao sau detect NBA)
    // wr_addr/data/strb: tu latched registers
    // -------------------------------------------------------------------------
    assign wr_en   = awready_reg && wready_reg;
    assign wr_addr = wr_addr_reg;
    assign wr_data = wr_data_reg;
    assign wr_strb = wr_strb_reg;

    // -------------------------------------------------------------------------
    // BVALID: registered, 1 cycle sau wr_en
    // BRESP:  SLVERR (2'b10) neu wr_err, OKAY (2'b00) neu khong
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn) begin
            bvalid_reg <= 1'b0;
            bresp_reg  <= 2'b00;
        end else if (wr_en) begin
            bvalid_reg <= 1'b1;
            bresp_reg  <= wr_err ? 2'b10 : 2'b00;
        end else if (s_axil_bready) begin
            bvalid_reg <= 1'b0;
        end
    end

endmodule
`default_nettype wire