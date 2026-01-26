

`timescale 1ns / 1ps

//============================================================
// TESTBENCH
// Verifies APB master–slave system by driving valid/invalid
// transactions and observing true APB handshake behavior
//============================================================
module testbench;

    // ------------------------------------------------------------
    // Clock and reset
    // ------------------------------------------------------------
    reg pclk;            // APB clock
    reg presetn;         // Active-low reset

    // ------------------------------------------------------------
    // Master control signals
    // Driven by testbench to initiate APB transactions
    // ------------------------------------------------------------
    reg transfer;        // Transfer request
    reg read;            // Read control
    reg write;           // Write control
    reg [7:0] apb_write_paddr; // Write address
    reg [7:0] apb_write_data;  // Write data
    reg [7:0] apb_read_paddr;  // Read address

    // ------------------------------------------------------------
    // Outputs from DUT (Device Under Test)
    // ------------------------------------------------------------
    wire        pslverr;          // Aggregated slave error
    wire [7:0]  apb_read_data_out;// Read data returned to master

    // ------------------------------------------------------------
    // Internal signal taps (observation only)
    // Used for debugging and transaction analysis
    // ------------------------------------------------------------
    wire        penable;
    wire        pwrite;
    wire        psel1, psel2;
    wire [7:0]  paddr;
    wire [7:0]  pwdata;
    wire        pready;
    wire [7:0]  prdata_mux;

    // ------------------------------------------------------------
    // Snapshot registers
    // Capture APB signals at the exact completion of a transfer
    // ------------------------------------------------------------
    reg        snap_pwrite;
    reg [7:0]  snap_addr;
    reg [7:0]  snap_wdata;
    reg        snap_psel1, snap_psel2;
    reg        snap_pslverr;

    // ------------------------------------------------------------
    // Clock generation
    // Generates a 100 MHz APB clock
    // ------------------------------------------------------------
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;
    end

    // ------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------
    APB_top dut (
        .pclk(pclk),
        .presetn(presetn),
        .transfer(transfer),
        .read(read),
        .write(write),
        .apb_write_paddr(apb_write_paddr),
        .apb_write_data(apb_write_data),
        .apb_read_paddr(apb_read_paddr),
        .pslverr(pslverr),
        .apb_read_data_out(apb_read_data_out)
    );

    // ------------------------------------------------------------
    // Signal taps from DUT hierarchy
    // These are used only for monitoring, not driving logic
    // ------------------------------------------------------------
    assign penable    = dut.penable;
    assign pwrite     = dut.pwrite;
    assign paddr      = dut.paddr;
    assign pwdata     = dut.pwdata;
    assign psel1      = dut.psel1;
    assign psel2      = dut.psel2;
    assign pready     = dut.pready;
    assign prdata_mux = dut.prdata_mux;

    // ------------------------------------------------------------
    // Snapshot capture
    // Captures APB signals only when a transfer truly completes
    // (ENABLE phase + PREADY asserted)
    // ------------------------------------------------------------
    always @(posedge pclk) begin
        if (penable && pready) begin
            snap_pwrite  <= pwrite;
            snap_addr    <= paddr;
            snap_wdata   <= pwdata;
            snap_psel1   <= psel1;
            snap_psel2   <= psel2;
            snap_pslverr <= pslverr;
        end
    end

    // ------------------------------------------------------------
    // Display captured APB transaction
    // Provides a truthful summary of the completed transfer
    // ------------------------------------------------------------
    task display_apb_snapshot;
        begin
            $display("--------------------------------------------------");
            $display("APB TRANSACTION SUMMARY @ time %0t", $time);
            $display("  Operation : %s", snap_pwrite ? "WRITE" : "READ");
            $display("  Address   : 0x%02h", snap_addr);
            $display("  WriteData : 0x%02h", snap_wdata);
            $display("  PSEL1=%b  PSEL2=%b", snap_psel1, snap_psel2);
            $display("  PSLVERR   : %b", snap_pslverr);

            if (snap_pslverr)
                $display("  ⚠️ ERROR: Invalid or unmapped address access");
            else
                $display("  ✅ VALID ACCESS");

            $display("--------------------------------------------------");
        end
    endtask

    // ------------------------------------------------------------
    // Transfer wait task
    // Waits for ENABLE and PREADY with timeout protection
    // Ensures protocol-correct completion detection
    // ------------------------------------------------------------
    task wait_for_transfer_completion;
        integer timeout;
        begin
            $display("\n>>> APB TRANSFER STARTED");
            timeout = 0;

            // Wait for ENABLE phase
            while (!penable && timeout < 20) begin
                @(posedge pclk);
                timeout = timeout + 1;
            end

            if (timeout == 20) begin
                $display("❌ ERROR: Timeout waiting for ENABLE");
                $finish;
            end

            // Wait for PREADY from slave
            timeout = 0;
            while (!pready && timeout < 20) begin
                @(posedge pclk);
                timeout = timeout + 1;
            end

            if (timeout == 20) begin
                $display("❌ ERROR: Timeout waiting for PREADY");
                $finish;
            end

            // Allow snapshot capture
            @(posedge pclk);
            #1;

            // Extra cycle for read data visibility
            if (read && !write) begin
                @(posedge pclk);
                #1;
            end

            display_apb_snapshot();
            $display(">>> APB TRANSFER COMPLETED\n");
        end
    endtask

    // ------------------------------------------------------------
    // Test sequence
    // Exercises valid write, valid read, and invalid access cases
    // ------------------------------------------------------------
    initial begin
        $display("\n==========================================");
        $display("=== APB WRITE / READ WITH ERROR REPORT ===");
        $display("==========================================");

        // Apply reset
        presetn = 0;
        transfer = 0;
        read = 0;
        write = 0;
        apb_write_paddr = 0;
        apb_write_data  = 0;
        apb_read_paddr  = 0;

        #20 presetn = 1;
        #20;

        // --------------------------------------------------------
        // TEST 1: Write to a valid address
        // --------------------------------------------------------
        $display("\n### TEST 1: WRITE to VALID address 0x25 ###");
        transfer = 1;
        write = 1;
        read = 0;
        apb_write_paddr = 8'h25;
        apb_write_data  = 8'hAB;

        @(posedge pclk);
        wait_for_transfer_completion();

        transfer = 0;
        write = 0;
        #20;

        // --------------------------------------------------------
        // TEST 2: Read from a valid address
        // --------------------------------------------------------
        $display("\n### TEST 2: READ from VALID address 0x25 ###");
        transfer = 1;
        read = 1;
        write = 0;
        apb_read_paddr = 8'h25;

        @(posedge pclk);
        wait_for_transfer_completion();

        transfer = 0;
        read = 0;
        #20;

        // --------------------------------------------------------
        // TEST 3: Write to an invalid address
        // --------------------------------------------------------
        $display("\n### TEST 3: WRITE to INVALID address 0x80 ###");
        transfer = 1;
        write = 1;
        read = 0;
        apb_write_paddr = 8'h80;
        apb_write_data  = 8'h55;

        @(posedge pclk);
        wait_for_transfer_completion();

        transfer = 0;
        write = 0;

        $display("\n==========================================");
        $display("=== TEST COMPLETE ===");
        $display("==========================================");

        #50;
        $finish;
    end

    // ------------------------------------------------------------
    // Waveform dump for post-simulation analysis
    // ------------------------------------------------------------
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, testbench);
    end

endmodule
   
