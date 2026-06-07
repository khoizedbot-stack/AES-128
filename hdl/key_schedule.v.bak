`timescale 1ns / 1ps

module key_schedule (
    input  wire         clk,
    input  wire         rst_n,

    input  wire         start_expand,
    input  wire [127:0] key_in,

    output reg          key_ready,
    output reg          busy,

    input  wire [3:0]   round_idx,      // 0..10
    output wire [127:0] round_key       // keys[round_idx]
);

    reg [127:0] keys [0:10];
    reg [127:0] current_key;
    reg [3:0]   rcon_idx;
    reg [3:0]   cnt;

    wire [127:0] next_key;

    expand_key_core u_expand (
        .key_in     (current_key),
        .rcon_idx   (rcon_idx),
        .key_out    (next_key)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy      <= 1'b0;
            key_ready <= 1'b0;
            cnt       <= 4'd0;
            rcon_idx  <= 4'd1;
        end else if (start_expand) begin
            busy      <= 1'b1;
            key_ready <= 1'b0;
            cnt       <= 4'd1;
            rcon_idx  <= 4'd1;
        end else if (busy) begin
            if (cnt == 4'd10) begin
                busy      <= 1'b0;
                key_ready <= 1'b1;
            end else begin
                cnt      <= cnt + 4'd1;
                rcon_idx <= rcon_idx + 4'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_key <= 128'b0;
        end else if (start_expand) begin
            current_key <= key_in;
        end else if (busy) begin
            current_key <= next_key;
        end
    end

    always @(posedge clk) begin
        if (start_expand) begin
            keys[0] <= key_in;
        end else if (busy) begin
            keys[cnt] <= next_key;
        end
    end

    assign round_key = keys[round_idx];

endmodule