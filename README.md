# 📘 AMBA APB Master–Slave Peripheral System — Verilog HDL

A modular **AMBA APB-style Master–Slave peripheral system** implemented in
Verilog HDL, featuring an FSM-based APB master, address-decoded multi-slave
interconnect, memory-mapped APB slaves, error handling, timeout protection,
and a directed self-checking verification environment.

The project is designed as an **educational and interview-oriented RTL
implementation** demonstrating practical understanding of AMBA APB concepts,
FSM-based bus control, peripheral interfacing, memory mapping, response
aggregation, and RTL verification.

---

## 🔖 Overview

This project implements a small APB-based peripheral subsystem consisting of:

- FSM-based APB Master
- APB Top-Level Interconnect
- Two memory-mapped slave regions
- Address-based slave selection
- Read/write transaction support
- `PREADY` response handling
- `PSLVERR` error reporting
- Timeout protection
- Directed self-checking testbench
- Golden reference memory
- Transaction scoreboard/history
- Protocol signal monitoring
- Console-based verification
- VCD waveform generation

The implementation uses an **APB3-style signal set**, including `PREADY` and
`PSLVERR`.

> **Project positioning:** Educational / student / fresher-level RTL design
> project intended to demonstrate APB protocol concepts and RTL verification
> methodology. It is not intended to be a production AMBA peripheral fabric.

---

# 🧠 What is APB?

APB (Advanced Peripheral Bus) is a low-complexity AMBA bus interface commonly
used for connecting low-bandwidth peripherals and control/status registers.

APB is designed around a simple two-phase transfer:

```text
        SETUP PHASE             ACCESS PHASE

      PSEL = 1                PSEL = 1
      PENABLE = 0             PENABLE = 1
           │                       │
           └──────────►────────────┘
```

 ## 🔍 APB Protocol Characteristics

APB (Advanced Peripheral Bus) is a low-complexity AMBA bus interface designed 
for connecting low-bandwidth peripherals and control/status registers.

| Characteristic | Description |
|----------------|-------------|
| Low-complexity interface | Simple signal set for peripheral communication |
| Non-pipelined transfers | One transaction completes before the next begins |
| No burst transactions | Single read or write per transfer |
| Two-phase operation | SETUP phase followed by ENABLE phase |
| PREADY support | Allows slaves to insert wait states |
| PSLVERR support | Enables slaves to report errors |
| Stable address/control | Address and control signals remain valid throughout the transfer |

This project implements an **educational APB3-style interface** using these 
fundamental concepts.

---

## 🎯 Project Objectives

The primary objectives of this project are:

| # | Objective |
|---|-----------|
| 1 | Implement an FSM-based APB Master with IDLE → SETUP → ENABLE sequencing |
| 2 | Implement memory-mapped APB peripheral slaves |
| 3 | Demonstrate address-based slave selection |
| 4 | Implement APB read and write operations |
| 5 | Handle slave completion using PREADY |
| 6 | Propagate error information using PSLVERR |
| 7 | Include timeout protection against stalled transfers |
| 8 | Build a directed self-checking verification environment |
| 9 | Maintain a golden reference model for memory verification |
| 10 | Generate waveform and console information for debugging |

---

## ✨ Main Features

### RTL Features

| Category | Feature |
|----------|---------|
| **Master** | FSM-based APB Master |
| **FSM** | IDLE → SETUP → ENABLE transaction structure |
| **Operations** | Read and write support |
| **Slaves** | Two slave regions |
| **Decoding** | Address-based slave decoding |
| **Response** | Response aggregation |
| **Data Path** | Read-data multiplexing |
| **Handshake** | PREADY handling |
| **Errors** | PSLVERR handling |
| **Protection** | Timeout protection |
| **Reset** | Active-low reset |
| **Memory** | Memory-backed peripheral implementation |

### Verification Features

| Category | Feature |
|----------|---------|
| **Stimulus** | Directed transaction testing |
| **Checking** | Self-checking scoreboard |
| **Reference** | Golden reference memory |
| **Ordering** | Read-after-write verification |
| **Negative** | Invalid-address testing |
| **Boundary** | Boundary-address testing |
| **Sequence** | Sequential transaction testing |
| **Recovery** | Reset/recovery testing |
| **Stress** | Repeated write/read testing |
| **Metrics** | Performance measurement |
| **Debug** | Transaction history |
| **Logging** | Configurable debug logging |
| **Waveform** | VCD waveform generation |


\section{System Architecture}

\begin{center}
\begin{verbatim}
                    USER / TESTBENCH
                           |
                           v
                +---------------------+
                |      APB MASTER     |
                |                     |
                |  IDLE               |
                |    |                |
                |    v                |
                |  SETUP              |
                |    |                |
                |    v                |
                |  ENABLE             |
                +---------+-----------+
                          |
                          | APB BUS
                          |
                          v
                +---------------------+
                |      APB_TOP        |
                |                     |
                | Address Decoder     |
                | Response Aggregator |
                +---------+-----------+
                          |
                +---------+---------+
                |                   |
                v                   v
       +----------------+   +----------------+
       |    SLAVE 1     |   |    SLAVE 2     |
       |                |   |                |
       | 0x00 - 0x7F    |   | 0x80 - 0xFF    |
       | Memory-backed  |   | Error/Slave    |
       | Peripheral     |   | Response       |
       +----------------+   +----------------+
                |                   |
                +---------+---------+
                          |
                    PREADY / PSLVERR
                          |
                          v
                    APB MASTER
\end{verbatim}
\end{center}

\subsection{Module Description}

\subsubsection{APB\_master}

The APB Master controls the APB transaction sequence using an FSM.

\textbf{Main responsibilities:}
\begin{itemize}
    \item Accept user read/write requests
    \item Generate APB control signals
    \item Generate PSEL
    \item Generate PENABLE
    \item Generate PWRITE
    \item Drive address and write data
    \item Wait for transaction completion
    \item Capture read response
    \item Return to the idle state
\end{itemize}

\textbf{FSM:}

\begin{center}
\begin{verbatim}
                  transfer request
                        |
                        v
                    +------+
              +---->| IDLE |
              |     +--+---+
              |        |
              |        v
              |    +--------+
              |    | SETUP  |
              |    +----+---+
              |         |
              |         v
              |    +--------+
              |    | ENABLE |
              |    +----+---+
              |         |
              |         | PREADY
              |         v
              +---------+
\end{verbatim}
\end{center}

\subsubsection{APB\_top}

APB\_top integrates the master and slave subsystem.

\textbf{Responsibilities:}
\begin{itemize}
    \item Instantiate the APB Master
    \item Instantiate APB slaves
    \item Decode the APB address
    \item Generate slave-select signals
    \item Aggregate PREADY
    \item Aggregate PSLVERR
    \item Multiplex returned PRDATA
    \item Provide timeout handling
\end{itemize}

\subsubsection{APB\_slave}

The slave implements a simple memory-mapped peripheral.

\textbf{Characteristics:}
\begin{itemize}
    \item 8-bit address
    \item 8-bit data
    \item Memory-backed storage
    \item Read operation
    \item Write operation
    \item Response generation
    \item Invalid-address handling
\end{itemize}

\subsection{APB Interface Signals}

\begin{table}[h]
\centering
\begin{tabular}{|l|l|l|}
\hline
\textbf{Signal} & \textbf{Direction} & \textbf{Description} \\
\hline
pclk     & Input  & APB clock \\
presetn  & Input  & Active-low reset \\
PSELx    & Output & Slave selection \\
PENABLE  & Output & APB access phase \\
PWRITE   & Output & Read/write indication \\
PADDR    & Output & APB address \\
PWDATA   & Output & Write data \\
PRDATA   & Input  & Read data \\
PREADY   & Input  & Transfer completion \\
PSLVERR  & Input  & Error indication \\
\hline
\end{tabular}
\caption{APB Interface Signals}
\end{table}

The design also includes a custom user-side request interface consisting of
transfer, read, write, address inputs, and write data.

\subsection{Address Map}

The current implementation uses an 8-bit address space.

\begin{table}[h]
\centering
\begin{tabular}{|l|l|l|}
\hline
\textbf{Address Range} & \textbf{Region} & \textbf{Purpose} \\
\hline
0x00 -- 0x7F & Slave 1 & Valid memory-backed peripheral \\
0x80 -- 0xFF & Slave 2 / invalid region & Error-response region \\
\hline
\end{tabular}
\caption{Address Map}
\end{table}

\textbf{Boundary examples:}
\begin{itemize}
    \item 0x00 $\rightarrow$ Valid
    \item 0x7F $\rightarrow$ Valid
    \item 0x80 $\rightarrow$ Invalid / Error
    \item 0xFF $\rightarrow$ Invalid / Error
\end{itemize}

\subsection{APB Transaction Flow}

A typical transaction follows:

\begin{center}
\begin{verbatim}
1. User generates transfer request
             |
             v
2. Master enters SETUP
             |
             v
3. PSEL is asserted
             |
             v
4. Master enters ENABLE
             |
             v
5. PENABLE is asserted
             |
             v
6. Selected slave processes request
             |
             v
7. Slave provides PREADY
             |
             +---------------+
             |               |
             v               v
          Success           Error
             |               |
             |            PSLVERR
             v               |
       Read/write complete <-+
\end{verbatim}
\end{center}

\subsection{Read Transaction}

Example:

\begin{center}
\begin{verbatim}
User
 |
 | READ address = 0x25
 v
APB Master
 |
 +-- SETUP
 |
 +-- ENABLE
 |
 v
Slave 1
 |
 +-- Read memory[0x25]
 |
 +-- Return PRDATA
 |
 v
APB Master
 |
 v
User
\end{verbatim}
\end{center}

\subsection{Write Transaction}

Example:

\begin{center}
\begin{verbatim}
User
 |
 | WRITE address = 0x25
 | WRITE data    = 0xAB
 v
APB Master
 |
 +-- SETUP
 |
 +-- ENABLE
 |
 v
Slave 1
 |
 +-- memory[0x25] = 0xAB
 |
 v
PREADY
 |
 v
Transaction Complete
\end{verbatim}
\end{center}

\subsection{Error Handling}

The design provides error handling through PSLVERR.

For example:

\begin{center}
\begin{tabular}{l l}
WRITE 0x25 & $\rightarrow$ Valid \\
READ  0x25 & $\rightarrow$ Valid \\
WRITE 0x80 & $\rightarrow$ Error \\
READ  0x80 & $\rightarrow$ Error \\
WRITE 0xFF & $\rightarrow$ Error \\
READ  0xFF & $\rightarrow$ Error \\
\end{tabular}
\end{center}

The verification environment explicitly tests invalid addresses and checks
the resulting error response.


\section{Timeout Protection}

The top-level interconnect includes timeout logic to prevent the system from
waiting indefinitely for an expected slave response.

Conceptually:

\begin{center}
\begin{verbatim}
ENABLE
  |
  +-- PREADY = 1
  |      |
  |      +-- Complete normally
  |
  +-- PREADY = 0
         |
         v
    Timeout Counter
         |
         v
    Timeout Condition
         |
         v
    Error / Recovery
\end{verbatim}
\end{center}

This makes timeout handling an explicit part of the educational design.

\section{Verification Environment}

The project includes a dedicated directed self-checking Verilog testbench.

The verification environment contains:

\begin{center}
\begin{verbatim}
                    TESTBENCH
                        |
        +---------------+----------------+
        |               |                |
        v               v                v
     Stimulus       Reference Model    Monitoring
        |               |                |
        +---------------+----------------+
                        v
                   Scoreboard
                        |
                +-------+-------+
                v               v
              PASS             FAIL
\end{verbatim}
\end{center}

\section{Verification Strategy}

The testbench uses directed, deterministic tests rather than randomized
verification.

\subsection{Test Group 1 --- Basic Functionality}

Includes:
\begin{itemize}
    \item Simple write
    \item Simple read
    \item Write followed by read
    \item Multiple writes
    \item Multiple reads
\end{itemize}

\subsection{Test Group 2 --- Error and Boundary Conditions}

Includes:
\begin{itemize}
    \item Invalid address 0x80
    \item Invalid address 0xFF
    \item Last valid address 0x7F
    \item Zero address 0x00
    \item Boundary read/write operations
\end{itemize}

\subsection{Test Group 3 --- Stress and Corner Cases}

Includes:
\begin{itemize}
    \item Sequential write transactions
    \item Sequential read transactions
    \item Maximum data value 0xFF
    \item Minimum data value 0x00
    \item Alternating write/read operations
    \item Repeated transactions
\end{itemize}

\subsection{Test Group 4 --- Reset Recovery}

Includes:
\begin{itemize}
    \item Reset during transaction scenario
    \item Reset followed by transaction
    \item Multiple reset cycles
    \item Post-reset read/write verification
\end{itemize}

\subsection{Test Group 5 --- Performance Measurement}

The testbench executes 50 write operations and measures the end-to-end
simulation time of the testbench transaction sequence.

The recorded simulation result was:

\begin{center}
\textbf{50 writes in 8500 ns} \\
\textbf{Average: 170 ns per testbench write operation}
\end{center}

This measurement includes the testbench transaction-control and waiting
overhead and should not be interpreted as the raw APB bus bandwidth.

\section{Final Simulation Result}

The final directed simulation completed successfully.

\begin{center}
\begin{tabular}{|l|l|}
\hline
\textbf{FINAL TEST SUMMARY} & \\
\hline
Total Tests   & 108 \\
Passed        & 108 \\
Failed        & 0 \\
Warnings      & 1 \\
Pass Rate     & 100.0\% \\
\hline
\end{tabular}
\end{center}

\begin{center}
\textbf{[PASS] ALL TESTS PASSED}
\end{center}

The simulation completed normally and generated a VCD waveform for further
inspection.

The reported 100\% pass rate represents the checks implemented by the
directed scoreboard/testbench. It should not be interpreted as exhaustive
formal or protocol-compliance verification.

\section{Verification Results}

\begin{table}[h]
\centering
\begin{tabular}{|l|l|}
\hline
\textbf{Verification Item} & \textbf{Result} \\
\hline
Basic write                & PASS \\
Basic read                 & PASS \\
Read-after-write           & PASS \\
Multiple addresses         & PASS \\
Address 0x00               & PASS \\
Address 0x7F               & PASS \\
Invalid address 0x80       & PASS \\
Invalid address 0xFF       & PASS \\
0x00 data pattern          & PASS \\
0xFF data pattern          & PASS \\
Sequential transactions    & PASS \\
Alternating read/write     & PASS \\
Reset/recovery scenarios   & PASS \\
Performance workload       & PASS \\
Scoreboard checks          & PASS \\
\hline
Functional failures        & 0 \\
Reported warnings          & 1 \\
\hline
\end{tabular}
\caption{Verification Results}
\end{table}

\section{Simulation and Debugging}

The testbench provides:
\begin{itemize}
    \item Console transaction logs
    \item Error and warning messages
    \item Transaction history
    \item Golden reference memory
    \item Self-checking comparisons
    \item Internal APB signal visibility
    \item VCD waveform generation
\end{itemize}

The generated waveform can be inspected using GTKWave or EPWave.

Useful signals include:

\begin{multicols}{2}
\begin{itemize}
    \item PSEL
    \item PENABLE
    \item PADDR
    \item PWDATA
    \item PWRITE
    \item PREADY
    \item PSLVERR
    \item PRDATA
    \item transfer
    \item read
    \item write
    \item master\_state
\end{itemize}
\end{multicols}

\section{Tools Used}

\begin{table}[h]
\centering
\begin{tabular}{|l|l|}
\hline
\textbf{Category} & \textbf{Tools} \\
\hline
HDL               & Verilog HDL \\
Simulation        & Icarus Verilog, VCS / EPWave-compatible flow \\
Waveform Debugging & GTKWave, EPWave \\
Optional Tools    & ModelSim, Vivado Simulator \\
\hline
\end{tabular}
\caption{Tools Used}
\end{table}

\section{Project Structure}

\begin{center}
\begin{verbatim}
APB-Peripheral-Interface/
|
+-- APB_master.v
+-- APB_slave.v
+-- APB_top.v
+-- testbench.v
|
+-- apb_sim.vcd
|
+-- README.md
\end{verbatim}
\end{center}

\section{Quick Start}

\subsection{Compile}

\begin{verbatim}
iverilog -o apb_sim -g2009 \
    APB_master.v \
    APB_slave.v \
    APB_top.v \
    testbench.v
\end{verbatim}

\subsection{Run}

\begin{verbatim}
vvp apb_sim
\end{verbatim}

\subsection{View waveform}

\begin{verbatim}
gtkwave apb_sim.vcd
\end{verbatim}

\section{What This Project Demonstrates}

This project demonstrates practical understanding of:
\begin{itemize}
    \item RTL design methodology
    \item Finite State Machines
    \item AMBA APB concepts
    \item Master--slave communication
    \item Memory-mapped peripherals
    \item Address decoding
    \item Bus response aggregation
    \item Error handling
    \item Timeout protection
    \item Synchronous digital design
    \item Reset handling
    \item Directed verification
    \item Reference modeling
    \item Scoreboards
    \item Waveform-based debugging
    \item Simulation-driven RTL debugging
\end{itemize}

\section{Current Scope and Limitations}

This implementation is intentionally an educational RTL design.

Current limitations include:
\begin{itemize}
    \item Fixed 8-bit address width
    \item Fixed 8-bit data width
    \item Fixed two-region address map
    \item Single outstanding transaction
    \item No APB4 PSTRB
    \item No APB4 PPROT
    \item No burst transactions
    \item No pipelined transactions
    \item No randomized stimulus
    \item No functional coverage model
    \item No SystemVerilog Assertions
    \item No UVM environment
    \item Limited protocol assertion/checking
    \item Memory implementation is intended primarily for educational simulation
    \item Custom user-side transfer/read/write interface rather than a standardized upstream bus interface
\end{itemize}

The design should therefore be considered an educational APB-style
peripheral subsystem rather than a production AMBA interconnect.

\section{Future Enhancements}

Possible future extensions include:

\subsection{RTL}
\begin{itemize}
    \item Parameterized address width
    \item Parameterized data width
    \item Parameterized number of slaves
    \item Configurable address map
    \item APB4 support
    \item PSTRB support
    \item PPROT support
    \item Additional peripheral types
    \item More configurable wait states
\end{itemize}

\subsection{Verification}
\begin{itemize}
    \item SystemVerilog Assertions
    \item APB protocol assertion library
    \item Constrained-random stimulus
    \item Functional coverage
    \item Coverage-driven verification
    \item SystemVerilog/UVM testbench
    \item Automated regression testing
    \item Formal protocol verification
\end{itemize}

\section{Key Design Learning}

The project was developed to understand the complete RTL-to-verification
workflow:

\begin{center}
\begin{verbatim}
Specification
      |
      v
Architecture
      |
      v
FSM Design
      |
      v
RTL Implementation
      |
      v
Integration
      |
      v
Testbench
      |
      v
Reference Model
      |
      v
Scoreboard
      |
      v
Simulation
      |
      v
Waveform Debugging
      |
      v
Functional Validation
\end{verbatim}
\end{center}

The primary learning outcome is understanding how a simple AMBA peripheral
protocol can be translated into synthesizable RTL and then verified using a
self-checking simulation environment.

\section{Project Status}

\textbf{Status:} Completed / Frozen for Portfolio and Academic Defense

The current implementation is considered the final educational version of
the project.

No production-level compliance or exhaustive protocol-verification claim is
made.

\section{Author}

\textbf{Devansh Swaroop}

\textbf{Domain:} RTL Design \(\cdot\) Verilog HDL \(\cdot\) AMBA/APB \(\cdot\) VLSI \(\cdot\) SoC Design \(\cdot\) Digital Verification
