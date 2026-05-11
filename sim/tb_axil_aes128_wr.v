`timescale 1ns / 1ps

module tb_axil_aes128_wr();
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 6;
    parameter STRB_WIDTH = 4;

    reg clk;
    reg aresetn;
    reg [ADDR_WIDTH-1:0] s_axil_awaddr;
    reg s_axil_awvalid;
    reg [DATA_WIDTH-1:0] s_axil_wdata;
    reg [STRB_WIDTH-1:0] s_axil_wstrb;
    reg s_axil_wvalid;
    reg s_axil_bready;
    reg wr_err;

    wire s_axil_awready;
    wire s_axil_wready;
    wire [1:0] s_axil_bresp;
    wire s_axil_bvalid;
    wire [ADDR_WIDTH-1:0] wr_addr;
    wire [DATA_WIDTH-1:0] wr_data;
    wire [STRB_WIDTH-1:0] wr_strb;
    wire wr_en;

    axil_aes128_wr #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_strb(wr_strb),
        .wr_en(wr_en),
        .wr_err(wr_err)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        aresetn = 0;
        s_axil_awaddr = 0;
        s_axil_awvalid = 0;
        s_axil_wdata = 0;
        s_axil_wstrb = 0;
        s_axil_wvalid = 0;
        s_axil_bready = 0;
        wr_err = 0;

        #20;
        aresetn = 1;
        #20;

        @(posedge clk);
        s_axil_awaddr = 6'h14;
        s_axil_awvalid = 1;
        s_axil_wdata = 32'h12345678;
        s_axil_wstrb = 4'hF;
        s_axil_wvalid = 1;
        s_axil_bready = 1;

        wait(s_axil_awready && s_axil_wready);
        @(posedge clk);
        s_axil_awvalid = 0;
        s_axil_wvalid = 0;

        wait(s_axil_bvalid);
        @(posedge clk);
        s_axil_bready = 0;

        #20;
        $display("tb_axil_aes128_wr completed");
        $finish;
    end
endmodule