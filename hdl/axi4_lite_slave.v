//==============================================================================
// FILE: axi4_lite_slave_crypto.v 
// Description: AXI4-Lite Slave wrapper for Crypto Core with Hierarchical Design
//
// Register Map:
//   0x00: CTRL_REG   [W]   [0]=start  [1]=enc_dec  [2]=new_key  [3]=irq_en
//   0x04: STATUS_REG [R]   [0]=busy  [1]=done  [2]=key_ready
//   0x08-0x14: KEY_0..KEY_3       [R/W]
//   0x18-0x24: PLAINTEXT_0..3     [R/W]
//   0x28-0x34: CIPHERTEXT_0..3    [R]
//==============================================================================

`timescale 1ns / 1ps

// ==============================================================================
// 1. TOP MODULE: Nơi kết nối AXI và đi dây nội bộ
// ==============================================================================
module axi4_lite_slave #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
    // AXI Interface
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input wire  S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY,

    // User interface (Crypto Core)
    inout  wire [127:0] data_bus,
    output wire         start,
    output wire         new_key,
    output wire         enc_dec,
    input  wire         busy,
    input  wire         done,
    input  wire         key_ready,
    output wire         irq_out
);

    // --- Dây nối nội bộ (Internal Buses) ---
    wire                            mem_wr_en;
    wire [C_S_AXI_ADDR_WIDTH-1:0]   mem_wr_addr;
    wire [C_S_AXI_DATA_WIDTH-1:0]   mem_wr_data;
    wire [(C_S_AXI_DATA_WIDTH/8)-1:0] mem_wr_strb;
    wire                            mem_wr_error;

    wire [C_S_AXI_ADDR_WIDTH-1:0]   mem_rd_addr;
    wire [C_S_AXI_DATA_WIDTH-1:0]   mem_rd_data;
    wire                            mem_rd_en;
    wire                            mem_rd_error;

    // --- Khởi tạo khối điều khiển Ghi ---
    axi_lite_write_ctrl #(
        .ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) u_write_ctrl (
        .aclk        (S_AXI_ACLK),
        .areset_n    (S_AXI_ARESETN),
        .awaddr      (S_AXI_AWADDR),
        .awvalid     (S_AXI_AWVALID),
        .awready     (S_AXI_AWREADY),
        .wdata       (S_AXI_WDATA),
        .wstrb       (S_AXI_WSTRB),
        .wvalid      (S_AXI_WVALID),
        .wready      (S_AXI_WREADY),
        .bresp       (S_AXI_BRESP),
        .bvalid      (S_AXI_BVALID),
        .bready      (S_AXI_BREADY),
        // Nối vào bộ nhớ
        .mem_wr_en   (mem_wr_en),
        .mem_wr_addr (mem_wr_addr),
        .mem_wr_data (mem_wr_data),
        .mem_wr_strb (mem_wr_strb),
        .mem_wr_error(mem_wr_error)
    );

    // --- Khởi tạo khối điều khiển Đọc ---
    axi_lite_read_ctrl #(
        .ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) u_read_ctrl (
        .aclk        (S_AXI_ACLK),
        .areset_n    (S_AXI_ARESETN),
        .araddr      (S_AXI_ARADDR),
        .arvalid     (S_AXI_ARVALID),
        .arready     (S_AXI_ARREADY),
        .rdata       (S_AXI_RDATA),
        .rresp       (S_AXI_RRESP),
        .rvalid      (S_AXI_RVALID),
        .rready      (S_AXI_RREADY),
        // Nối vào bộ nhớ
        .mem_rd_addr (mem_rd_addr),
        .mem_rd_data (mem_rd_data),
        .mem_rd_en   (mem_rd_en),
        .mem_rd_error(mem_rd_error)
    );

    // --- Khởi tạo Tập thanh ghi (Register File) ---
    crypto_reg_file #(
        .ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_S_AXI_DATA_WIDTH)
    ) u_reg_file (
        .clk         (S_AXI_ACLK),
        .rst_n       (S_AXI_ARESETN),
        
        // Cổng nối với Write Ctrl
        .wr_en       (mem_wr_en),
        .wr_addr     (mem_wr_addr),
        .wr_data     (mem_wr_data),
        .wr_strb     (mem_wr_strb),
        .wr_error    (mem_wr_error),
        
        // Cổng nối với Read Ctrl
        .rd_en       (mem_rd_en),
        .rd_addr     (mem_rd_addr),
        .rd_data     (mem_rd_data),
        .rd_error    (mem_rd_error),
        
        // Cổng nối với Crypto Core
        .data_bus    (data_bus),
        .start       (start),
        .new_key     (new_key),
        .enc_dec     (enc_dec),
        .busy        (busy),
        .done        (done),
        .key_ready   (key_ready),
        .irq_out     (irq_out)
    );

endmodule


// ==============================================================================
// 2. SUB-MODULE: Điều khiển kênh Ghi (Write Control)
// ==============================================================================
module axi_lite_write_ctrl #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input  wire aclk,
    input  wire areset_n,
    input  wire [ADDR_WIDTH-1:0] awaddr,
    input  wire awvalid,
    output wire awready,
    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [(DATA_WIDTH/8)-1:0] wstrb,
    input  wire wvalid,
    output wire wready,
    output wire [1:0] bresp,
    output wire bvalid,
    input  wire bready,

    output wire mem_wr_en,
    output wire [ADDR_WIDTH-1:0] mem_wr_addr,
    output wire [DATA_WIDTH-1:0] mem_wr_data,
    output wire [(DATA_WIDTH/8)-1:0] mem_wr_strb,
    input  wire mem_wr_error
);
    reg awready_reg;
    reg wready_reg;
    reg bvalid_reg;
    reg [1:0] bresp_reg;

    assign awready = awready_reg;
    assign wready  = wready_reg;
    assign bvalid  = bvalid_reg;
    assign bresp   = bresp_reg;

    // Chốt tín hiệu xuống Memory Buffer
    assign mem_wr_en   = awready_reg && awvalid && wready_reg && wvalid;
    assign mem_wr_addr = awaddr;
    assign mem_wr_data = wdata;
    assign mem_wr_strb = wstrb;

    always @(posedge aclk) begin
        if (!areset_n) begin
            awready_reg <= 1'b0;
            wready_reg  <= 1'b0;
            bvalid_reg  <= 1'b0;
            bresp_reg   <= 2'b00;
        end else begin
            // Handshake Address & Data
            if (~awready_reg && awvalid && ~wready_reg && wvalid) begin
                awready_reg <= 1'b1;
                wready_reg  <= 1'b1;
                // Determine response based on error signal from register file
                bresp_reg   <= mem_wr_error ? 2'b10 : 2'b00; // SLVERR or OKAY
            end else begin
                awready_reg <= 1'b0;
                wready_reg  <= 1'b0;
            end

            // Response
            if (awready_reg && awvalid && wready_reg && wvalid) begin
                bvalid_reg <= 1'b1;
            end else if (bready && bvalid_reg) begin
                bvalid_reg <= 1'b0;
            end
        end
    end
endmodule


// ==============================================================================
// 3. SUB-MODULE: Điều khiển kênh Đọc (Read Control)
// ==============================================================================
module axi_lite_read_ctrl #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input  wire aclk,
    input  wire areset_n,
    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire arvalid,
    output wire arready,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire [1:0] rresp,
    output wire rvalid,
    input  wire rready,

    output wire mem_rd_en,
    output wire [ADDR_WIDTH-1:0] mem_rd_addr,
    input  wire [DATA_WIDTH-1:0] mem_rd_data,
    input  wire mem_rd_error
);
    reg arready_reg;
    reg rvalid_reg;
    reg [DATA_WIDTH-1:0] rdata_reg;
    reg [1:0] rresp_reg;

    assign arready = arready_reg;
    assign rvalid  = rvalid_reg;
    assign rresp   = rresp_reg;
    assign rdata   = rdata_reg;

    // Nối trực tiếp địa chỉ sang Register File
    assign mem_rd_addr = araddr;
    assign mem_rd_en   = arready_reg && arvalid; 

    always @(posedge aclk) begin
        if (!areset_n) begin
            arready_reg <= 1'b0;
            rvalid_reg  <= 1'b0;
            rdata_reg   <= 0;
            rresp_reg   <= 2'b00;
        end else begin
            // 1. Quản lý kênh Address (AR)
            if (~arready_reg && arvalid && ~rvalid_reg) begin
                arready_reg <= 1'b1;
            end 
            else if (arready_reg && arvalid) begin
                arready_reg <= 1'b0; 
            end

            // 2. Quản lý kênh Data (R)
            if (arready_reg && arvalid && ~rvalid_reg) begin
                rvalid_reg <= 1'b1;
                rdata_reg  <= mem_rd_data;
                rresp_reg  <= mem_rd_error ? 2'b10 : 2'b00; // SLVERR or OKAY
            end 
            else if (rvalid_reg && rready) begin
                rvalid_reg <= 1'b0;
            end
        end
    end
endmodule


// ==============================================================================
// 4. SUB-MODULE: Lõi thanh ghi & Giao tiếp Crypto Core
// ==============================================================================
module crypto_reg_file #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    
    // Nối với Write Ctrl
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire [(DATA_WIDTH/8)-1:0] wr_strb,
    output wire wr_error,
    
    // Nối với Read Ctrl
    input  wire rd_en, 
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire rd_error,
    
    // Nối với User App (Crypto)
    inout  wire [127:0] data_bus,
    output wire start,
    output wire new_key,
    output wire enc_dec,
    input  wire busy,
    input  wire done,
    input  wire key_ready,
    output wire irq_out
);
    // Address Map
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

    // Registers
    reg [31:0] reg_ctrl;
    reg [31:0] reg_status;
    reg [31:0] reg_key_0, reg_key_1, reg_key_2, reg_key_3;
    reg [31:0] reg_pt_0,  reg_pt_1,  reg_pt_2,  reg_pt_3;
    reg [31:0] reg_cipher_0, reg_cipher_1, reg_cipher_2, reg_cipher_3;
    
    reg [127:0] bus_out_r;
    reg         bus_oe_r;

    // Error detection
    // Write error: address unmapped or read-only (STATUS, CIPHER)
    assign wr_error = !((wr_addr == ADDR_CTRL) || 
                        (wr_addr >= ADDR_KEY_0 && wr_addr <= ADDR_KEY_3) ||
                        (wr_addr >= ADDR_PLAINTEXT_0 && wr_addr <= ADDR_PLAINTEXT_3));
    
    // Read error: address unmapped (beyond CIPHER_3)
    assign rd_error = (rd_addr > ADDR_CIPHER_3);

    // Crypto Outputs
    assign enc_dec = reg_ctrl[1];
    
    reg start_r, new_key_r;
    always @(posedge clk) begin
        if (!rst_n) begin
            start_r <= 1'b0;
            new_key_r <= 1'b0;
        end else begin
            start_r <= reg_ctrl[0];
            new_key_r <= reg_ctrl[2];
        end
    end
    assign start = start_r;
    assign new_key = new_key_r;
    
    // Xuất ngắt khi hoàn thành (nếu bit irq_en được bật)
    assign irq_out = done & reg_ctrl[3];

    // Hàm áp dụng Byte-Enable (wstrb)
    function [31:0] apply_wstrb;
        input [31:0] old_data, new_data;
        input [4:0]  wstrb; // Use 4 bits, changed to 5 to avoid warning if any
        begin
            apply_wstrb[7:0]   = wstrb[0] ? new_data[7:0]   : old_data[7:0];
            apply_wstrb[15:8]  = wstrb[1] ? new_data[15:8]  : old_data[15:8];
            apply_wstrb[23:16] = wstrb[2] ? new_data[23:16] : old_data[23:16];
            apply_wstrb[31:24] = wstrb[3] ? new_data[31:24] : old_data[31:24];
        end
    endfunction

    // Logic xử lý Ghi và cập nhật Trạng thái
    always @(posedge clk) begin
        if (!rst_n) begin
            reg_ctrl   <= 32'h0;
            reg_status <= 32'h0;
            reg_key_0  <= 32'h0;  reg_key_1 <= 32'h0;
            reg_key_2  <= 32'h0;  reg_key_3 <= 32'h0;
            reg_pt_0   <= 32'h0;  reg_pt_1  <= 32'h0;
            reg_pt_2   <= 32'h0;  reg_pt_3  <= 32'h0;
            reg_cipher_0 <= 32'h0; reg_cipher_1 <= 32'h0;
            reg_cipher_2 <= 32'h0; reg_cipher_3 <= 32'h0;
            bus_out_r    <= 128'b0;
            bus_oe_r     <= 1'b1;
        end else begin
            // 1. Logic tự động xóa bit (Auto-clear)
            if (reg_ctrl[0]) reg_ctrl[0] <= 1'b0;
            if (reg_ctrl[2]) reg_ctrl[2] <= 1'b0;
            
            // 2. Logic cập nhật Status
            if (busy)      reg_status[0] <= 1'b1;
            if (done)      reg_status[1] <= 1'b1;
            if (done)      reg_status[0] <= 1'b0;
            if (key_ready) reg_status[2] <= 1'b1;
            
            if (reg_ctrl[0]) reg_status[1:0] <= 2'b00;
            if (reg_ctrl[2]) reg_status      <= 32'h0;

            // 3. Logic Ghi từ AXI Master
            if (wr_en && !wr_error) begin
                case (wr_addr)
                    ADDR_CTRL:        reg_ctrl  <= apply_wstrb(reg_ctrl,  wr_data, wr_strb);
                    ADDR_KEY_0:       reg_key_0 <= apply_wstrb(reg_key_0, wr_data, wr_strb);
                    ADDR_KEY_1:       reg_key_1 <= apply_wstrb(reg_key_1, wr_data, wr_strb);
                    ADDR_KEY_2:       reg_key_2 <= apply_wstrb(reg_key_2, wr_data, wr_strb);
                    ADDR_KEY_3:       reg_key_3 <= apply_wstrb(reg_key_3, wr_data, wr_strb);
                    ADDR_PLAINTEXT_0: reg_pt_0  <= apply_wstrb(reg_pt_0,  wr_data, wr_strb);
                    ADDR_PLAINTEXT_1: reg_pt_1  <= apply_wstrb(reg_pt_1,  wr_data, wr_strb);
                    ADDR_PLAINTEXT_2: reg_pt_2  <= apply_wstrb(reg_pt_2,  wr_data, wr_strb);
                    ADDR_PLAINTEXT_3: reg_pt_3  <= apply_wstrb(reg_pt_3,  wr_data, wr_strb);
                    default: ; 
                endcase
            end

            // 4. Logic tương tác với data_bus
            if (done) begin
                reg_cipher_0 <= data_bus[31:0];
                reg_cipher_1 <= data_bus[63:32];
                reg_cipher_2 <= data_bus[95:64];
                reg_cipher_3 <= data_bus[127:96];
                bus_oe_r     <= 1'b0;
            end

            if (reg_ctrl[0]) begin
                bus_out_r <= {reg_pt_3,  reg_pt_2,  reg_pt_1,  reg_pt_0};
                bus_oe_r  <= 1'b1;
            end
            if (reg_ctrl[2]) begin
                bus_out_r <= {reg_key_3, reg_key_2, reg_key_1, reg_key_0};
                bus_oe_r  <= 1'b1;
            end
        end
    end

    // Giao tiếp inout
    assign data_bus = (bus_oe_r && !done) ? bus_out_r : 128'bz;

    // 5. Logic Đọc trả về cho AXI Master
    always @(*) begin
        case (rd_addr)
            ADDR_CTRL:        rd_data = reg_ctrl;
            ADDR_STATUS:      rd_data = reg_status;
            ADDR_KEY_0:       rd_data = reg_key_0;
            ADDR_KEY_1:       rd_data = reg_key_1;
            ADDR_KEY_2:       rd_data = reg_key_2;
            ADDR_KEY_3:       rd_data = reg_key_3;
            ADDR_PLAINTEXT_0: rd_data = reg_pt_0;
            ADDR_PLAINTEXT_1: rd_data = reg_pt_1;
            ADDR_PLAINTEXT_2: rd_data = reg_pt_2;
            ADDR_PLAINTEXT_3: rd_data = reg_pt_3;
            ADDR_CIPHER_0:    rd_data = reg_cipher_0;
            ADDR_CIPHER_1:    rd_data = reg_cipher_1;
            ADDR_CIPHER_2:    rd_data = reg_cipher_2;
            ADDR_CIPHER_3:    rd_data = reg_cipher_3;
            default:          rd_data = 32'hDEAD_BEEF; // Debug value
        endcase
    end

endmodule