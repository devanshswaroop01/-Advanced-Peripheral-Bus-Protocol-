`timescale 1ns / 1ps

//============================================================================
// MODULE: APB_master
//============================================================================
// DESCRIPTION:
//   Implements an AMBA APB 2.0 protocol-compliant master device. This module
//   generates all APB control signals and manages the transaction lifecycle
//   using a 3-state finite state machine (FSM).
//
// PROTOCOL COMPLIANCE:
//   - AMBA APB 2.0 Specification Compliant
//   - Implements IDLE → SETUP → ENABLE state sequence
//   - Latches address/control signals during SETUP phase
//   - Supports wait states via PREADY input
//   - Handles back-to-back transfers
//   - Full reset of all internal state
//
// ARCHITECTURE:
//   - 3-State Finite State Machine (FSM)
//     * IDLE   : No active transfer, bus is idle
//     * SETUP  : Address and control signals driven (PSEL=1, PENABLE=0)
//     * ENABLE : Data phase active (PSEL=1, PENABLE=1, wait for PREADY)
//   - Edge-triggered transfer detection (prevents retriggering)
//   - Signal latching for APB protocol compliance
//   - Read data capture on transaction completion
//
// FSM STATE DIAGRAM:
//
//         transfer_pulse
//   IDLE ──────────────► SETUP ──────► ENABLE
//     ▲                                  │
//     │         !transfer_pulse          │ pready
//     └──────────────────────────────────┘
//                (transfer complete)
//
// TIMING DIAGRAM (Single Write):
//   Cycle:    T0    T1    T2    T3
//   State:    IDLE  SETUP ENABLE IDLE
//   PSEL:     0     1     1      0
//   PENABLE:  0     0     1      0
//   PWRITE:   X     1     1      X
//   PADDR:    X     A     A      X
//   PWDATA:   X     D     D      X
//   PREADY:   X     X     1      X
//
// SIGNAL DESCRIPTION:
//   presetn          : Active-low asynchronous reset
//   pclk             : APB Clock
//   transfer         : Transfer request from user logic
//   read             : Read operation request
//   write            : Write operation request
//   apb_write_paddr  : Write address from user
//   apb_write_data   : Write data from user
//   apb_read_paddr   : Read address from user
//   pready           : Transfer complete from slave
//   pslverr          : Slave error indicator
//   prdata           : Read data from slave
//   psel1            : Slave 1 select output
//   psel2            : Slave 2 select output
//   penable          : ENABLE phase indicator output
//   pwrite           : Write/Read control output
//   paddr            : Address bus output
//   pwdata           : Write data bus output
//   apb_read_data_out: Latched read data to user
//============================================================================
module APB_master (
    //------------------------------------------------------------------------
    // CLOCK AND RESET
    //------------------------------------------------------------------------
    input  wire        presetn,           // Active-low asynchronous reset
    input  wire        pclk,              // APB Clock
    
    //------------------------------------------------------------------------
    // HIGH-LEVEL REQUEST INTERFACE
    //------------------------------------------------------------------------
    // These signals come from user logic and initiate APB transactions.
    // The master translates these requests into APB protocol signals.
    //------------------------------------------------------------------------
    input  wire        transfer,          // Transfer request from user
    input  wire        read,              // Read operation request
    input  wire        write,             // Write operation request
    
    //------------------------------------------------------------------------
    // ADDRESS/DATA INPUTS FROM USER LOGIC
    //------------------------------------------------------------------------
    // Separate address buses for read and write operations allow the
    // user to set up the next transaction while the current one completes.
    //------------------------------------------------------------------------
    input  wire [7:0]  apb_write_paddr,   // Write address from user
    input  wire [7:0]  apb_write_data,    // Write data from user
    input  wire [7:0]  apb_read_paddr,    // Read address from user
    
    //------------------------------------------------------------------------
    // APB SLAVE RESPONSE SIGNALS
    //------------------------------------------------------------------------
    // These signals come from the APB interconnect/slaves.
    // They indicate transaction completion, errors, and read data.
    //------------------------------------------------------------------------
    input  wire        pready,            // Transfer complete from slave
    input  wire        pslverr,           // Slave error indicator
    input  wire [7:0]  prdata,            // Read data from slave
    
    //------------------------------------------------------------------------
    // APB BUS OUTPUTS
    //------------------------------------------------------------------------
    // These signals drive the APB bus and are connected to all slaves
    // through the APB interconnect.
    //------------------------------------------------------------------------
    output reg         psel1,             // Slave 1 select
    output reg         psel2,             // Slave 2 select
    output reg         penable,           // ENABLE phase indicator
    output reg         pwrite,            // Write/Read control
    output reg [7:0]   paddr,             // Address bus
    output reg [7:0]   pwdata,            // Write data bus
    
    //------------------------------------------------------------------------
    // READ DATA OUTPUT
    //------------------------------------------------------------------------
    // Latched read data is provided to user logic.
    // This data is valid after a read transaction completes.
    //------------------------------------------------------------------------
    output reg [7:0]   apb_read_data_out  // Latched read data to user
);

    //========================================================================
    // FSM STATE ENCODING
    //========================================================================
    // APB Protocol defines three states for a transaction:
    //
    //   IDLE   : No active transaction. All outputs are inactive.
    //            The master waits for a transfer request.
    //
    //   SETUP  : Address and control signals are driven. PSEL is asserted
    //            but PENABLE remains low. This state ensures address and
    //            control signals are stable before the ENABLE phase.
    //
    //   ENABLE : Data phase. PENABLE is asserted. The master waits for
    //            PREADY from the slave to complete the transfer.
    //
    // State encoding uses 2 bits with one-hot-like assignment for
    // easier debug and waveform viewing.
    //========================================================================
    
    localparam IDLE   = 2'b00;      // No active transfer
    localparam SETUP  = 2'b01;      // Address/control setup phase
    localparam ENABLE = 2'b10;      // Data phase with PENABLE asserted

    reg [1:0] state, next_state;    // Current and next FSM state

    //========================================================================
    // TRANSFER EDGE DETECTION
    //========================================================================
    // The transfer signal is level-sensitive in the user interface.
    // To prevent multiple transactions from a single request, we detect
    // the rising edge of the transfer signal.
    //
    // How it works:
    //   1. transfer_d is a delayed version of transfer (1 cycle delay)
    //   2. transfer_pulse is asserted only when transfer is 1 AND
    //      transfer_d is 0 (i.e., on the rising edge of transfer)
    //
    // This ensures one APB transaction per user request, even if the
    // transfer signal remains asserted for multiple cycles.
    //========================================================================
    
    reg transfer_d;                      // Delayed transfer signal
    wire transfer_pulse;                 // Single-cycle pulse on rising edge

    //------------------------------------------------------------------------
    // Transfer Delay Register
    //------------------------------------------------------------------------
    // This register delays the transfer signal by one clock cycle.
    // On reset, it is cleared to 0.
    //------------------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            transfer_d <= 1'b0;         // Reset to 0
        else
            transfer_d <= transfer;     // Delay by 1 cycle
    end

    //------------------------------------------------------------------------
    // Rising Edge Detection
    //------------------------------------------------------------------------
    // transfer_pulse is high only when:
    //   - transfer is currently 1 (new request)
    //   - transfer_d is 0 (was 0 in previous cycle)
    // This represents a rising edge on the transfer signal.
    //------------------------------------------------------------------------
    assign transfer_pulse = transfer & ~transfer_d;

    //========================================================================
    // FSM STATE REGISTER
    //========================================================================
    // The state register holds the current FSM state.
    // It updates on every rising edge of PCLK.
    //
    // Reset Behavior:
    //   - Asynchronous reset forces the FSM to IDLE state
    //   - This ensures deterministic startup
    //
    // Normal Operation:
    //   - State transitions to next_state on each clock edge
    //========================================================================
    
    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            state <= IDLE;              // Reset to IDLE
        else
            state <= next_state;        // Update state
    end

    //========================================================================
    // FSM NEXT STATE LOGIC
    //========================================================================
    // This combinational logic determines the next state based on:
    //   - Current state
    //   - transfer_pulse (new request)
    //   - pready (slave ready)
    //
    // State Transition Rules:
    //
    //   IDLE:
    //     - If transfer_pulse=1 → SETUP (new transaction)
    //     - Otherwise → IDLE (remain idle)
    //
    //   SETUP:
    //     - Always → ENABLE (unconditional transition)
    //     - SETUP is always one cycle (address setup time)
    //
    //   ENABLE:
    //     - If pready=1:
    //         - If transfer_pulse=1 → SETUP (back-to-back transfer)
    //         - Otherwise → IDLE (transaction complete)
    //     - If pready=0 → ENABLE (wait state)
    //
    //   default:
    //     - → IDLE (safe recovery from invalid state)
    //
    // The default case is important for:
    //   - Preventing latch inference in synthesis
    //   - Safe recovery from illegal states
    //   - Handling X states in simulation
    //========================================================================
    
    always @(*) begin
        // Default assignment prevents latch inference
        next_state = IDLE;
        
        case (state)
            //----------------------------------------------------------------
            // IDLE STATE
            //----------------------------------------------------------------
            // Wait for a new transfer request.
            // When a request is detected (rising edge of transfer),
            // transition to SETUP state.
            //----------------------------------------------------------------
            IDLE: begin
                if (transfer_pulse)
                    next_state = SETUP; // New transfer starts
                else
                    next_state = IDLE;  // Stay idle
            end
            
            //----------------------------------------------------------------
            // SETUP STATE
            //----------------------------------------------------------------
            // Address and control signals are being driven.
            // After one cycle, always transition to ENABLE.
            // This ensures the required setup time for the address bus.
            //----------------------------------------------------------------
            SETUP: begin
                next_state = ENABLE;    // Always enter ENABLE
            end
            
            //----------------------------------------------------------------
            // ENABLE STATE
            //----------------------------------------------------------------
            // Data phase is active. Wait for PREADY from slave.
            //
            // If PREADY is asserted (slave is ready):
            //   - If a new transfer is requested → SETUP (back-to-back)
            //   - Otherwise → IDLE (transaction complete)
            //
            // If PREADY is not asserted (slave not ready):
            //   - Stay in ENABLE (wait state)
            //----------------------------------------------------------------
            ENABLE: begin
                if (pready) begin
                    // Transfer complete
                    if (transfer_pulse)
                        next_state = SETUP;   // Back-to-back transfer
                    else
                        next_state = IDLE;    // No new transfer
                end
                else begin
                    next_state = ENABLE;      // Wait for PREADY
                end
            end
            
            //----------------------------------------------------------------
            // DEFAULT STATE (Safety)
            //----------------------------------------------------------------
            // If the FSM ever enters an invalid state, return to IDLE.
            // This is a safety mechanism for robust design.
            //----------------------------------------------------------------
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    //========================================================================
    // CONTROL SIGNAL LATCHING
    //========================================================================
    // APB PROTOCOL REQUIREMENT:
    //   Address (PADDR), PWRITE, PSEL, and PWDATA must remain STABLE
    //   throughout the SETUP and ENABLE phases of a transaction.
    //
    // WHY LATCH?
    //   - The user interface signals (apb_read_paddr, apb_write_paddr,
    //     apb_write_data) may change during the transaction.
    //   - By latching them in SETUP, we freeze their values for the
    //     duration of the transaction.
    //   - This ensures APB protocol compliance.
    //
    // LATCHED SIGNALS:
    //   - latched_addr : Address bus (from read or write address)
    //   - latched_wdata: Write data (from apb_write_data)
    //   - latched_write: Operation type (from read/write inputs)
    //   - latched_psel1: Slave 1 select (derived from address)
    //   - latched_psel2: Slave 2 select (derived from address)
    //========================================================================
    
    reg [7:0] latched_addr;
    reg [7:0] latched_wdata;
    reg       latched_write;
    reg       latched_psel1;
    reg       latched_psel2;

    always @(posedge pclk or negedge presetn) begin
        //--------------------------------------------------------------------
        // Reset Condition
        //--------------------------------------------------------------------
        // Initialize all latched signals to their inactive state.
        // This ensures deterministic startup behavior.
        //--------------------------------------------------------------------
        if (!presetn) begin
            latched_addr   <= 8'h00;
            latched_wdata  <= 8'h00;
            latched_write  <= 1'b0;
            latched_psel1  <= 1'b0;
            latched_psel2  <= 1'b0;
        end
        
        //--------------------------------------------------------------------
        // Latch Signals During SETUP Phase
        //--------------------------------------------------------------------
        // The SETUP phase is the correct time to latch:
        //   - User signals are stable (user has provided the request)
        //   - PSEL is asserted but PENABLE is still low
        //   - This gives us one cycle to capture the signals
        //--------------------------------------------------------------------
        else if (state == SETUP) begin
            
            //----------------------------------------------------------------
            // Read Transaction Latching
            //----------------------------------------------------------------
            // When read=1 and write=0, this is a read operation.
            // Latch the read address and set up slave selects.
            //
            // Address decoding:
            //   - MSB (bit 7) = 0 : Address range 0x00-0x7F → Slave 1
            //   - MSB (bit 7) = 1 : Address range 0x80-0xFF → Slave 2
            //----------------------------------------------------------------
            if (read && !write) begin
                latched_addr  <= apb_read_paddr;
                latched_write <= 1'b0;      // Read operation
                latched_psel1 <= (apb_read_paddr[7] == 1'b0);
                latched_psel2 <= (apb_read_paddr[7] == 1'b1);
            end
            
            //----------------------------------------------------------------
            // Write Transaction Latching
            //----------------------------------------------------------------
            // When write=1 and read=0, this is a write operation.
            // Latch the write address, write data, and set up slave selects.
            //
            // Address decoding is the same as for reads.
            //----------------------------------------------------------------
            else if (write && !read) begin
                latched_addr  <= apb_write_paddr;
                latched_wdata <= apb_write_data;
                latched_write <= 1'b1;      // Write operation
                latched_psel1 <= (apb_write_paddr[7] == 1'b0);
                latched_psel2 <= (apb_write_paddr[7] == 1'b1);
            end
            
            //----------------------------------------------------------------
            // Invalid Request Handling
            //----------------------------------------------------------------
            // If both read and write are 0, or both are 1, no latching
            // occurs. The FSM will still transition to ENABLE, but the
            // latched signals retain their previous values.
            //
            // This is a design choice - the system could also be designed
            // to flag an error for illegal requests.
            //----------------------------------------------------------------
        end
    end

    //========================================================================
    // READ DATA CAPTURE
    //========================================================================
    // APB PROTOCOL REQUIREMENT:
    //   Read data (PRDATA) is valid when PREADY is asserted during
    //   the ENABLE phase. The master must capture this data.
    //
    // CAPTURE LOGIC:
    //   - When PENABLE=1, PREADY=1, and PWRITE=0 (read operation),
    //     capture the PRDATA value.
    //   - The captured data is provided to the user via
    //     apb_read_data_out.
    //
    // TIMING:
    //   - Data is captured on the PCLK rising edge
    //   - User can read the data after this edge
    //========================================================================
    
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            apb_read_data_out <= 8'h00;     // Reset output
        end
        else if (penable && pready && !pwrite) begin
            // Valid read transaction completion
            apb_read_data_out <= prdata;    // Capture read data
        end
        // Otherwise, hold the previous value (no spurious updates)
    end

    //========================================================================
    // APB OUTPUT LOGIC
    //========================================================================
    // This combinational logic drives the APB bus outputs based on:
    //   - Current FSM state
    //   - Latched control signals
    //
    // The outputs are generated as follows:
    //
    //   IDLE   : All outputs inactive (PSEL=0, PENABLE=0)
    //   SETUP  : PSEL asserted, PENABLE=0, address/control driven
    //   ENABLE : PSEL asserted, PENABLE=1, all signals driven
    //
    // IMPORTANT:
    //   - Using latched signals ensures stability during ENABLE phase
    //   - Default assignments prevent latch inference
    //   - Full case coverage with default is a best practice
    //========================================================================
    
    always @(*) begin
        //--------------------------------------------------------------------
        // Default Values
        //--------------------------------------------------------------------
        // Set all outputs to their inactive state by default.
        // This prevents accidental latching and ensures a known state
        // in all cases not explicitly covered.
        //--------------------------------------------------------------------
        psel1   = 1'b0;
        psel2   = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = 8'h00;
        pwdata  = 8'h00;

        case (state)
            //----------------------------------------------------------------
            // IDLE State
            //----------------------------------------------------------------
            // All outputs remain in their default (inactive) state.
            // The APB bus is idle.
            //----------------------------------------------------------------
            IDLE: begin
                // All outputs inactive (defaults apply)
            end
            
            //----------------------------------------------------------------
            // SETUP State
            //----------------------------------------------------------------
            // Assert PSEL and drive address/control signals.
            // PENABLE remains low (as required by APB spec).
            //
            // This is the address/control setup phase.
            //----------------------------------------------------------------
            SETUP: begin
                psel1   = latched_psel1;
                psel2   = latched_psel2;
                penable = 1'b0;             // PENABLE low in SETUP
                pwrite  = latched_write;
                paddr   = latched_addr;
                pwdata  = latched_wdata;
            end
            
            //----------------------------------------------------------------
            // ENABLE State
            //----------------------------------------------------------------
            // Assert PENABLE to indicate the data phase.
            // All other signals remain stable (from latched values).
            //
            // This is the data transfer phase where the slave responds.
            //----------------------------------------------------------------
            ENABLE: begin
                psel1   = latched_psel1;
                psel2   = latched_psel2;
                penable = 1'b1;             // PENABLE high in ENABLE
                pwrite  = latched_write;
                paddr   = latched_addr;
                pwdata  = latched_wdata;
            end
            
            //----------------------------------------------------------------
            // Default Case (Safety)
            //----------------------------------------------------------------
            // For any invalid state, all outputs remain inactive.
            // The defaults at the top of this block apply.
            //----------------------------------------------------------------
            default: begin
                // All outputs inactive (defaults apply)
            end
        endcase
    end

endmodule
