`timescale 1ns / 1ps

module adc_capture #(
    parameter integer SAMPLE_WIDTH = 10,
    parameter integer FRAME_SAMPLES = 256,
    parameter integer SAMPLE_PERIOD_CLKS = 5000,
    parameter integer SOURCE_SELECT = 1
) (
    input  wire clk,
    input  wire rst,
    output reg  buffer_wr_en,
    output reg  [$clog2(FRAME_SAMPLES)-1:0] buffer_wr_addr,
    output reg  [SAMPLE_WIDTH-1:0] buffer_wr_data,
    input  wire capture_enable,
    output reg  frame_done,
    output reg  frame_active,
    output reg  spi_start,
    input  wire spi_done,
    input  wire [SAMPLE_WIDTH-1:0] spi_sample,
    output reg  [SAMPLE_WIDTH-1:0] synthetic_sample_dbg
);

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_WAIT_TICK  = 3'd1;
    localparam [2:0] ST_START_SPI  = 3'd2;
    localparam [2:0] ST_WAIT_SPI   = 3'd3;
    localparam [2:0] ST_WRITE      = 3'd4;
    localparam [2:0] ST_DONE       = 3'd5;

    reg [2:0] state;
    reg [$clog2(SAMPLE_PERIOD_CLKS)-1:0] sample_timer;
    reg [$clog2(FRAME_SAMPLES):0] sample_count;
    reg [SAMPLE_WIDTH-1:0] current_sample;
    reg [SAMPLE_WIDTH-1:0] synth_lfsr;
    reg [SAMPLE_WIDTH-1:0] synth_ramp;

    wire sample_tick = (sample_timer == SAMPLE_PERIOD_CLKS - 1);
    // Synthetic mode uses a ramp plus a small pseudo-random term so the data
    // is more interesting than a perfect ramp, but still easy to explain.
    wire [SAMPLE_WIDTH-1:0] synth_next = synth_ramp + synth_lfsr[3:0];

    always @(posedge clk) begin
        if (rst) begin
            state                <= ST_IDLE;
            sample_timer         <= 0;
            sample_count         <= 0;
            buffer_wr_en         <= 1'b0;
            buffer_wr_addr       <= 0;
            buffer_wr_data       <= 0;
            frame_done           <= 1'b0;
            frame_active         <= 1'b0;
            spi_start            <= 1'b0;
            current_sample       <= 0;
            synth_lfsr           <= 10'h155;
            synth_ramp           <= 0;
            synthetic_sample_dbg <= 0;
        end else begin
            buffer_wr_en <= 1'b0;
            spi_start    <= 1'b0;
            frame_done   <= 1'b0;

            case (state)
                ST_IDLE: begin
                    frame_active <= 1'b0;
                    sample_timer <= 0;
                    sample_count <= 0;
                    buffer_wr_addr <= 0;
                    synth_lfsr <= 10'h155;
                    synth_ramp <= 0;

                    if (capture_enable) begin
                        frame_active <= 1'b1;
                        state <= ST_WAIT_TICK;
                    end
                end

                ST_WAIT_TICK: begin
                    if (sample_tick) begin
                        sample_timer <= 0;
                        if (SOURCE_SELECT == 2) begin
                            state <= ST_START_SPI;
                        end else begin
                            synth_ramp <= synth_ramp + 10'd4;
                            current_sample <= synth_next;
                            synthetic_sample_dbg <= synth_next;
                            synth_lfsr <= {synth_lfsr[SAMPLE_WIDTH-2:0], synth_lfsr[SAMPLE_WIDTH-1] ^ synth_lfsr[6]};
                            state <= ST_WRITE;
                        end
                    end else begin
                        sample_timer <= sample_timer + 1'b1;
                    end
                end

                ST_START_SPI: begin
                    spi_start <= 1'b1;
                    state <= ST_WAIT_SPI;
                end

                ST_WAIT_SPI: begin
                    if (spi_done) begin
                        current_sample <= spi_sample;
                        state <= ST_WRITE;
                    end
                end

                ST_WRITE: begin
                    buffer_wr_en   <= 1'b1;
                    buffer_wr_addr <= sample_count[$clog2(FRAME_SAMPLES)-1:0];
                    buffer_wr_data <= current_sample;

                    if (sample_count == FRAME_SAMPLES - 1) begin
                        state <= ST_DONE;
                    end else begin
                        sample_count   <= sample_count + 1'b1;
                        state          <= ST_WAIT_TICK;
                    end
                end

                ST_DONE: begin
                    frame_done   <= 1'b1;
                    frame_active <= 1'b0;
                    state        <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
