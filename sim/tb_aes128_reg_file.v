`timescale 1ns / 1ps

module tb_aes128_reg_file();
    // =========================================================================
    // PARAMETERS & SIGNALS
    // =========================================================================
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 6;
    parameter STRB_WIDTH = 4;

    reg clk;
    reg aresetn;
    
    // AXI Master Signals
    reg  [ADDR_WIDTH-1:0] wr_addr;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg  [STRB_WIDTH-1:0] wr_strb;
    reg  wr_en;
    wire wr_err;
    
    reg  [ADDR_WIDTH-1:0] rd_addr;
    reg  rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire rd_err;
    
    // AES Core Signals
    wire [127:0] data_bus;
    wire start, new_key, enc_dec, irq_out;
    
    reg  busy, done, key_ready;
    reg  [127:0] mock_core_data;

    // =========================================================================
    // LOGIC CHIẾM QUYỀN BUS (TỪ TESTBENCH)
    // =========================================================================
    reg tb_drive_bus_reg = 0;
    always @(posedge clk) begin
        if (start || new_key)
            tb_drive_bus_reg <= 1'b0; // Nhả bus khi Core nhận lệnh mới
        else if (done)
            tb_drive_bus_reg <= 1'b1; // Giữ trạng thái chiếm bus sau khi tính xong
    end

    // Kết hợp OR: Ngay khi done=1 lập tức chiếm bus (tổ hợp), sau đó tb_drive_bus_reg sẽ duy trì (tuần tự)
    wire tb_drive_bus = tb_drive_bus_reg || done;
    
    assign data_bus = tb_drive_bus ? mock_core_data : 128'bz;

    // =========================================================================
    // INSTANTIATE DUT (Thiết bị cần test)
    // =========================================================================
    crypto_reg_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk        (clk),
        .rst_n      (aresetn),
        .wr_addr    (wr_addr),
        .wr_data    (wr_data),
        .wr_strb    (wr_strb),
        .wr_en      (wr_en),
        .wr_error   (wr_err),
        .rd_addr    (rd_addr),
        .rd_en      (rd_en),
        .rd_data    (rd_data),
        .rd_error   (rd_err),
        .data_bus   (data_bus),
        .start      (start),
        .new_key    (new_key),
        .enc_dec    (enc_dec),
        .busy       (busy),
        .done       (done),
        .key_ready  (key_ready),
        .irq_out    (irq_out)
    );

    // =========================================================================
    // CLOCK GENERATION & TASKS
    // =========================================================================
    initial begin clk = 0; forever #5 clk = ~clk; end

    task axi_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            wr_addr = addr; wr_data = data; wr_strb = 4'hF; wr_en = 1;
            @(posedge clk);
            wr_en = 0;
        end
    endtask

    task axi_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            rd_addr = addr; rd_en = 1;
            @(posedge clk);
            data = rd_data; rd_en = 0;
        end
    endtask

    // =========================================================================
    // MAIN TEST SCENARIOS
    // =========================================================================
    reg [31:0] rdata;

    initial begin
        // Khởi tạo trạng thái ban đầu
        aresetn = 0; 
        wr_en = 0; rd_en = 0; 
        busy = 0; done = 0; key_ready = 0; mock_core_data = 0;
        wr_addr = 0; wr_data = 0; wr_strb = 0; rd_addr = 0;
        
        #25 aresetn = 1;

        // ---------------------------------------------------------------------
        // KỊCH BẢN 1: GHI KEY (Theo Waveform 1)
        // ---------------------------------------------------------------------
        #15;
        axi_write(6'h08, 32'h11111111); // KEY_0
        axi_write(6'h0C, 32'h22222222); // KEY_1
        axi_write(6'h10, 32'h33333333); // KEY_2
        axi_write(6'h14, 32'h44444444); // KEY_3
        
        axi_write(6'h00, 32'h00000004); // CPU ra lệnh new_key (CTRL[2]=1)

        @(posedge clk);
        #1;
        busy = 1; // AES Core báo bận sau khi thấy new_key
        
        #80;
        @(posedge clk);
        #1;
        busy = 0; // Xong
        key_ready = 1;
        
        @(posedge clk);
        #1;
        key_ready = 0;

        #30;

        // ---------------------------------------------------------------------
        // KỊCH BẢN 2: GHI PLAINTEXT & START (Theo Waveform 2)
        // ---------------------------------------------------------------------
        axi_write(6'h18, 32'hAAAAAAAA); // PT_0
        axi_write(6'h1C, 32'hBBBBBBBB); // PT_1
        axi_write(6'h20, 32'hCCCCCCCC); // PT_2
        axi_write(6'h24, 32'hDDDDDDDD); // PT_3
        
        axi_write(6'h00, 32'h00000009); // CPU ra lệnh start & enc (CTRL[3]=1, CTRL[0]=1)
        
        @(posedge clk);
        #1;
        busy = 1; // Core bắt đầu chạy
        
        #80;
        @(posedge clk);
        #1;
        busy = 0; 
        
        // Trả kết quả về
        mock_core_data = 128'hC3C3C3C3_C2C2C2C2_C1C1C1C1_C0C0C0C0;
        done = 1;
        
        @(posedge clk);
        #1;
        done = 0; // Tắt done, nhả bus

        #30;

        // ---------------------------------------------------------------------
        // KỊCH BẢN 3: ĐỌC KẾT QUẢ VÀ STATUS
        // ---------------------------------------------------------------------
        axi_read(6'h04, rdata); // Đọc STATUS
        axi_read(6'h34, rdata); // CIPHER_3
        axi_read(6'h30, rdata); // CIPHER_2
        axi_read(6'h2C, rdata); // CIPHER_1
        axi_read(6'h28, rdata); // CIPHER_0

        #50 $finish;
    end
endmodule