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
    // Latch registers for addr/data/strb
    reg [ADDR_WIDTH-1:0] wr_addr_reg;
    reg [DATA_WIDTH-1:0] wr_data_reg;
    reg [STRB_WIDTH-1:0] wr_strb_reg;

    // Flags to track if we have latched address/data for the current transaction
    reg aw_latched;
    reg w_latched;

    // Registered outputs
    assign s_axil_awready = awready_reg;
    assign s_axil_wready  = wready_reg;
    assign s_axil_bvalid  = bvalid_reg;
    assign s_axil_bresp   = bresp_reg;

    // -------------------------------------------------------------------------
    // Detect independent AW and W transactions
    // -------------------------------------------------------------------------
    wire aw_en = ~awready_reg && s_axil_awvalid && ~aw_latched;
    wire w_en  = ~wready_reg  && s_axil_wvalid  && ~w_latched;

    // -------------------------------------------------------------------------
    // AW Channel: Latch address independently
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn) begin
            awready_reg <= 1'b0;
            aw_latched  <= 1'b0;
            wr_addr_reg <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (aw_en) begin
                awready_reg <= 1'b1;
                wr_addr_reg <= s_axil_awaddr;
                aw_latched  <= 1'b1;
            end else begin
                awready_reg <= 1'b0;
                // Clear latched flag when transaction completes (BVALID & BREADY)
                if (bvalid_reg && s_axil_bready) begin
                    aw_latched <= 1'b0;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // W Channel: Latch data independently
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!aresetn) begin
            wready_reg  <= 1'b0;
            w_latched   <= 1'b0;
            wr_data_reg <= {DATA_WIDTH{1'b0}};
            wr_strb_reg <= {STRB_WIDTH{1'b0}};
        end else begin
            if (w_en) begin
                wready_reg  <= 1'b1;
                wr_data_reg <= s_axil_wdata;
                wr_strb_reg <= s_axil_wstrb;
                w_latched   <= 1'b1;
            end else begin
                wready_reg <= 1'b0;
                // Clear latched flag when transaction completes
                if (bvalid_reg && s_axil_bready) begin
                    w_latched <= 1'b0;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Register File interface
    // wr_en: combinational, asserts for 1 cycle when both are latched
    // wr_addr/data/strb: from latched registers
    // -------------------------------------------------------------------------
    assign wr_en   = aw_latched && w_latched && !bvalid_reg;
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