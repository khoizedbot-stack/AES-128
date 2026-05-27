`timescale 1ns / 1ps
`default_nettype none

module crypto_reg_file #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 32
)(
    input  wire clk,
    input  wire rst_n,
    
    // Ná»‘i vá»›i Write Ctrl
    input  wire wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire [(DATA_WIDTH/8)-1:0] wr_strb,
    output wire wr_error,
    
    // Ná»‘i vá»›i Read Ctrl
    input  wire rd_en, 
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire rd_error,
    
    // Ná»‘i vá»›i User App (Crypto)
    inout  wire [127:0] data_bus,
    output wire start,
    output wire new_key,
    output wire enc_dec,
    input  wire busy,
    input  wire done,
    input  wire key_ready,
    output wire irq_out
);
    // =========================================================================
    // ADDRESS MAP & PARAMETERS
    // =========================================================================
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

    // =========================================================================
    // REGISTERS DECLARATION
    // =========================================================================
    reg [31:0] reg_ctrl;
    reg [31:0] reg_status;
    reg [31:0] reg_key_0, reg_key_1, reg_key_2, reg_key_3;
    reg [31:0] reg_pt_0,  reg_pt_1,  reg_pt_2,  reg_pt_3;
    reg [31:0] reg_cipher_0, reg_cipher_1, reg_cipher_2, reg_cipher_3;
    
    reg [127:0] bus_out_r;
    reg         bus_oe_r;

    // =========================================================================
    // TÃ�N HIá»†U Lá»–I & Káº¾T Ná»�I TÄ¨NH
    // =========================================================================
    assign wr_error = !((wr_addr == ADDR_CTRL) || 
                        (wr_addr >= ADDR_KEY_0 && wr_addr <= ADDR_KEY_3) ||
                        (wr_addr >= ADDR_PLAINTEXT_0 && wr_addr <= ADDR_PLAINTEXT_3));
    
    assign rd_error = (rd_addr > ADDR_CIPHER_3);
    assign enc_dec  = reg_ctrl[1];
    assign irq_out  = done & reg_ctrl[3];

    // =========================================================================
    // HÃ€M APPLY WSTRB
    // =========================================================================
    function [31:0] apply_wstrb;
        input [31:0] old_data, new_data;
        input [3:0]  wstrb; 
        begin
            apply_wstrb[7:0]   = wstrb[0] ? new_data[7:0]   : old_data[7:0];
            apply_wstrb[15:8]  = wstrb[1] ? new_data[15:8]  : old_data[15:8];
            apply_wstrb[23:16] = wstrb[2] ? new_data[23:16] : old_data[23:16];
            apply_wstrb[31:24] = wstrb[3] ? new_data[31:24] : old_data[31:24];
        end
    endfunction


    // =========================================================================
    // KHá»�I 1: Xá»¬ LÃ� GIAO TIáº¾P AES 128 (PROCESS BLOCK)
    // =========================================================================
    reg start_r, new_key_r;
    assign start    = start_r;
    assign new_key  = new_key_r;
    assign data_bus = (bus_oe_r && !done) ? bus_out_r : 128'bz;

    always @(posedge clk) begin
        if (!rst_n) begin
            start_r      <= 1'b0;
            new_key_r    <= 1'b0;
            bus_out_r    <= 128'b0;
            bus_oe_r     <= 1'b1;   // <--- Sá»¬A á»ž Ä�Ã‚Y: Cho phÃ©p khá»‘i AXI chiáº¿m quyá»�n Ã©p data_bus = 0 lÃºc reset
            reg_status   <= 32'h0;
            reg_cipher_0 <= 32'h0; reg_cipher_1 <= 32'h0;
            reg_cipher_2 <= 32'h0; reg_cipher_3 <= 32'h0;
        end else begin
            // start_r chỉ là pulse 1 chu kỳ.
            // Không chờ busy kéo xuống nữa, vì busy phản hồi trễ 1 clock.
            start_r <= 1'b0;

            // --- 1. KÃ�CH HOáº T Lá»†NH ---
            if (reg_ctrl[0] && !busy) begin
                start_r   <= 1'b1;
                bus_out_r <= {reg_pt_3,  reg_pt_2,  reg_pt_1,  reg_pt_0};
                bus_oe_r  <= 1'b1;
            end
            
            if (reg_ctrl[2] && !busy) begin
                new_key_r <= 1'b1;
                bus_out_r <= {reg_key_3, reg_key_2, reg_key_1, reg_key_0};
                bus_oe_r  <= 1'b1;
            end

            // --- 2. Há»¦Y Lá»†NH (ACKNOWLEDGE) ---
            if (busy) begin
                new_key_r <= 1'b0;
            end

            // --- 3. Báº®T Káº¾T QUáº¢ KHI XONG ---
            if (done) begin
                reg_cipher_0 <= data_bus[31:0];
                reg_cipher_1 <= data_bus[63:32];
                reg_cipher_2 <= data_bus[95:64];
                reg_cipher_3 <= data_bus[127:96];
                bus_oe_r     <= 1'b0; // Thu há»“i quyá»�n Ä‘áº©y bus
            end

            // --- 4. Cáº¬P NHáº¬T STATUS FLAGS ---
            reg_status[0] <= busy;               
            if (done)      reg_status[1] <= 1'b1;
            if (key_ready) reg_status[2] <= 1'b1;
            
            if (reg_ctrl[0]) reg_status[1] <= 1'b0;
            if (reg_ctrl[2]) reg_status[2] <= 1'b0;
        end
    end


    // =========================================================================
    // KHá»�I 2: LOGIC Xá»¬ LÃ� GHI Tá»ª AXI MASTER (WRITE BLOCK)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            reg_ctrl   <= 32'h0;
            reg_key_0  <= 32'h0;  reg_key_1 <= 32'h0;
            reg_key_2  <= 32'h0;  reg_key_3 <= 32'h0;
            reg_pt_0   <= 32'h0;  reg_pt_1  <= 32'h0;
            reg_pt_2   <= 32'h0;  reg_pt_3  <= 32'h0;
        end else begin
            if (reg_ctrl[0]) reg_ctrl[0] <= 1'b0;
            if (reg_ctrl[2]) reg_ctrl[2] <= 1'b0;
            
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
        end
    end


    // =========================================================================
    // KHá»�I 3: LOGIC Ä�á»ŒC TRáº¢ Vá»€ AXI MASTER (READ BLOCK)
    // =========================================================================
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
            default:          rd_data = 32'hDEAD_BEEF; 
        endcase
    end

endmodule
`default_nettype wire
