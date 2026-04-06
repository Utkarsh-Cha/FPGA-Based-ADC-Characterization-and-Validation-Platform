# FPGA-Based-ADC-Characterization-and-Validation-Platform

An FPGA-based data acquisition and ADC validation platform designed to demonstrate a complete hardware-to-software signal processing pipeline.

This project implements a modular system capable of capturing ADC samples, buffering them on FPGA, transmitting data over UART, and performing analysis on a host machine using Python.

---

## Overview

The system provides an end-to-end flow for working with ADC data:

- Data generation or acquisition (simulated, internal, or external ADC)
- FPGA-based capture and buffering
- UART-based data transmission
- PC-side logging and analysis

The focus is on building a clean, understandable, and extensible architecture that reflects real hardware-software integration workflows.

---

## Features

- Capture of 10-bit ADC samples from multiple sources:
  - Simulated ADC model  
  - Internal waveform/sample generator  
  - External SPI-based ADC interface  

- FPGA-side processing:
  - Sample capture controller  
  - Buffered data storage  
  - UART transmission  

- Host-side processing:
  - UART data reception using Python  
  - CSV logging  
  - Visualization and basic analysis  

- Basic ADC evaluation metrics:
  - Offset error  
  - Gain error  
  - Linearity trend  
  - Noise estimation  

---

## Modes of Operation

### 1. Simulation Mode
Complete verification using testbenches without requiring hardware.

### 2. FPGA with Internal Source
Runs on FPGA using a built-in sample generator, useful for validation without external ADC hardware.

### 3. FPGA with SPI ADC
Interfaces with an external ADC through SPI for real data acquisition.

---

## System Architecture
