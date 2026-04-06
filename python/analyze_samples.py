#!/usr/bin/env python3
"""
Analyze captured ADC samples from CSV and generate student-level metrics.
"""

from __future__ import annotations

import argparse
import pathlib

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze FPGA ADC capture samples.")
    parser.add_argument("--csv", required=True, help="Input CSV file produced by receive_uart.py")
    parser.add_argument(
        "--outdir",
        default="analysis_output",
        help="Directory where plots and summary will be saved",
    )
    return parser.parse_args()


def compute_metrics(samples: np.ndarray) -> dict[str, float]:
    x = np.arange(len(samples), dtype=float)

    if len(samples) < 2:
        raise ValueError("Need at least 2 samples for analysis.")

    fit = np.polyfit(x, samples, 1)
    fitted = np.polyval(fit, x)
    residual = samples - fitted

    ideal_start = 0.0
    ideal_end = 1023.0
    ideal_slope = (ideal_end - ideal_start) / max(len(samples) - 1, 1)

    offset_error = float(fitted[0] - ideal_start)
    gain_error = float((fit[0] - ideal_slope) / ideal_slope) if ideal_slope != 0 else 0.0
    noise_std = float(np.std(residual))
    residual_peak = float(np.max(np.abs(residual)))

    return {
        "fit_slope": float(fit[0]),
        "fit_intercept": float(fit[1]),
        "offset_error_lsb": offset_error,
        "gain_error_relative": gain_error,
        "noise_std_lsb": noise_std,
        "linearity_residual_peak_lsb": residual_peak,
    }


def make_plots(samples: np.ndarray, metrics: dict[str, float], outdir: pathlib.Path) -> None:
    x = np.arange(len(samples))
    fitted = metrics["fit_slope"] * x + metrics["fit_intercept"]
    residual = samples - fitted

    plt.figure(figsize=(10, 4))
    plt.plot(x, samples, label="Captured samples", linewidth=1.5)
    plt.plot(x, fitted, label="Linear fit", linestyle="--")
    plt.xlabel("Sample index")
    plt.ylabel("ADC code")
    plt.title("Captured ADC Samples")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(outdir / "samples_plot.png", dpi=150)
    plt.close()

    plt.figure(figsize=(10, 4))
    plt.plot(x, residual, color="tab:red", linewidth=1.2)
    plt.xlabel("Sample index")
    plt.ylabel("Residual (LSB)")
    plt.title("Basic Linearity Trend")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(outdir / "linearity_residual.png", dpi=150)
    plt.close()

    plt.figure(figsize=(8, 4))
    plt.hist(residual, bins=20, color="tab:green", alpha=0.8)
    plt.xlabel("Residual (LSB)")
    plt.ylabel("Count")
    plt.title("Noise / Residual Histogram")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(outdir / "noise_histogram.png", dpi=150)
    plt.close()


def write_summary(metrics: dict[str, float], outdir: pathlib.Path) -> pathlib.Path:
    summary_path = outdir / "summary.txt"
    summary_text = "\n".join(
        [
            "Student-Level ADC Characterization Summary",
            "=========================================",
            f"Linear fit slope: {metrics['fit_slope']:.4f} codes/sample",
            f"Linear fit intercept: {metrics['fit_intercept']:.4f} codes",
            f"Offset error: {metrics['offset_error_lsb']:.4f} LSB",
            f"Gain error: {metrics['gain_error_relative'] * 100:.4f} %",
            f"Noise estimate (std of residual): {metrics['noise_std_lsb']:.4f} LSB",
            f"Peak residual for linearity trend: {metrics['linearity_residual_peak_lsb']:.4f} LSB",
            "",
            "Note: These are educational trend metrics, not lab-grade ADC metrology results.",
        ]
    )
    summary_path.write_text(summary_text + "\n")
    return summary_path


def main() -> int:
    args = parse_args()
    csv_path = pathlib.Path(args.csv)
    outdir = pathlib.Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(csv_path)
    if "adc_code" not in df.columns:
        raise ValueError("CSV must contain an 'adc_code' column.")

    samples = df["adc_code"].to_numpy(dtype=float)
    metrics = compute_metrics(samples)
    make_plots(samples, metrics, outdir)
    summary_path = write_summary(metrics, outdir)

    print(f"Processed {len(samples)} samples from {csv_path}")
    print(f"Summary saved to {summary_path}")
    print(f"Plots saved under {outdir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
