`timescale 1ns / 1ps

module simple_adc_model #(
    parameter integer SAMPLE_WIDTH = 10
) (
    input  wire cs_n,
    input  wire sclk,
    input  wire mosi,
    output reg  miso
);

    reg [4:0] rx_cmd;
    reg [SAMPLE_WIDTH-1:0] sample_reg;
    reg [SAMPLE_WIDTH-1:0] sample_counter;
    reg [4:0] bit_count;

    initial begin
        rx_cmd = 5'd0;
        sample_reg = 10'd0;
        sample_counter = 10'd40;
        bit_count = 5'd0;
        miso = 1'b0;
    end

    always @(posedge cs_n) begin
        bit_count <= 0;
        miso <= 1'b0;
    end

    always @(posedge sclk) begin
        if (!cs_n) begin
            if (bit_count < 5) begin
                rx_cmd <= {rx_cmd[3:0], mosi};
                miso <= 1'b0;
            end else if (bit_count == 5) begin
                sample_reg <= sample_counter;
                sample_counter <= sample_counter + 10'd9;
                miso <= sample_counter[SAMPLE_WIDTH-1];
            end else if (bit_count < (5 + SAMPLE_WIDTH)) begin
                miso <= sample_reg[SAMPLE_WIDTH-1];
                sample_reg <= {sample_reg[SAMPLE_WIDTH-2:0], 1'b0};
            end else begin
                miso <= 1'b0;
            end

            bit_count <= bit_count + 1'b1;
        end
    end

endmodule
