#!/usr/bin/env python3
"""
Receive 10-bit ADC samples over UART and save them to CSV.

UART format per sample:
    byte0 = 000000SS   where SS are sample bits [9:8]
    byte1 = SSSSSSSS   where bits are sample bits [7:0]

Reconstruction:
    sample = ((byte0 & 0x03) << 8) | byte1
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import sys
import time

import serial


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Receive FPGA UART samples and save CSV.")
    parser.add_argument("--port", required=True, help="Serial port, for example COM3 or /dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate")
    parser.add_argument("--num-samples", type=int, default=256, help="Number of 10-bit samples to receive")
    parser.add_argument(
        "--output",
        default="captured_samples.csv",
        help="Output CSV file path",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=10.0,
        help="Maximum receive timeout in seconds",
    )
    return parser.parse_args()


def read_exact_samples(port: str, baud: int, num_samples: int, timeout: float) -> list[int]:
    target_bytes = num_samples * 2
    buffer = bytearray()
    start_time = time.time()

    with serial.Serial(port=port, baudrate=baud, timeout=0.2) as ser:
        # Brief wait helps if the USB-UART adapter resets the board on open.
        time.sleep(0.5)

        while len(buffer) < target_bytes:
            chunk = ser.read(target_bytes - len(buffer))
            if chunk:
                buffer.extend(chunk)
                print(f"Received {len(buffer)}/{target_bytes} bytes", end="\r", flush=True)

            if time.time() - start_time > timeout:
                raise TimeoutError(
                    f"Timed out after {timeout:.1f}s while waiting for {target_bytes} bytes. "
                    f"Only received {len(buffer)} bytes."
                )

    print()
    samples: list[int] = []
    for idx in range(0, len(buffer), 2):
        high = buffer[idx]
        low = buffer[idx + 1]
        sample = ((high & 0x03) << 8) | low
        samples.append(sample)

    return samples


def write_csv(samples: list[int], output_path: pathlib.Path) -> None:
    with output_path.open("w", newline="") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["sample_index", "adc_code"])
        for index, value in enumerate(samples):
            writer.writerow([index, value])


def main() -> int:
    args = parse_args()
    output_path = pathlib.Path(args.output)

    print(f"Opening serial port {args.port} at {args.baud} baud")
    samples = read_exact_samples(args.port, args.baud, args.num_samples, args.timeout)
    write_csv(samples, output_path)

    print(f"Saved {len(samples)} samples to {output_path}")
    if samples:
        print(f"First 8 samples: {samples[:8]}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nInterrupted by user.", file=sys.stderr)
        raise SystemExit(1)
