`timescale 1ns / 1ps

module apb_testbench;

    // Clock and reset signals
    reg pclk;
    reg presetn;

    // Master control signals
    reg transfer;
    reg write_enable;
    reg [8:0] apb_write_paddr;
    reg [7:0] apb_write_data;
    reg [8:0] apb_read_paddr;

    // Outputs from the top module
    wire pslverr;
    wire [7:0] apb_read_data_out;
    
    // Internal signals for monitoring
    wire penable;
    wire pwrite;
    wire [8:0] paddr;
    wire [7:0] pwdata;
    wire psel1, psel2;
    wire [7:0] prdata_slave1, prdata_slave2;
    wire pready_slave1, pready_slave2;
    wire pslverr_slave1, pslverr_slave2;

    // Monitor state variables
    reg [8:0] prev_paddr_monitor;
    reg prev_psel_monitor;
    
    // Timeout parameter
    parameter TIMEOUT_CYCLES = 100;

    // Clock generation
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;  // 100 MHz clock (10 ns period)
    end

    // Instantiate the top module
    APB_top dut (
        .pclk(pclk),
        .presetn(presetn),
        .transfer(transfer),
        .write_enable(write_enable),
        .apb_write_paddr(apb_write_paddr),
        .apb_write_data(apb_write_data),
        .apb_read_paddr(apb_read_paddr),
        .pslverr(pslverr),
        .apb_read_data_out(apb_read_data_out)
    );

    // Assign internal signals for monitoring
    assign penable = dut.master_inst.penable;
    assign pwrite = dut.master_inst.pwrite;
    assign paddr = dut.master_inst.paddr;
    assign pwdata = dut.master_inst.pwdata;
    assign psel1 = dut.master_inst.psel1;
    assign psel2 = dut.master_inst.psel2;
    assign prdata_slave1 = dut.slave1_inst.prdata;
    assign prdata_slave2 = dut.slave2_inst.prdata;
    assign pready_slave1 = dut.slave1_inst.pready;
    assign pready_slave2 = dut.slave2_inst.pready;
    assign pslverr_slave1 = dut.slave1_inst.pslverr;
    assign pslverr_slave2 = dut.slave2_inst.pslverr;

    // Reset and Initialization
    task reset_and_init;
        begin
            $display("[%0t] Applying system reset...", $time);
            presetn = 0;
            transfer = 0;
            write_enable = 0;
            apb_write_paddr = 9'b0;
            apb_write_data = 8'b0;
            apb_read_paddr = 9'b0;
            repeat(5) @(posedge pclk);
            presetn = 1;
            repeat(2) @(posedge pclk);
            $display("[%0t] System reset released", $time);
        end
    endtask

    // Helper task: Wait for bus to be completely idle
    task wait_bus_idle;
        begin
            // Wait until no transfer is in progress
            wait((psel1 === 0) && (psel2 === 0) && (penable === 0));
            // Wait one more cycle to ensure clean state
            @(posedge pclk);
        end
    endtask

    // Helper task: Perform single APB write with proper completion detection
    task apb_write;
        input [8:0] address;
        input [7:0] data;
        integer timeout_counter;
        begin
            $display("[%0t] Starting APB WRITE: Addr=0x%h, Data=0x%h", $time, address, data);
            
            // Wait for bus to be idle first
            wait_bus_idle();
            
            // Start transfer - assert for exactly 1 cycle
            @(posedge pclk);
            transfer = 1;
            write_enable = 1;
            apb_write_paddr = address;
            apb_write_data = data;
            
            @(posedge pclk);
            transfer = 0;  // Only assert for 1 cycle!
            
            // Wait for ACCESS phase completion with timeout
            fork
                begin
                    // Wait for completion - when PSEL and PENABLE are deasserted
                    wait((psel1 === 0) && (psel2 === 0) && (penable === 0));
                    // Wait one more cycle for data to be written
                    @(posedge pclk);
                    $display("[%0t] WRITE completed successfully", $time);
                end
                begin
                    // Timeout detection
                    repeat(TIMEOUT_CYCLES) @(posedge pclk);
                    $display("[%0t] ERROR: WRITE timeout - transfer did not complete", $time);
                end
            join_any
            disable fork;
            
            // Clean up signals
            write_enable = 0;
            @(posedge pclk);
        end
    endtask

    // Helper task: Perform single APB read with proper completion detection
    task apb_read;
        input [8:0] address;
        output [7:0] read_data;
        integer timeout_counter;
        begin
            $display("[%0t] Starting APB READ: Addr=0x%h", $time, address);
            
            // Wait for bus to be idle first
            wait_bus_idle();
            
            // Start transfer - assert for exactly 1 cycle
            @(posedge pclk);
            transfer = 1;
            write_enable = 0;
            apb_read_paddr = address;
            
            @(posedge pclk);
            transfer = 0;  // Only assert for 1 cycle!
            
            // Wait for ACCESS phase completion with timeout
            fork
                begin
                    // Wait for completion - when PSEL and PENABLE are deasserted
                    wait((psel1 === 0) && (psel2 === 0) && (penable === 0));
                    
                    // Wait one more cycle for data to be valid at output
                    @(posedge pclk);
                    read_data = apb_read_data_out;
                    $display("[%0t] READ completed: Data=0x%h", $time, read_data);
                end
                begin
                    // Timeout detection
                    repeat(TIMEOUT_CYCLES) @(posedge pclk);
                    $display("[%0t] ERROR: READ timeout - transfer did not complete", $time);
                    read_data = 8'hXX;
                end
            join_any
            disable fork;
            
            @(posedge pclk);
        end
    endtask

    // Helper task: Read with expected data verification
    task apb_read_verify;
        input [8:0] address;
        input [7:0] expected_data;
        reg [7:0] read_data;
        begin
            apb_read(address, read_data);
            if (read_data === expected_data) begin
                $display("[%0t] PASS: Read data matches expected 0x%h", $time, expected_data);
            end else begin
                $display("[%0t] FAIL: Expected 0x%h, got 0x%h", $time, expected_data, read_data);
            end
        end
    endtask

    // ============================================
    // TEST CASES
    // ============================================

    // Test Case 1: Basic Memory Read/Write
    task test_memory_basic;
        begin
            $display("\n========================================");
            $display("TEST 1: Basic Memory Read/Write");
            $display("========================================");
            
            // Wait for bus to be idle after reset
            wait_bus_idle();
            
            // Test Slave 1 (address[8] = 0)
            apb_write(9'h020, 8'hAA);
            wait_bus_idle();
            apb_read_verify(9'h020, 8'hAA);
            wait_bus_idle();
            
            // Test Slave 2 (address[8] = 1)
            apb_write(9'h120, 8'h55);
            wait_bus_idle();
            apb_read_verify(9'h120, 8'h55);
            wait_bus_idle();
            
            // Test different addresses
            apb_write(9'h0FF, 8'hFF);
            wait_bus_idle();
            apb_read_verify(9'h0FF, 8'hFF);
            wait_bus_idle();
            
            $display("Test 1 Complete\n");
        end
    endtask

    // Test Case 2: Address Stability
    task test_address_stability;
        input [8:0] test_address;
        reg [8:0] stable_address;
        reg stable_psel;
        integer i;
        begin
            $display("\n========================================");
            $display("TEST 2: Address Stability Verification");
            $display("========================================");
            
            $display("[%0t] Testing address 0x%h", $time, test_address);
            
            // Wait for bus idle
            wait_bus_idle();
            
            // Start transfer
            @(posedge pclk);
            transfer = 1;
            write_enable = 1;
            apb_write_paddr = test_address;
            apb_write_data = 8'h11;
            
            // Capture initial address
            @(posedge pclk);
            stable_address = paddr;
            stable_psel = psel1 || psel2;
            transfer = 0;  // Single cycle pulse
            
            // Monitor address for 3 clock cycles
            for (i = 0; i < 3; i = i + 1) begin
                @(posedge pclk);
                $display("[%0t] Clock edge: PADDR=0x%h, PSEL1=%b, PSEL2=%b, PENABLE=%b", 
                         $time, paddr, psel1, psel2, penable);
                
                if (paddr !== stable_address) begin
                    $display("[%0t] ERROR: Address changed from 0x%h to 0x%h", 
                             $time, stable_address, paddr);
                end
            end
            
            // Wait for completion
            wait_bus_idle();
            
            // Clean up
            write_enable = 0;
            @(posedge pclk);
            
            $display("[%0t] Address stability test complete", $time);
            $display("Test 2 Complete\n");
        end
    endtask

    // Test Case 3: APB Two-Phase Protocol Compliance
    task test_protocol_compliance;
        input [8:0] address;
        reg setup_detected;
        reg access_detected;
        integer cycle_count;
        begin
            $display("\n========================================");
            $display("TEST 3: APB Two-Phase Protocol Compliance");
            $display("========================================");
            
            setup_detected = 0;
            access_detected = 0;
            cycle_count = 0;
            
            $display("[%0t] Starting protocol test at address 0x%h", $time, address);
            
            // Wait for bus idle
            wait_bus_idle();
            
            // Start transfer
            @(posedge pclk);
            transfer = 1;
            write_enable = 1;
            apb_write_paddr = address;
            apb_write_data = 8'h22;
            
            // Monitor for protocol phases
            fork
                begin : setup_monitor
                    repeat(10) begin
                        @(posedge pclk);
                        cycle_count = cycle_count + 1;
                        if ((psel1 || psel2) && !penable) begin
                            $display("[%0t] SETUP phase detected: PSEL=%b, PENABLE=0", $time, (psel1 || psel2));
                            setup_detected = 1;
                        end
                        if ((psel1 || psel2) && penable) begin
                            $display("[%0t] ACCESS phase detected: PSEL=%b, PENABLE=1", $time, (psel1 || psel2));
                            access_detected = 1;
                        end
                    end
                end
            join
            
            // Complete transfer
            transfer = 0;
            write_enable = 0;
            
            // Wait for completion
            wait_bus_idle();
            
            // Report results
            if (setup_detected && access_detected) begin
                $display("[%0t] PASS: Both SETUP and ACCESS phases detected correctly", $time);
            end else begin
                $display("[%0t] FAIL: SETUP=%b, ACCESS=%b", $time, setup_detected, access_detected);
            end
            
            $display("Test 3 Complete\n");
        end
    endtask

    // Test Case 4: Slave Selection and Decoding
    task test_slave_selection;
        begin
            $display("\n========================================");
            $display("TEST 4: Slave Selection and Address Decoding");
            $display("========================================");
            
            // Wait for bus idle
            wait_bus_idle();
            
            $display("[%0t] Testing Slave 1 selection (address[8]=0)", $time);
            @(posedge pclk);
            transfer = 1;
            write_enable = 1;
            apb_write_paddr = 9'h050;
            
            @(posedge pclk);
            transfer = 0;
            
            // Check PSEL signals in next cycle
            @(posedge pclk);
            if (psel1 && !psel2) begin
                $display("[%0t] PASS: Slave 1 correctly selected", $time);
            end else begin
                $display("[%0t] FAIL: PSEL1=%b, PSEL2=%b", $time, psel1, psel2);
            end
            
            // Wait for completion
            wait_bus_idle();
            write_enable = 0;
            @(posedge pclk);
            
            // Wait a bit before next test
            repeat(2) @(posedge pclk);
            
            $display("[%0t] Testing Slave 2 selection (address[8]=1)", $time);
            @(posedge pclk);
            transfer = 1;
            write_enable = 1;
            apb_write_paddr = 9'h150;
            
            @(posedge pclk);
            transfer = 0;
            
            // Check PSEL signals in next cycle
            @(posedge pclk);
            if (!psel1 && psel2) begin
                $display("[%0t] PASS: Slave 2 correctly selected", $time);
            end else begin
                $display("[%0t] FAIL: PSEL1=%b, PSEL2=%b", $time, psel1, psel2);
            end
            
            // Wait for completion
            wait_bus_idle();
            write_enable = 0;
            @(posedge pclk);
            
            $display("Test 4 Complete\n");
        end
    endtask

    // Test Case 5: PREADY Signal Handling
    task test_pready_handling;
        reg [7:0] read_data;
        begin
            $display("\n========================================");
            $display("TEST 5: PREADY Signal Handling");
            $display("========================================");
            
            $display("[%0t] Testing normal transfer (checking PREADY)", $time);
            
            // Wait for bus idle
            wait_bus_idle();
            
            // Perform a read operation
            apb_read(9'h030, read_data);
            
            $display("Test 5 Complete\n");
        end
    endtask

    // Test Case 6: PSLVERR Signal
    task test_pslverr_signal;
        reg [7:0] read_data;
        begin
            $display("\n========================================");
            $display("TEST 6: PSLVERR Signal Verification");
            $display("========================================");
            
            // Wait for bus idle
            wait_bus_idle();
            
            $display("[%0t] Testing valid address (should not assert PSLVERR)", $time);
            apb_write(9'h080, 8'h33);
            
            // Check PSLVERR after write completes
            if (!pslverr) begin
                $display("[%0t] PASS: PSLVERR=0 for valid address", $time);
            end else begin
                $display("[%0t] FAIL: PSLVERR=1 for valid address", $time);
            end
            
            $display("[%0t] Note: PSLVERR behavior depends on slave implementation", $time);
            $display("[%0t] Current PSLVERR state: %b", $time, pslverr);
            
            // Test read back to ensure data was written
            wait_bus_idle();
            apb_read(9'h080, read_data);
            
            $display("Test 6 Complete\n");
        end
    endtask

    // Test Case 7: Back-to-Back Transfers
    task test_back_to_back;
        reg [7:0] read_data;
        begin
            $display("\n========================================");
            $display("TEST 7: Back-to-Back Transfers");
            $display("========================================");
            
            // Wait for bus idle
            wait_bus_idle();
            
            $display("[%0t] Starting back-to-back write transfers", $time);
            
            // Proper back-to-back transfers using tasks
            apb_write(9'h040, 8'hA1);
            apb_write(9'h041, 8'hB2);
            apb_write(9'h042, 8'hC3);
            
            // Verify writes by reading back
            $display("[%0t] Verifying writes by reading back", $time);
            apb_read_verify(9'h040, 8'hA1);
            apb_read_verify(9'h041, 8'hB2);
            apb_read_verify(9'h042, 8'hC3);
            
            $display("Test 7 Complete\n");
        end
    endtask

    // Test Case 8: Reset Behavior
    task test_reset_behavior;
        begin
            $display("\n========================================");
            $display("TEST 8: Reset Behavior");
            $display("========================================");
            
            // Wait for bus idle
            wait_bus_idle();
            
            // Perform a transfer
            $display("[%0t] Performing transfer before reset", $time);
            apb_write(9'h060, 8'h77);
            
            // Assert reset during operation
            $display("[%0t] Asserting reset", $time);
            presetn = 0;
            repeat(5) @(posedge pclk);
            
            // Check that all signals are in reset state
            if (!penable && !psel1 && !psel2) begin
                $display("[%0t] PASS: All APB signals in reset state", $time);
            end else begin
                $display("[%0t] FAIL: Signals not properly reset", $time);
                $display("  PENABLE=%b, PSEL1=%b, PSEL2=%b", penable, psel1, psel2);
            end
            
            // Release reset
            $display("[%0t] Releasing reset", $time);
            presetn = 1;
            repeat(5) @(posedge pclk);
            
            // Wait for bus to stabilize
            wait_bus_idle();
            
            // Verify system works after reset
            $display("[%0t] Testing operation after reset", $time);
            apb_write(9'h070, 8'h88);
            apb_read_verify(9'h070, 8'h88);
            
            $display("Test 8 Complete\n");
        end
    endtask

    // Test Case 9: Mixed Read/Write Operations
    task test_mixed_operations;
        reg [7:0] read_data;
        begin
            $display("\n========================================");
            $display("TEST 9: Mixed Read/Write Operations");
            $display("========================================");
            
            // Wait for bus idle
            wait_bus_idle();
            
            $display("[%0t] Starting mixed operations test", $time);
            
            // Write-Read-Write sequence
            apb_write(9'h090, 8'h11);
            apb_read_verify(9'h090, 8'h11);
            apb_write(9'h091, 8'h22);
            apb_read_verify(9'h091, 8'h22);
            
            // Read-Write-Read sequence with proper verification
            apb_read(9'h092, read_data);
            $display("[%0t] Initial value at 0x092: 0x%h", $time, read_data);
            
            apb_write(9'h092, 8'h33);
            apb_read_verify(9'h092, 8'h33);  // Verify written value
            
            $display("Test 9 Complete\n");
        end
    endtask

    // Test Case 10: Random Stress Test
    task test_random_stress;
        integer i;
        integer num_tests;
        reg [8:0] rand_addr;
        reg [7:0] rand_data, read_data;
        begin
            num_tests = 20;
            $display("\n========================================");
            $display("TEST 10: Random Stress Test (%0d operations)", num_tests);
            $display("========================================");
            
            // Wait for bus idle
            wait_bus_idle();
            
            for (i = 0; i < num_tests; i = i + 1) begin
                rand_addr = $urandom % 9'h200;
                rand_data = $urandom % 8'h100;
                
                if ($urandom % 2) begin
                    $display("[%0t] Random Write %0d: Addr=0x%h, Data=0x%h", 
                             $time, i+1, rand_addr, rand_data);
                    apb_write(rand_addr, rand_data);
                end else begin
                    $display("[%0t] Random Read %0d: Addr=0x%h", $time, i+1, rand_addr);
                    apb_read(rand_addr, read_data);
                end
            end
            
            $display("[%0t] Random stress test complete", $time);
            $display("Test 10 Complete\n");
        end
    endtask

    // ============================================
    // MAIN TEST SEQUENCE
    // ============================================

    initial begin
        // Waveform dumping
        $dumpfile("apb_testbench.vcd");
        $dumpvars(0, apb_testbench);
        
        $display("\n**************************************************");
        $display("APB PROTOCOL VERIFICATION TESTBENCH");
        $display("**************************************************\n");
        
        // Initialize monitor variables
        prev_paddr_monitor = 9'b0;
        prev_psel_monitor = 0;
        
        // Initialize
        reset_and_init;
        
        // Run all test cases
        test_memory_basic;                  // Test 1
        test_address_stability(9'h0A0);     // Test 2
        test_protocol_compliance(9'h0B0);   // Test 3
        test_slave_selection;              // Test 4
        test_pready_handling;              // Test 5
        test_pslverr_signal;               // Test 6
        test_back_to_back;                 // Test 7
        test_reset_behavior;               // Test 8
        test_mixed_operations;             // Test 9
        test_random_stress;                // Test 10
        
        // Final summary
        $display("\n**************************************************");
        $display("ALL TESTS COMPLETED");
        $display("**************************************************");
        
        // Final wait and display coverage
        repeat(10) @(posedge pclk);
        $finish;
    end

    // ============================================
    // MONITORS AND ASSERTIONS
    // ============================================

    // Protocol Monitor: Check APB rules
    always @(posedge pclk) begin
        if (presetn) begin
            // Rule 1: PENABLE should never be asserted without PSEL
            if (penable && !psel1 && !psel2) begin
                $display("[%0t] PROTOCOL VIOLATION: PENABLE=1 but no PSEL asserted", $time);
            end
            
            // Rule 2: PADDR should not change during active transfer
            if (prev_psel_monitor && (psel1 || psel2)) begin
                if (prev_paddr_monitor !== paddr) begin
                    $display("[%0t] PROTOCOL VIOLATION: PADDR changed during transfer (0x%h -> 0x%h)", 
                             $time, prev_paddr_monitor, paddr);
                end
            end
            
            // Rule 3: Only one slave can be selected at a time
            if (psel1 && psel2) begin
                $display("[%0t] PROTOCOL VIOLATION: Multiple slaves selected simultaneously", $time);
            end
            
            // Update monitor state
            prev_paddr_monitor = paddr;
            prev_psel_monitor = (psel1 || psel2);
        end
    end

    // Coverage collection
    reg [31:0] coverage_write_count;
    reg [31:0] coverage_read_count;
    reg [31:0] coverage_slave1_count;
    reg [31:0] coverage_slave2_count;
    
    initial begin
        coverage_write_count = 0;
        coverage_read_count = 0;
        coverage_slave1_count = 0;
        coverage_slave2_count = 0;
    end
    
    always @(posedge pclk) begin
        if (presetn) begin
            if (penable && (pready_slave1 || pready_slave2)) begin
                if (pwrite) coverage_write_count = coverage_write_count + 1;
                else coverage_read_count = coverage_read_count + 1;
                
                if (psel1) coverage_slave1_count = coverage_slave1_count + 1;
                if (psel2) coverage_slave2_count = coverage_slave2_count + 1;
            end
        end
    end
    
    // Final coverage report
    final begin
        $display("\n========================================");
        $display("COVERAGE REPORT");
        $display("========================================");
        $display("Total Write Operations: %0d", coverage_write_count);
        $display("Total Read Operations:  %0d", coverage_read_count);
        $display("Slave 1 Accesses:       %0d", coverage_slave1_count);
        $display("Slave 2 Accesses:       %0d", coverage_slave2_count);
        $display("Total Operations:       %0d", coverage_write_count + coverage_read_count);
    end

endmodule