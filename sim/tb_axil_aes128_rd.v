`timescale 1ns / 1ps

module tb_axil_aes128_rd();
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 6;

    reg clk;
    reg aresetn;
    reg [ADDR_WIDTH-1:0] s_axil_araddr;
    reg s_axil_arvalid;
    reg s_axil_rready;
    reg [DATA_WIDTH-1:0] rd_data;
    reg rd_err;

    wire s_axil_arready;
    wire [DATA_WIDTH-1:0] s_axil_rdata;
    wire [1:0] s_axil_rresp;
    wire s_axil_rvalid;
    wire [ADDR_WIDTH-1:0] rd_addr;
    wire rd_en;

    axil_aes128_rd #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .rd_addr(rd_addr),
        .rd_en(rd_en),
        .rd_data(rd_data),
        .rd_err(rd_err)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        aresetn = 0;
        s_axil_araddr = 0;
        s_axil_arvalid = 0;
        s_axil_rready = 0;
        rd_err = 0;

        #20;
        aresetn = 1;
        #20;

        // Test OK Read
        @(posedge clk);
        #1; // Thêm trễ nhỏ để tránh gai (glitch) do thay đổi cùng lúc với sườn lên
        s_axil_araddr = 6'h04;
        s_axil_arvalid = 1;
        s_axil_rready = 1;
        
        // Mô phỏng đáp ứng của reg_file (combinational read)
        wait(s_axil_arready);
        @(posedge clk);
        #1;
        s_axil_arvalid = 0;

        wait(s_axil_rvalid);
        @(posedge clk);
        #1;
        s_axil_rready = 0;
        
        #40;
        $display("tb_axil_aes128_rd completed");
        $finish;
    end

    // Giả lập Register File đọc bất đồng bộ (trả kết quả ngay khi có rd_addr)
    always @(*) begin
        case (rd_addr)
            6'h04: rd_data = 32'h00000004;
            6'h14: rd_data = 32'h11223344;
            default: rd_data = 32'hDEADBEEF;
        endcase
    end
endmodule