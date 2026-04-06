`timescale 1ns / 1ps

module tb_top_student_adc_platform;

    localparam integer CLK_FREQ_HZ = 1000000;
    localparam integer BAUD_RATE = 100000;
    localparam integer SAMPLE_WIDTH = 10;
    localparam integer FRAME_SAMPLES = 16;
    localparam integer SAMPLE_PERIOD_CLKS = 20;
    reg clk;
    reg rst;
    reg start_capture_i;
    wire adc_sclk;
    wire adc_cs_n;
    wire adc_mosi;
    wire adc_miso;
    wire uart_tx_o;
    wire status_led_o;

    integer i;
    integer uart_byte_count;
    reg [7:0] rx_bytes [0:(FRAME_SAMPLES*2)-1];
    reg [SAMPLE_WIDTH-1:0] samples [0:FRAME_SAMPLES-1];
    reg [SAMPLE_WIDTH-1:0] expected [0:FRAME_SAMPLES-1];
    reg [SAMPLE_WIDTH-1:0] lfsr_state;
    reg [SAMPLE_WIDTH-1:0] ramp_state;
    reg [SAMPLE_WIDTH-1:0] synth_value;

    top_student_adc_platform #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .FRAME_SAMPLES(FRAME_SAMPLES),
        .SAMPLE_PERIOD_CLKS(SAMPLE_PERIOD_CLKS),
        .SOURCE_SELECT(1),
        .SPI_CLK_DIV(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start_capture_i(start_capture_i),
        .adc_miso(adc_miso),
        .adc_sclk(adc_sclk),
        .adc_cs_n(adc_cs_n),
        .adc_mosi(adc_mosi),
        .uart_tx_o(uart_tx_o),
        .status_led_o(status_led_o)
    );

    // The SPI ADC model is instantiated so students can switch the DUT to
    // SOURCE_SELECT=2 and reuse the same simulation environment later.
    simple_adc_model #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH)
    ) u_adc_model (
        .cs_n(adc_cs_n),
        .sclk(adc_sclk),
        .mosi(adc_mosi),
        .miso(adc_miso)
    );

    initial begin
        clk = 1'b0;
        forever #500 clk = ~clk;
    end

    initial begin
        #100000000;
        $display(
            "TIMEOUT: state=%0d frame_done=%0b capture_enable=%0b tx_index=%0d uart_busy=%0b uart_tx=%0b",
            dut.state,
            dut.frame_done,
            dut.capture_enable,
            dut.tx_sample_index,
            dut.uart_busy,
            uart_tx_o
        );
        $fatal;
    end

    initial begin
        rst = 1'b1;
        start_capture_i = 1'b0;
        uart_byte_count = 0;
        lfsr_state = 10'h155;
        ramp_state = 0;

        repeat (10) @(posedge clk);
        rst = 1'b0;

        @(posedge clk);
        start_capture_i = 1'b1;
        @(posedge clk);
        start_capture_i = 1'b0;

        for (i = 0; i < FRAME_SAMPLES; i = i + 1) begin
            synth_value = (ramp_state + lfsr_state[3:0]) & 10'h3FF;
            expected[i] = synth_value;
            ramp_state = (ramp_state + 10'd4) & 10'h3FF;
            lfsr_state = {lfsr_state[SAMPLE_WIDTH-2:0], lfsr_state[SAMPLE_WIDTH-1] ^ lfsr_state[6]};
        end

        wait (uart_byte_count == FRAME_SAMPLES * 2);

        for (i = 0; i < FRAME_SAMPLES; i = i + 1) begin
            samples[i] = {rx_bytes[(2*i)][1:0], rx_bytes[(2*i)+1]};
            if (samples[i] !== expected[i]) begin
                $display("ERROR: sample %0d mismatch. expected=%0d got=%0d", i, expected[i], samples[i]);
                $fatal;
            end
        end

        $display("PASS: all %0d samples matched expected synthetic values", FRAME_SAMPLES);
        $finish;
    end

    // Instead of re-decoding the serial line in plain Verilog, the testbench
    // checks the bytes handed from the top-level into the UART transmitter.
    // This keeps the self-checking logic simpler and more robust for students.
    always @(posedge clk) begin
        #1;
        if (dut.uart_start) begin
            if (uart_byte_count < FRAME_SAMPLES * 2) begin
                rx_bytes[uart_byte_count] = dut.uart_data;
                $display("UART byte %0d = 0x%02x", uart_byte_count, dut.uart_data);
                uart_byte_count = uart_byte_count + 1;
            end
        end
    end

endmodule
