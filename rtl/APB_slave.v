
`timescale 1ns / 1ps

//============================================================
// APB SLAVE
// Implements a simple APB-compliant slave with
// byte-addressable memory, error detection, and
// single-cycle response in ENABLE phase
//============================================================
module APB_slave (
    input  wire        pclk,        // APB clock
    input  wire        presetn,       // Active-low reset
    input  wire        psel,          // Slave select
    input  wire        penable,       // ENABLE phase indicator
    input  wire        pwrite,        // Write control (1=write, 0=read)
    input  wire [7:0]  paddr,         // Address bus
    input  wire [7:0]  pwdata,        // Write data bus
    output reg  [7:0]  prdata,        // Read data bus
    output reg         pready,        // Transfer completion signal
    output reg         pslverr        // Slave error indicator
);

    // ------------------------------------------------------------
    // Internal memory
    // 256-byte byte-addressable register array
    // ------------------------------------------------------------
    reg [7:0] memory [0:255];
    integer idx;

    // ------------------------------------------------------------
    // Sequential logic
    // All APB responses are synchronous to PCLK
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            // ----------------------------------------------------
            // Reset behavior
            // Initialize memory and outputs to known values
            // (Deterministic reset for simulation/education)
            // ----------------------------------------------------
            for (idx = 0; idx < 256; idx = idx + 1)
                memory[idx] <= 8'h00;

            pready  <= 1'b0;
            pslverr <= 1'b0;
            prdata  <= 8'h00;
        end
        else begin
            // ----------------------------------------------------
            // Default outputs each clock cycle
            // Prevents stale handshake or error signals
            // ----------------------------------------------------
            pready  <= 1'b0;
            pslverr <= 1'b0;

            // ----------------------------------------------------
            // APB slave responds only during ENABLE phase
            // and only when selected
            // ----------------------------------------------------
            if (psel && penable) begin

                // ------------------------------------------------
                // Invalid address check
                // Design rule: addresses 0x80–0xFF are invalid
                // ------------------------------------------------
                if (paddr[7] == 1'b1) begin
                    // Signal error but still complete transfer
                    // (APB requires PREADY to assert even on error)
                    pready  <= 1'b1;
                    pslverr <= 1'b1;
                end
                else begin
                    // --------------------------------------------
                    // Valid address access
                    // --------------------------------------------
                    pready <= 1'b1;

                    if (pwrite) begin
                        // Write operation:
                        // Store write data into memory
                        memory[paddr] <= pwdata;
                    end
                    else begin
                        // Read operation:
                        // Drive read data from memory
                        prdata <= memory[paddr];
                    end
                end
            end
        end
    end

endmodule

  
