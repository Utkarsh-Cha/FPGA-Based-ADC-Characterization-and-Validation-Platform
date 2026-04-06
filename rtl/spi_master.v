`timescale 1ns / 1ps

module spi_master #(
    parameter integer CLK_DIV = 8,
    parameter integer SAMPLE_WIDTH = 10,
    parameter [4:0] COMMAND_WORD = 5'b11000
) (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  busy,
    output reg  done,
    output reg  [SAMPLE_WIDTH-1:0] sample_data,
    output reg  sclk,
    output reg  cs_n,
    output reg  mosi,
    input  wire miso
);

    // 5 command bits followed by 10 data bits for a simple educational ADC flow.
    localparam integer TOTAL_BITS = 15;

    reg [$clog2(CLK_DIV)-1:0] clk_div_cnt;
    reg [4:0] bit_index;
    reg [4:0] tx_shift;
    reg [SAMPLE_WIDTH-1:0] rx_shift;
    reg sclk_prev;

    wire tick = (clk_div_cnt == CLK_DIV - 1);

    always @(posedge clk) begin
        if (rst) begin
            clk_div_cnt  <= 0;
            bit_index    <= 0;
            tx_shift     <= COMMAND_WORD;
            rx_shift     <= {SAMPLE_WIDTH{1'b0}};
            busy         <= 1'b0;
            done         <= 1'b0;
            sample_data  <= {SAMPLE_WIDTH{1'b0}};
            sclk         <= 1'b0;
            sclk_prev    <= 1'b0;
            cs_n         <= 1'b1;
            mosi         <= 1'b0;
        end else begin
            done <= 1'b0;
            sclk_prev <= sclk;

            if (!busy) begin
                sclk <= 1'b0;
                clk_div_cnt <= 0;

                if (start) begin
                    busy      <= 1'b1;
                    cs_n      <= 1'b0;
                    bit_index <= 0;
                    tx_shift  <= COMMAND_WORD;
                    rx_shift  <= {SAMPLE_WIDTH{1'b0}};
                    mosi      <= COMMAND_WORD[4];
                end
            end else begin
                if (tick) begin
                    clk_div_cnt <= 0;
                    sclk <= ~sclk;

                    if (!sclk) begin
                        if (bit_index < 5) begin
                            mosi <= tx_shift[4];
                            tx_shift <= {tx_shift[3:0], 1'b0};
                        end else begin
                            mosi <= 1'b0;
                        end
                    end else begin
                        if (bit_index >= 5 && bit_index < (5 + SAMPLE_WIDTH)) begin
                            rx_shift <= {rx_shift[SAMPLE_WIDTH-2:0], miso};
                        end

                        if (bit_index == TOTAL_BITS - 1) begin
                            busy        <= 1'b0;
                            cs_n        <= 1'b1;
                            sclk        <= 1'b0;
                            sample_data <= {rx_shift[SAMPLE_WIDTH-2:0], miso};
                            done        <= 1'b1;
                        end

                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    clk_div_cnt <= clk_div_cnt + 1'b1;
                end
            end
        end
    end

endmodule
