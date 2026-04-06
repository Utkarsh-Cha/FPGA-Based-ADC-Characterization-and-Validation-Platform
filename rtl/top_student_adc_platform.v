`timescale 1ns / 1ps

module top_student_adc_platform #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD_RATE = 115200,
    parameter integer SAMPLE_WIDTH = 10,
    parameter integer FRAME_SAMPLES = 256,
    parameter integer SAMPLE_PERIOD_CLKS = 5000,
    parameter integer SOURCE_SELECT = 1,
    parameter integer SPI_CLK_DIV = 8
) (
    input  wire clk,
    input  wire rst,
    input  wire start_capture_i,
    input  wire adc_miso,
    output wire adc_sclk,
    output wire adc_cs_n,
    output wire adc_mosi,
    output wire uart_tx_o,
    output reg  status_led_o
);

    // The top-level works in two phases:
    // 1. capture a complete frame into memory
    // 2. read the frame back and stream it over UART
    localparam [3:0] ST_IDLE            = 4'd0;
    localparam [3:0] ST_CAPTURE         = 4'd1;
    localparam [3:0] ST_LOAD_SAMPLE     = 4'd2;
    localparam [3:0] ST_LATCH_SAMPLE    = 4'd3;
    localparam [3:0] ST_SEND_HIGH       = 4'd4;
    localparam [3:0] ST_WAIT_HIGH_DONE  = 4'd5;
    localparam [3:0] ST_SEND_LOW        = 4'd6;
    localparam [3:0] ST_WAIT_LOW_DONE   = 4'd7;

    reg capture_enable;
    wire frame_done;
    wire frame_active;

    wire buffer_wr_en;
    wire [$clog2(FRAME_SAMPLES)-1:0] buffer_wr_addr;
    wire [SAMPLE_WIDTH-1:0] buffer_wr_data;

    reg [$clog2(FRAME_SAMPLES)-1:0] buffer_rd_addr;
    wire [SAMPLE_WIDTH-1:0] buffer_rd_data;

    wire spi_done;
    wire [SAMPLE_WIDTH-1:0] spi_sample;
    wire spi_start;
    wire [SAMPLE_WIDTH-1:0] synthetic_sample_dbg;

    reg [3:0] state;
    reg [$clog2(FRAME_SAMPLES)-1:0] tx_sample_index;
    reg [SAMPLE_WIDTH-1:0] sample_latched;
    reg uart_start;
    reg [7:0] uart_data;
    wire uart_busy;
    wire uart_done;

    adc_capture #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .FRAME_SAMPLES(FRAME_SAMPLES),
        .SAMPLE_PERIOD_CLKS(SAMPLE_PERIOD_CLKS),
        .SOURCE_SELECT(SOURCE_SELECT)
    ) u_adc_capture (
        .clk(clk),
        .rst(rst),
        .buffer_wr_en(buffer_wr_en),
        .buffer_wr_addr(buffer_wr_addr),
        .buffer_wr_data(buffer_wr_data),
        .capture_enable(capture_enable),
        .frame_done(frame_done),
        .frame_active(frame_active),
        .spi_start(spi_start),
        .spi_done(spi_done),
        .spi_sample(spi_sample),
        .synthetic_sample_dbg(synthetic_sample_dbg)
    );

    sample_buffer #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .DEPTH(FRAME_SAMPLES)
    ) u_sample_buffer (
        .clk(clk),
        .wr_en(buffer_wr_en),
        .wr_addr(buffer_wr_addr),
        .wr_data(buffer_wr_data),
        .rd_addr(buffer_rd_addr),
        .rd_data(buffer_rd_data)
    );

    spi_master #(
        .CLK_DIV(SPI_CLK_DIV),
        .SAMPLE_WIDTH(SAMPLE_WIDTH)
    ) u_spi_master (
        .clk(clk),
        .rst(rst),
        .start(spi_start),
        .busy(),
        .done(spi_done),
        .sample_data(spi_sample),
        .sclk(adc_sclk),
        .cs_n(adc_cs_n),
        .mosi(adc_mosi),
        .miso(adc_miso)
    );

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart_tx (
        .clk(clk),
        .rst(rst),
        .start(uart_start),
        .data_in(uart_data),
        .tx(uart_tx_o),
        .busy(uart_busy),
        .done(uart_done)
    );

    always @(posedge clk) begin
        if (rst) begin
            state          <= ST_IDLE;
            capture_enable <= 1'b0;
            buffer_rd_addr <= 0;
            tx_sample_index <= 0;
            sample_latched <= 0;
            uart_start     <= 1'b0;
            uart_data      <= 8'h00;
            status_led_o   <= 1'b0;
        end else begin
            uart_start   <= 1'b0;
            status_led_o <= frame_active;

            case (state)
                ST_IDLE: begin
                    capture_enable <= 1'b0;
                    tx_sample_index <= 0;
                    if (start_capture_i) begin
                        capture_enable <= 1'b1;
                        state <= ST_CAPTURE;
                    end
                end

                ST_CAPTURE: begin
                    if (frame_done) begin
                        capture_enable <= 1'b0;
                        tx_sample_index <= 0;
                        state <= ST_LOAD_SAMPLE;
                    end
                end

                ST_LOAD_SAMPLE: begin
                    buffer_rd_addr <= tx_sample_index;
                    state <= ST_LATCH_SAMPLE;
                end

                ST_LATCH_SAMPLE: begin
                    sample_latched <= buffer_rd_data;
                    state <= ST_SEND_HIGH;
                end

                ST_SEND_HIGH: begin
                    if (!uart_busy) begin
                        // The high byte carries only bits [9:8] of the 10-bit sample.
                        uart_data  <= {6'b000000, sample_latched[9:8]};
                        uart_start <= 1'b1;
                        state <= ST_WAIT_HIGH_DONE;
                    end
                end

                ST_WAIT_HIGH_DONE: begin
                    if (uart_done) begin
                        state <= ST_SEND_LOW;
                    end
                end

                ST_SEND_LOW: begin
                    if (!uart_busy) begin
                        // The low byte carries bits [7:0].
                        uart_data  <= sample_latched[7:0];
                        uart_start <= 1'b1;
                        state <= ST_WAIT_LOW_DONE;
                    end
                end

                ST_WAIT_LOW_DONE: begin
                    if (uart_done) begin
                        if (tx_sample_index == FRAME_SAMPLES - 1) begin
                            state <= ST_IDLE;
                        end else begin
                            tx_sample_index <= tx_sample_index + 1'b1;
                            state <= ST_LOAD_SAMPLE;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
