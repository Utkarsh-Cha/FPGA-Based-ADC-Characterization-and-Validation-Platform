# Block Diagram Notes

## High-Level Data Path

```text
+--------------------+      +------------------+      +------------------+
| Sample Source      | ---> | ADC Capture      | ---> | Sample Buffer    |
|                    |      | Controller       |      | (Frame Memory)   |
| 1. Simulated ADC   |      +------------------+      +------------------+
| 2. Synthetic Ramp  |                |                         |
| 3. SPI ADC         |                v                         v
+--------------------+      +------------------+      +------------------+
                            | Frame Ready       | ---> | UART Streamer    |
                            +------------------+      +------------------+
                                                               |
                                                               v
                                                    +--------------------+
                                                    | PC Python Scripts  |
                                                    | CSV + Plots +      |
                                                    | Basic Metrics      |
                                                    +--------------------+
```

## Main RTL Blocks

### `spi_master.v`

- Generates SPI clock from FPGA system clock
- Drives `cs_n`, `sclk`, and `mosi`
- Samples `miso`
- Returns one 10-bit sample at the end of a transaction

### `adc_capture.v`

- Starts one conversion at a fixed interval
- Accepts samples from either:
  - internal synthetic source, or
  - external SPI ADC block
- Writes samples sequentially into the sample buffer
- Raises `frame_done` when buffer is full

### `sample_buffer.v`

- Simple single-clock sample storage
- One write port and one read port
- Stores one frame of samples before UART transmission

### `uart_tx.v`

- Sends one byte at a time over UART
- Provides `busy` and `done` handshake signals

### `top_student_adc_platform.v`

- Selects sample source
- Controls capture
- Reads stored samples
- Splits each 10-bit sample into two bytes
- Streams them to the PC over UART

## Source Modes

### Mode 0: Pure Simulation

- The top-level runs in synthetic source mode
- The testbench can also instantiate `simple_adc_model.v` to mimic an SPI ADC
- Best mode for learning and debugging

### Mode 1: FPGA Synthetic Source

- No external ADC required
- Good for verifying:
  - board clock
  - UART link
  - Python scripts

### Mode 2: FPGA SPI ADC

- Uses `spi_master.v`
- Best for demonstrating real data capture with minimal hardware

## Educational Tradeoffs

This project intentionally chooses:

- Small frame buffer instead of streaming fabric
- UART instead of USB high-speed interfaces
- Fixed-width 10-bit samples
- Basic linear-fit analysis instead of full converter metrology

These choices keep the project teachable and achievable.
