`timescale 1ns / 1ps

//============================================================================
// MODULE: APB_slave
//============================================================================
// DESCRIPTION:
//   Implements an AMBA APB 2.0 protocol-compliant slave device with a
//   byte-addressable memory interface. This slave responds to read and write
//   transactions initiated by an APB master.
//
// PROTOCOL COMPLIANCE:
//   - AMBA APB 2.0 Specification Compliant
//   - Responds only when selected (PSEL=1) and in ENABLE phase (PENABLE=1)
//   - Single-cycle PREADY assertion (zero wait-state operation)
//   - Full support for read and write transactions
//   - Error signaling via PSLVERR
//
// ARCHITECTURE:
//   - 256-byte byte-addressable memory array
//   - Synchronous read/write operations (clocked on PCLK rising edge)
//   - Asynchronous active-low reset (PRESETn)
//   - Address decoding: MSB determines valid/invalid access
//
// MEMORY MAP:
//   - 0x00 - 0x7F : Valid addresses (read/write allowed)
//   - 0x80 - 0xFF : Invalid addresses (error signaled)
//
// TIMING:
//   - Read data available in same cycle as PREADY assertion
//   - Write data captured on PCLK rising edge when PSEL=1 and PENABLE=1
//   - Single-cycle response (no wait states)
//
// SIGNAL DESCRIPTION:
//   pclk    : APB Clock - all operations synchronous to rising edge
//   presetn : Active-low asynchronous reset
//   psel    : Slave select - indicates this slave is targeted
//   penable : ENABLE phase indicator - data phase active
//   pwrite  : Write control - 1=Write operation, 0=Read operation
//   paddr   : 8-bit address bus
//   pwdata  : 8-bit write data bus
//   prdata  : 8-bit read data bus (driven by slave)
//   pready  : Transfer completion signal (slave asserts when ready)
//   pslverr : Slave error indicator (asserted on invalid access)
//============================================================================
module APB_slave (
    //------------------------------------------------------------------------
    // CLOCK AND RESET INPUTS
    //------------------------------------------------------------------------
    input  wire        pclk,           // APB Clock - rising edge active
    input  wire        presetn,        // Active-low asynchronous reset
    
    //------------------------------------------------------------------------
    // APB CONTROL SIGNALS (INPUTS from master)
    //------------------------------------------------------------------------
    input  wire        psel,           // Slave select from master
    input  wire        penable,        // ENABLE phase indicator
    input  wire        pwrite,         // Write/Read control: 1=Write, 0=Read
    
    //------------------------------------------------------------------------
    // APB ADDRESS/DATA INPUTS
    //------------------------------------------------------------------------
    input  wire [7:0]  paddr,          // 8-bit address bus
    input  wire [7:0]  pwdata,         // 8-bit write data bus
    
    //------------------------------------------------------------------------
    // APB RESPONSE OUTPUTS
    //------------------------------------------------------------------------
    output reg  [7:0]  prdata,         // 8-bit read data bus
    output reg         pready,         // Transfer completion signal
    output reg         pslverr         // Slave error indicator
);

    //========================================================================
    // INTERNAL MEMORY DECLARATION
    //========================================================================
    // The slave implements a 256-byte byte-addressable memory.
    // Each address location stores 8 bits of data.
    // 
    // Memory Organization:
    //   - memory[0x00] : First byte
    //   - memory[0x7F] : Last valid byte
    //   - memory[0x80] : First invalid byte (unused)
    //   - memory[0xFF] : Last byte (unused)
    //
    // Synthesis Note:
    //   - This will infer either distributed RAM or block RAM depending on
    //     the target technology and synthesis tool settings.
    //   - For FPGA: Typically infers Block RAM (BRAM) or Distributed RAM
    //   - For ASIC: Typically infers flip-flops or compiled memory
    //========================================================================
    
    reg [7:0] memory [0:255];   // 256 x 8-bit memory array
    integer idx;                 // Loop counter for reset initialization

    //========================================================================
    // SYNCHRONOUS LOGIC - APB SLAVE OPERATION
    //========================================================================
    // This always block implements the core APB slave functionality.
    // All state updates occur on the rising edge of PCLK.
    //
    // Reset Behavior:
    //   - Asynchronous reset (presetn) initializes all memory and outputs
    //   - Ensures deterministic startup after power-on or reset
    //
    // Normal Operation:
    //   - Responds only when PSEL=1 and PENABLE=1 (APB ENABLE phase)
    //   - Performs read or write based on PWRITE signal
    //   - Asserts PREADY to indicate transfer completion
    //   - Asserts PSLVERR for invalid address accesses
    //
    // Why Default Assignments?
    //   - Prevents stale PREADY/PSLVERR from previous cycles
    //   - Ensures APB protocol compliance (slave must not drive PREADY
    //     when not selected)
    //   - Avoids inferring latches in synthesis
    //========================================================================
    
    always @(posedge pclk or negedge presetn) begin
        
        //====================================================================
        // RESET CONDITION (presetn = 0)
        //====================================================================
        // When reset is asserted (active-low), initialize:
        //   1. All memory locations to 0x00
        //   2. All output signals to inactive state
        //
        // This ensures:
        //   - Deterministic memory contents after reset
        //   - No unknown (X) states in simulation
        //   - Proper startup behavior in hardware
        //====================================================================
        if (!presetn) begin
            
            //----------------------------------------------------------------
            // Initialize Memory Array
            //----------------------------------------------------------------
            // Loop through all 256 memory locations and set to 0x00.
            // This is synthesizable and will generate appropriate reset
            // logic for the memory elements.
            //----------------------------------------------------------------
            for (idx = 0; idx < 256; idx = idx + 1)
                memory[idx] <= 8'h00;

            //----------------------------------------------------------------
            // Initialize Output Signals
            //----------------------------------------------------------------
            // Set all APB response signals to inactive state.
            // This ensures the slave does not drive PREADY or PSLVERR
            // until a valid transaction occurs.
            //----------------------------------------------------------------
            pready  <= 1'b0;        // No transfer in progress
            pslverr <= 1'b0;        // No error
            prdata  <= 8'h00;       // Read data = 0
        end
        
        //====================================================================
        // NORMAL OPERATION (presetn = 1)
        //====================================================================
        else begin
            
            //----------------------------------------------------------------
            // DEFAULT OUTPUT ASSIGNMENTS
            //----------------------------------------------------------------
            // Every clock cycle, we assign default values to PREADY and
            // PSLVERR. This is CRITICAL for APB protocol compliance:
            //
            //   - PREADY must only be asserted during ENABLE phase
            //   - PREADY must be deasserted when slave is not selected
            //   - PSLVERR must only be asserted for valid error conditions
            //
            // Without these defaults, stale values from previous cycles
            // could cause protocol violations and simulation mismatches.
            //----------------------------------------------------------------
            pready  <= 1'b0;        // Default: not ready
            pslverr <= 1'b0;        // Default: no error
            
            // Note: prdata default is handled in the conditional logic below
            // to avoid unnecessary toggling

            //----------------------------------------------------------------
            // APB SLAVE RESPONSE LOGIC
            //----------------------------------------------------------------
            // The slave responds to a transaction only when:
            //   1. PSEL = 1 (slave is selected by master)
            //   2. PENABLE = 1 (ENABLE phase is active)
            //
            // This is the APB protocol requirement - the slave must not
            // respond during SETUP phase (PENABLE=0).
            //----------------------------------------------------------------
            if (psel && penable) begin
                
                //============================================================
                // INVALID ADDRESS DETECTION
                //============================================================
                // Design Rule: Addresses 0x80-0xFF are considered invalid.
                //
                // For invalid addresses, the slave:
                //   1. Asserts PREADY to complete the transfer (required by APB)
                //   2. Asserts PSLVERR to signal the error
                //   3. Returns 0x00 for read data (safe default)
                //
                // This demonstrates error handling capability, which is
                // essential for robust system design.
                //============================================================
                if (paddr[7] == 1'b1) begin
                    
                    //--------------------------------------------------------
                    // Invalid Address Handling (0x80 - 0xFF)
                    //--------------------------------------------------------
                    pready  <= 1'b1;    // Complete the transfer
                    pslverr <= 1'b1;    // Signal error to master
                    prdata  <= 8'h00;   // Return 0 for read (safe value)
                end
                
                //============================================================
                // VALID ADDRESS ACCESS
                //============================================================
                // Address range: 0x00 - 0x7F
                //
                // For valid addresses, the slave:
                //   1. Asserts PREADY to complete the transfer
                //   2. Deasserts PSLVERR (no error)
                //   3. Performs read or write based on PWRITE signal
                //============================================================
                else begin
                    
                    //--------------------------------------------------------
                    // Assert Ready and Clear Error
                    //--------------------------------------------------------
                    pready  <= 1'b1;    // Transfer can complete
                    pslverr <= 1'b0;    // No error

                    //--------------------------------------------------------
                    // OPERATION TYPE DECODING
                    //--------------------------------------------------------
                    if (pwrite) begin
                        
                        //====================================================
                        // WRITE OPERATION
                        //====================================================
                        // PWRITE = 1 indicates a write transaction.
                        //
                        // The slave stores the write data (pwdata) into
                        // memory at the address specified by paddr.
                        //
                        // Timing:
                        //   - Memory update occurs on PCLK rising edge
                        //   - Data is available for subsequent reads
                        //
                        // Note:
                        //   - prdata is set to 0x00 during writes as per
                        //     APB convention (read data is not meaningful)
                        //====================================================
                        memory[paddr] <= pwdata;  // Store write data
                        prdata <= 8'h00;          // No read data on write
                    end
                    else begin
                        
                        //====================================================
                        // READ OPERATION
                        //====================================================
                        // PWRITE = 0 indicates a read transaction.
                        //
                        // The slave retrieves data from memory at the
                        // address specified by paddr and drives it onto
                        // the prdata bus.
                        //
                        // Timing:
                        //   - Read data is driven in the same cycle as
                        //     PREADY assertion (APB requirement)
                        //   - Master captures data on PCLK rising edge
                        //====================================================
                        prdata <= memory[paddr];  // Drive read data
                    end
                end
            end
            
            //----------------------------------------------------------------
            // NOT SELECTED OR NOT IN ENABLE PHASE
            //----------------------------------------------------------------
            // When the slave is not selected (PSEL=0) or not in ENABLE
            // phase (PENABLE=0):
            //
            //   - PREADY remains deasserted (default)
            //   - PSLVERR remains deasserted (default)
            //   - PRDATA is driven to 0x00 when not selected
            //
            // Note: The 'else' branch here is implicit - the defaults
            // assigned at the top of this block handle these cases.
            //----------------------------------------------------------------
            else begin
                // Drive prdata to 0 when not selected (clean bus)
                if (!psel)
                    prdata <= 8'h00;
                // Otherwise, keep previous value (no unnecessary toggling)
            end
        end
    end

    //========================================================================
    // SIMULATION-ONLY MEMORY INITIALIZATION
    //========================================================================
    // This optional block provides additional memory initialization for
    // simulation purposes. It is only compiled when SIMULATION is defined.
    //
    // Purpose:
    //   - Provides a secondary initialization path for simulation
    //   - Useful for pre-loading test data in some verification flows
    //   - Does NOT synthesize (initial blocks are ignored by synthesis)
    //
    // Usage:
    //   - Compile with: +define+SIMULATION
    //   - Or add `define SIMULATION at the top of the file
    //
    // Note: The reset logic above already handles initialization for
    // most simulation scenarios. This block is provided as an additional
    // safety measure for specific verification environments.
    //========================================================================
    
    `ifdef SIMULATION
    initial begin
        //--------------------------------------------------------------------
        // Initialize all memory locations to 0x00
        //--------------------------------------------------------------------
        for (idx = 0; idx < 256; idx = idx + 1)
            memory[idx] = 8'h00;
        
        //--------------------------------------------------------------------
        // Display confirmation message
        //--------------------------------------------------------------------
        $display("[%0t] APB Slave memory initialized", $time);
    end
    `endif

endmodule 
