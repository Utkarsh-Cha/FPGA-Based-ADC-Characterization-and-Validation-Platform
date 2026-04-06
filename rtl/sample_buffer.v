`timescale 1ns / 1ps

module sample_buffer #(
    parameter integer SAMPLE_WIDTH = 10,
    parameter integer DEPTH = 256
) (
    input  wire clk,
    input  wire wr_en,
    input  wire [$clog2(DEPTH)-1:0] wr_addr,
    input  wire [SAMPLE_WIDTH-1:0] wr_data,
    input  wire [$clog2(DEPTH)-1:0] rd_addr,
    output wire [SAMPLE_WIDTH-1:0] rd_data
);

    reg [SAMPLE_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end

    end

    assign rd_data = mem[rd_addr];

endmodule
