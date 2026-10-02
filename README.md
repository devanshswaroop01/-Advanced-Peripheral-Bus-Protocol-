#  AMBA APB Master–Slave Peripheral System — Verilog HDL

A modular **AMBA APB-style Master–Slave peripheral system** implemented in
Verilog HDL, featuring an FSM-based APB master, address-decoded multi-slave
interconnect, memory-mapped APB slaves, error handling, timeout protection,
and a directed self-checking verification environment.

The project is designed as an **educational and interview-oriented RTL
implementation** demonstrating practical understanding of AMBA APB concepts,
FSM-based bus control, peripheral interfacing, memory mapping, response
aggregation, and RTL verification.

---

##  Overview

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

#  What is APB?

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

 ##  APB Protocol Characteristics

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

##  Project Objectives

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

##  Main Features

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


##  System Architecture

```
                    USER / TESTBENCH
                           │
                           ▼
                ┌─────────────────────┐
                │      APB MASTER     │
                │                     │
                │  IDLE               │
                │    ↓                │
                │  SETUP              │
                │    ↓                │
                │  ENABLE             │
                └─────────┬───────────┘
                          │
                          │ APB BUS
                          ▼
                ┌─────────────────────┐
                │      APB_TOP        │
                │                     │
                │ Address Decoder     │
                │ Response Aggregator │
                └─────────┬───────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
                ▼                   ▼
       ┌────────────────┐   ┌────────────────┐
       │    SLAVE 1     │   │    SLAVE 2     │
       │                │   │                │
       │ 0x00 – 0x7F    │   │ 0x80 – 0xFF    │
       │ Memory-backed  │   │ Error/Slave    │
       │ Peripheral     │   │ Response       │
       └────────────────┘   └────────────────┘
                │                   │
                └─────────┬─────────┘
                          │
                    PREADY / PSLVERR
                          │
                          ▼
                    APB MASTER
```

---

###  Module Description

#### 1. APB_master

The APB Master controls the APB transaction sequence using an FSM.

**Main responsibilities:**

- Accept user read/write requests
- Generate APB control signals
- Generate PSEL
- Generate PENABLE
- Generate PWRITE
- Drive address and write data
- Wait for transaction completion
- Capture read response
- Return to the idle state

**FSM:**

```
                  transfer request
                        │
                        ▼
                    ┌──────┐
              ┌────►│ IDLE │
              │     └──┬───┘
              │        │
              │        ▼
              │    ┌────────┐
              │    │ SETUP  │
              │    └────┬───┘
              │         │
              │         ▼
              │    ┌────────┐
              │    │ ENABLE │
              │    └────┬───┘
              │         │
              │         │ PREADY
              │         ▼
              └─────────┘
```

---

#### 2. APB_top

APB_top integrates the master and slave subsystem.

**Responsibilities:**

- Instantiate the APB Master
- Instantiate APB slaves
- Decode the APB address
- Generate slave-select signals
- Aggregate PREADY
- Aggregate PSLVERR
- Multiplex returned PRDATA
- Provide timeout handling

---

#### 3. APB_slave

The slave implements a simple memory-mapped peripheral.

**Characteristics:**

- 8-bit address
- 8-bit data
- Memory-backed storage
- Read operation
- Write operation
- Response generation
- Invalid-address handling
- 
###  APB Interface Signals

| Signal | Direction | Description |
|--------|-----------|-------------|
| pclk | Input | APB clock |
| presetn | Input | Active-low reset |
| PSELx | Output | Slave selection |
| PENABLE | Output | APB access phase |
| PWRITE | Output | Read/write indication |
| PADDR | Output | APB address |
| PWDATA | Output | Write data |
| PRDATA | Input | Read data |
| PREADY | Input | Transfer completion |
| PSLVERR | Input | Error indication |

The design also includes a custom user-side request interface consisting of transfer, read, write, address inputs, and write data.

---

###  Address Map

The current implementation uses an 8-bit address space.

| Address Range | Region | Purpose |
|---------------|--------|---------|
| 0x00 – 0x7F | Slave 1 | Valid memory-backed peripheral |
| 0x80 – 0xFF | Slave 2 / invalid region | Error-response region |

**Boundary examples:**

- 0x00 → Valid
- 0x7F → Valid
- 0x80 → Invalid / Error
- 0xFF → Invalid / Error

---

###  APB Transaction Flow

A typical transaction follows:

```
1. User generates transfer request
             │
             ▼
2. Master enters SETUP
             │
             ▼
3. PSEL is asserted
             │
             ▼
4. Master enters ENABLE
             │
             ▼
5. PENABLE is asserted
             │
             ▼
6. Selected slave processes request
             │
             ▼
7. Slave provides PREADY
             │
             ├───────────────┐
             │               │
             ▼               ▼
          Success           Error
             │               │
             │            PSLVERR
             ▼               │
       Read/write complete ◄─┘
```

---

###  Read Transaction

Example:

```
User
 │
 │ READ address = 0x25
 ▼
APB Master
 │
 ├── SETUP
 │
 ├── ENABLE
 │
 ▼
Slave 1
 │
 ├── Read memory[0x25]
 │
 └── Return PRDATA
 │
 ▼
APB Master
 │
 ▼
User
```

---

###  Write Transaction

Example:

```
User
 │
 │ WRITE address = 0x25
 │ WRITE data    = 0xAB
 ▼
APB Master
 │
 ├── SETUP
 │
 ├── ENABLE
 │
 ▼
Slave 1
 │
 └── memory[0x25] = 0xAB
 │
 ▼
PREADY
 │
 ▼
Transaction Complete
```

---

###  Error Handling

The design provides error handling through PSLVERR.

For example:

| Operation | Result |
|-----------|--------|
| WRITE 0x25 | Valid |
| READ 0x25 | Valid |
| WRITE 0x80 | Error |
| READ 0x80 | Error |
| WRITE 0xFF | Error |
| READ 0xFF | Error |

The verification environment explicitly tests invalid addresses and checks the resulting error response. 


##  Timeout Protection

The top-level interconnect includes timeout logic to prevent the system from waiting indefinitely for an expected slave response.

Conceptually:

```
ENABLE
  │
  ├── PREADY = 1
  │      │
  │      └── Complete normally
  │
  └── PREADY = 0
         │
         ▼
    Timeout Counter
         │
         ▼
    Timeout Condition
         │
         ▼
    Error / Recovery
```

This makes timeout handling an explicit part of the educational design.

---

##  Verification Environment

The project includes a dedicated directed self-checking Verilog testbench.

The verification environment contains:

```
                    TESTBENCH
                        │
        ┌───────────────┼────────────────┐
        │               │                │
        ▼               ▼                ▼
     Stimulus       Reference Model    Monitoring
        │               │                │
        └───────────────┼────────────────┘
                        ▼
                   Scoreboard
                        │
                ┌───────┴───────┐
                ▼               ▼
              PASS             FAIL
```

---

##  Verification Strategy

The testbench uses directed, deterministic tests rather than randomized verification.

### Test Group 1 — Basic Functionality

Includes:

- Simple write
- Simple read
- Write followed by read
- Multiple writes
- Multiple reads

### Test Group 2 — Error & Boundary Conditions

Includes:

- Invalid address 0x80
- Invalid address 0xFF
- Last valid address 0x7F
- Zero address 0x00
- Boundary read/write operations

### Test Group 3 — Stress & Corner Cases

Includes:

- Sequential write transactions
- Sequential read transactions
- Maximum data value 0xFF
- Minimum data value 0x00
- Alternating write/read operations
- Repeated transactions

### Test Group 4 — Reset Recovery

Includes:

- Reset during transaction scenario
- Reset followed by transaction
- Multiple reset cycles
- Post-reset read/write verification

### Test Group 5 — Performance Measurement

The testbench executes 50 write operations and measures the end-to-end simulation time of the testbench transaction sequence.

The recorded simulation result was:

**50 writes in 8500 ns**
**Average: 170 ns per testbench write operation**

This measurement includes the testbench transaction-control and waiting overhead and should not be interpreted as the raw APB bus bandwidth.

---

##  Final Simulation Result

The final directed simulation completed successfully.

```
┌──────────────────────────────────────────┐
│         FINAL TEST SUMMARY               │
├──────────────────────────────────────────┤
│ Total Tests  : 108                       │
│ Passed       : 108                       │
│ Failed       : 0                         │
│ Warnings     : 1                         │
│ Pass Rate    : 100.0%                    │
└──────────────────────────────────────────┘
[PASS] ALL TESTS PASSED
```

The simulation completed normally and generated a VCD waveform for further inspection.

The reported 100% pass rate represents the checks implemented by the directed scoreboard/testbench. It should not be interpreted as exhaustive formal or protocol-compliance verification.

---

##  Verification Results

| Verification Item | Result |
|-------------------|--------|
| Basic write | ✅ PASS |
| Basic read | ✅ PASS |
| Read-after-write | ✅ PASS |
| Multiple addresses | ✅ PASS |
| Address 0x00 | ✅ PASS |
| Address 0x7F | ✅ PASS |
| Invalid address 0x80 | ✅ PASS |
| Invalid address 0xFF | ✅ PASS |
| 0x00 data pattern | ✅ PASS |
| 0xFF data pattern | ✅ PASS |
| Sequential transactions | ✅ PASS |
| Alternating read/write | ✅ PASS |
| Reset/recovery scenarios | ✅ PASS |
| Performance workload | ✅ PASS |
| Scoreboard checks | ✅ PASS |
| **Functional failures** | **0** |
| **Reported warnings** | **1** |

---

##  Simulation and Debugging

The testbench provides:

- Console transaction logs
- Error and warning messages
- Transaction history
- Golden reference memory
- Self-checking comparisons
- Internal APB signal visibility
- VCD waveform generation

The generated waveform can be inspected using GTKWave or EPWave.

Useful signals include:

| Signal | Signal |
|--------|--------|
| PSEL | PSLVERR |
| PENABLE | PRDATA |
| PADDR | transfer |
| PWDATA | read |
| PWRITE | write |
| PREADY | master_state | 

##  Tools Used

| Category | Tools |
|----------|-------|
| HDL | Verilog HDL |
| Simulation | Icarus Verilog, VCS / EPWave-compatible flow |
| Waveform Debugging | GTKWave, EPWave |
| Optional Tools | ModelSim, Vivado Simulator |

---

##  Project Structure

```
APB-Peripheral-Interface/
│
├── APB_master.v
├── APB_slave.v
├── APB_top.v
├── testbench.v
│
├── apb_sim.vcd
│
└── README.md
```

---

##  What This Project Demonstrates

This project demonstrates practical understanding of:

- RTL design methodology
- Finite State Machines
- AMBA APB concepts
- Master–slave communication
- Memory-mapped peripherals
- Address decoding
- Bus response aggregation
- Error handling
- Timeout protection
- Synchronous digital design
- Reset handling
- Directed verification
- Reference modeling
- Scoreboards
- Waveform-based debugging
- Simulation-driven RTL debugging

---

##  Current Scope and Limitations

This implementation is intentionally an educational RTL design.

Current limitations include:

- Fixed 8-bit address width
- Fixed 8-bit data width
- Fixed two-region address map
- Single outstanding transaction
- No APB4 PSTRB
- No APB4 PPROT
- No burst transactions
- No pipelined transactions
- No randomized stimulus
- No functional coverage model
- No SystemVerilog Assertions
- No UVM environment
- Limited protocol assertion/checking
- Memory implementation is intended primarily for educational simulation
- Custom user-side transfer/read/write interface rather than a standardized upstream bus interface

The design should therefore be considered an educational APB-style peripheral subsystem rather than a production AMBA interconnect.

---

##  Future Enhancements

Possible future extensions include:

### RTL

- Parameterized address width
- Parameterized data width
- Parameterized number of slaves
- Configurable address map
- APB4 support
- PSTRB support
- PPROT support
- Additional peripheral types
- More configurable wait states

### Verification

- SystemVerilog Assertions
- APB protocol assertion library
- Constrained-random stimulus
- Functional coverage
- Coverage-driven verification
- SystemVerilog/UVM testbench
- Automated regression testing
- Formal protocol verification

---

##  Key Design Learning

The project was developed to understand the complete RTL-to-verification workflow:

```
Specification
      │
      ▼
Architecture
      │
      ▼
FSM Design
      │
      ▼
RTL Implementation
      │
      ▼
Integration
      │
      ▼
Testbench
      │
      ▼
Reference Model
      │
      ▼
Scoreboard
      │
      ▼
Simulation
      │
      ▼
Waveform Debugging
      │
      ▼
Functional Validation
```

The primary learning outcome is understanding how a simple AMBA peripheral protocol can be translated into synthesizable RTL and then verified using a self-checking simulation environment.

---

##  Project Status

**Status:** Completed / Frozen for Portfolio and Academic Defense

The current implementation is considered the final educational version of the project.

No production-level compliance or exhaustive protocol-verification claim is made.

---
