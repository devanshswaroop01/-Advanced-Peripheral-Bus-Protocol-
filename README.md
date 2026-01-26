# 📘 AMBA APB Master–Slave System (Verilog HDL)

A **protocol-compliant, deadlock-safe AMBA APB implementation** in Verilog HDL featuring an FSM-based master, multi-slave support, address decoding interconnect, and a protocol-aware verification testbench.

---

## 🔖 Overview (TL;DR)

This project implements a **fully functional AMBA APB (Advanced Peripheral Bus) system** using Verilog HDL. It strictly follows **APB3 timing and handshake rules** and demonstrates:

* Correct read/write transactions
* Wait-state handling via `PREADY`
* Error reporting using `PSLVERR`
* Clean FSM-based protocol sequencing

The design is intended for **learning, labs, and RTL/VLSI interviews**, not for high-performance production SoCs.

---

## 🧠 What is APB?

APB (Advanced Peripheral Bus) is part of the **ARM AMBA bus family**, optimized for:

* Low-bandwidth peripherals
* Register and control access
* Low power consumption
* Minimal hardware complexity

### Key APB Characteristics

* Single-cycle **SETUP** phase
* Single or multi-cycle **ENABLE** phase
* No burst transactions
* No pipelining
* Simple handshake using `PREADY` and `PSLVERR`

> This project follows **APB3-style behavior**.

---

## 🎯 Project Scope

### ✔ Included

* Educational, interview-grade APB design
* Strict protocol correctness
* Clean and readable RTL
* Deterministic and deadlock-free behavior

### ❌ Not Included

* High-performance or production-grade fabric
* Burst or pipelined transfers
* APB4 advanced features

---

## ✨ Features

* FSM-based APB Master (`IDLE → SETUP → ENABLE`)
* Protocol-compliant signal timing
* Read and write transaction support
* Two APB slaves with address-based selection
* Deadlock-free `PREADY` aggregation
* Proper `PSLVERR` handling
* Back-to-back transfer capability
* Deterministic reset behavior
* Clean, protocol-aware testbench
* Waveform and console-based verification

---

## 🏗️ Architecture Overview

```
User / Testbench
        │
        ▼
   APB Master (FSM)
        │
        ▼
  APB Interconnect (Top)
        │
   ┌────┴────┐
   ▼         ▼
APB Slave 1  APB Slave 2
```

### Component Responsibilities

* **APB Master**: Generates all APB protocol signals
* **Interconnect**: Decodes addresses and routes responses
* **Slaves**: Memory-mapped peripherals
* **Testbench**: Drives and verifies transactions

---

## 🧩 Block Descriptions

### 🔹 APB Master

* Implements APB protocol sequencing
* FSM controls `SETUP` and `ENABLE` phases
* Latches address and control signals in `SETUP`
* Handles wait states via `PREADY`

### 🔹 APB Interconnect (Top Module)

* Address-based slave selection
* Aggregates `PREADY` and `PSLVERR`
* Multiplexes `PRDATA`
* Prevents deadlock on invalid address decode

### 🔹 APB Slave

* 256-byte memory-mapped peripheral
* Responds only during `ENABLE` phase
* Supports read and write accesses
* Detects invalid address accesses

### 🔹 Testbench

* Drives valid and invalid APB transactions
* Captures data at true transfer completion
* Displays transaction summaries in console
* Generates waveforms for visual inspection

---

## 🔄 Finite State Machine (FSM)

### FSM States

| State  | Description                      |
| ------ | -------------------------------- |
| IDLE   | No active transaction            |
| SETUP  | Address/control phase (`PSEL=1`) |
| ENABLE | Data phase (`PENABLE=1`)         |

### FSM Behavior

* `IDLE → SETUP` on transfer request
* `SETUP → ENABLE` unconditionally
* `ENABLE → IDLE / SETUP` based on `PREADY` and next request

---

## 🔌 Interface Signals

### Master Inputs

* `pclk` – APB clock
* `presetn` – Active-low reset
* `transfer` – Transfer request
* `read`, `write` – Operation type
* `apb_read_paddr`, `apb_write_paddr` – Address inputs
* `apb_write_data` – Write data

### APB Bus Signals

* `PSELx` – Slave select
* `PENABLE` – Data phase indicator
* `PWRITE` – Read/Write control
* `PADDR` – Address bus
* `PWDATA` – Write data
* `PRDATA` – Read data
* `PREADY` – Transfer complete
* `PSLVERR` – Error indicator

---

## ⚙️ Parameters & Configuration

### Current Design Assumptions

* Address width: **8 bits**
* Data width: **8 bits**
* Number of slaves: **2**

### Address Map

| Slave   | Address Range |
| ------- | ------------- |
| Slave 1 | `0x00 – 0x7F` |
| Slave 2 | `0x80 – 0xFF` |

> The design can be extended via parameterization.

---

## 🔁 Transaction Flow

1. User asserts `transfer` with read/write
2. Master enters `SETUP` and latches signals
3. Master transitions to `ENABLE`
4. Slave processes the request
5. Slave asserts `PREADY` (and `PSLVERR` if required)
6. Master completes transfer
7. Read data captured (for read operations)

---

## ⏱️ Timing & Clocking

* All logic synchronous to `pclk`
* Reset is asynchronous, active-low
* APB timing rules strictly followed:

  * Signals stable from `SETUP` through `ENABLE`
  * `PREADY` sampled only during `ENABLE`

---

## 🧪 Simulation & Verification

Verification uses a **directed, protocol-aware testbench**:

* Timeout-protected waits
* Snapshot capture at `PENABLE && PREADY`
* Console logs for transaction summaries
* Waveform inspection using VCD

---

## 📊 Example Simulation Output

```
WRITE to 0x25 → SUCCESS
READ  from 0x25 → Data = 0xAB
WRITE to 0x80 → PSLVERR asserted
```

### Waveform Confirms

* Correct SETUP/ENABLE sequencing
* Stable signals during ENABLE
* Proper error handling without deadlock

---

## 🚀 Quick Start

```
# Compile
iverilog -o apb_tb *.v

# Run simulation
vvp apb_tb

# View waveform
gtkwave waveform.vcd
```

---

## 🛠️ Tools Used

* Verilog HDL
* Icarus Verilog (iverilog)
* GTKWave
* (Optional) ModelSim / Vivado Simulator / EPWave

---

## 📁 Directory Structure

```
├── APB_master.v
├── APB_slave.v
├── APB_top.v
├── testbench.v
├── waveform.vcd
└── README.md
```

---

## ⚠️ Limitations

* Single outstanding transaction
* Fixed address map
* APB3 only (no APB4 extensions)
* No burst or pipelined transfers
* Fixed slave response latency
* No assertion-based verification

---

## 🔮 Future Enhancements

* Parameterized number of slaves
* APB4 support (`PSTRB`, `PPROT`)
* Configurable address and data widths
* Assertion-based verification (SVA)
* Randomized and coverage-driven testing
* Power-aware enhancements (clock gating)

---

**Author:** Devansh Swaroop
**Domain:** RTL Design · AMBA Protocols · VLSI / SoC Design
 
 
