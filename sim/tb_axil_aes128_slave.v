`timescale 1ns / 1ps

module tb_axil_aes128_slave();

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 6;
    parameter STRB_WIDTH = (DATA_WIDTH/8);

    // Inputs
    reg clk;
    reg aresetn;
    reg [ADDR_WIDTH-1:0] s_axil_awaddr;
    reg [2:0] s_axil_awprot;
    reg s_axil_awvalid;
    reg [DATA_WIDTH-1:0] s_axil_wdata;
    reg [STRB_WIDTH-1:0] s_axil_wstrb;
    reg s_axil_wvalid;
    reg s_axil_bready;
    reg [ADDR_WIDTH-1:0] s_axil_araddr;
    reg [2:0] s_axil_arprot;
    reg s_axil_arvalid;
    reg s_axil_rready;

    // Outputs
    wire s_axil_awready;
    wire s_axil_wready;
    wire [1:0] s_axil_bresp;
    wire s_axil_bvalid;
    wire s_axil_arready;
    wire [DATA_WIDTH-1:0] s_axil_rdata;
    wire [1:0] s_axil_rresp;
    wire s_axil_rvalid;

    // Các tín hiệu giao tiếp với lõi AES (CẬP NHẬT MỚI)
    wire [127:0] data_bus;
    wire start, new_key, enc_dec, irq_out;
    
    reg busy, done, key_ready;
    reg [127:0] mock_core_data;

    // Giả lập logic chiếm quyền bus để tránh lỗi X (tương tự như Register File TB)
    reg tb_drive_bus_reg = 0;
    always @(posedge clk) begin
        if (start || new_key)
            tb_drive_bus_reg <= 1'b0; // Nhả bus
        else if (done)
            tb_drive_bus_reg <= 1'b1; // Chiếm bus sau khi xong
    end
    wire tb_drive_bus = tb_drive_bus_reg || done;
    assign data_bus = tb_drive_bus ? mock_core_data : 128'bz;

    // Khởi tạo Unit Under Test (UUT)
    axil_aes128_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        
        .data_bus(data_bus),
        .start(start),
        .new_key(new_key),
        .enc_dec(enc_dec),
        .busy(busy),
        .done(done),
        .key_ready(key_ready),
        .irq_out(irq_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // AXI Lite Write Task
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            #1;
            s_axil_awaddr = addr;
            s_axil_awvalid = 1;
            s_axil_wdata = data;
            s_axil_wstrb = 4'hF;
            s_axil_wvalid = 1;
            s_axil_bready = 1;
            
            wait(s_axil_awready && s_axil_wready);
            @(posedge clk);
            #1;
            s_axil_awvalid = 0;
            s_axil_wvalid = 0;
            
            wait(s_axil_bvalid);
            @(posedge clk);
            #1;
            s_axil_bready = 0;
        end
    endtask

    // AXI Lite Read Task
    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            #1;
            s_axil_araddr = addr;
            s_axil_arvalid = 1;
            s_axil_rready = 1;
            
            wait(s_axil_arready);
            @(posedge clk);
            #1;
            s_axil_arvalid = 0;
            
            wait(s_axil_rvalid);
            data = s_axil_rdata;
            @(posedge clk);
            #1;
            s_axil_rready = 0;
        end
    endtask

    reg [31:0] read_data;

    // Test process
    initial begin
        // Initialize Inputs
        aresetn = 0;
        s_axil_awaddr = 0;
        s_axil_awprot = 0;
        s_axil_awvalid = 0;
        s_axil_wdata = 0;
        s_axil_wstrb = 0;
        s_axil_wvalid = 0;
        s_axil_bready = 0;
        s_axil_araddr = 0;
        s_axil_arprot = 0;
        s_axil_arvalid = 0;
        s_axil_rready = 0;
        
        busy = 0;
        done = 0;
        key_ready = 0;
        mock_core_data = 0;

        // Reset
        #20;
        aresetn = 1;
        #20;
        $display("--- Start AXI Lite Read/Write Channel Tests ---");

        // ---------------------------------------------------------
        // SCENARIO 1: TRUYỀN LỆNH NEW_KEY (NẠP KEY VÀO KHỐI AES)
        // ---------------------------------------------------------
        $display("\n--- SCENARIO 1: Ghi Key & Truyen lenh new_key ---");
        axi_write(6'h08, 32'h00112233);
        axi_write(6'h0C, 32'h44556677);
        axi_write(6'h10, 32'h8899AABB);
        axi_write(6'h14, 32'hCCDDEEFF);

        $display("Ghi lenh new_key vao CTRL Register (CTRL[2]=1)...");
        axi_write(6'h00, 32'h00000004); // Set new_key bit

        @(posedge clk);
        #1;
        busy = 1; // Core đang nội suy Key
        #50;
        @(posedge clk);
        #1;
        busy = 0; 
        key_ready = 1; // Core báo nạp xong
        @(posedge clk);
        #1;
        key_ready = 0;

        // ---------------------------------------------------------
        // SCENARIO 2: TRUYỀN LỆNH START TÍNH TOÁN PLAINTEXT
        // ---------------------------------------------------------
        $display("\n--- SCENARIO 2: Ghi Plaintext & Truyen lenh start ---");
        axi_write(6'h18, 32'h01234567);
        axi_write(6'h1C, 32'h89ABCDEF);
        axi_write(6'h20, 32'h13579BDF);
        axi_write(6'h24, 32'h2468ACE0);

        $display("Ghi lenh start vao CTRL Register (CTRL[0]=1, CTRL[3]=1)...");
        axi_write(6'h00, 32'h00000009); // Set start & enable_irq

        @(posedge clk);
        #1;
        busy = 1; // Core bắt đầu tính toán
        #100;
        @(posedge clk);
        #1;
        busy = 0;
        done = 1;
        mock_core_data = 128'hFEDCBA9876543210FEDCBA9876543210;
        @(posedge clk);
        #1;
        done = 0;

        // ---------------------------------------------------------
        // SCENARIO 3: ĐỌC LẠI KẾT QUẢ VÀ TRẠNG THÁI
        // ---------------------------------------------------------
        $display("\n--- SCENARIO 3: Doc Status va Ciphertext ---");
        axi_read(6'h04, read_data);
        if (read_data[1]) $display("-> PASS: Co done trong Status da duoc bat.");
        else $display("-> FAIL: Khong thay co done trong Status.");

        axi_read(6'h28, read_data);
        axi_read(6'h2C, read_data);
        axi_read(6'h30, read_data);
        axi_read(6'h34, read_data);

        $display("\n--- AXI Lite Slave Integration Tests Completed ---");

        #50;
        $finish;
    end
endmodule