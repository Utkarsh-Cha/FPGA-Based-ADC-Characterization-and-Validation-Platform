`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE = 115200
) (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire [7:0] data_in,
    output reg  tx,
    output reg  busy,
    output reg  done
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer FRAME_BITS = 10;

    reg [$clog2(CLKS_PER_BIT)-1:0] baud_count;
    reg [3:0] bit_index;
    reg [FRAME_BITS-1:0] frame_data;

    always @(posedge clk) begin
        if (rst) begin
            baud_count <= 0;
            bit_index  <= 0;
            frame_data <= {FRAME_BITS{1'b1}};
            tx         <= 1'b1;
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                tx <= 1'b1;
                baud_count <= 0;
                bit_index <= 0;

                if (start) begin
                    frame_data <= {1'b1, data_in, 1'b0};
                    tx         <= 1'b0;
                    busy       <= 1'b1;
                end
            end else begin
                tx <= frame_data[bit_index];

                if (baud_count == CLKS_PER_BIT - 1) begin
                    baud_count <= 0;

                    if (bit_index == FRAME_BITS - 1) begin
                        bit_index <= 0;
                        busy <= 1'b0;
                        done <= 1'b1;
                        tx <= 1'b1;
                    end else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end else begin
                    baud_count <= baud_count + 1'b1;
                end
            end
        end
    end

endmodule
