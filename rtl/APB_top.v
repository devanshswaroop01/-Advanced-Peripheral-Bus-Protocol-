
`timescale 1ns / 1ps

//============================================================
// APB TOP
// Top-level integration of APB master and multiple slaves.
// Provides address decoding, response aggregation, and
// safety handling for unmapped or illegal accesses.
//============================================================
module APB_top (
    input  wire        pclk,                 // APB clock
    input  wire        presetn,                // Active-low reset

    // High-level request interface to APB master
    input  wire        transfer,               // Transfer request
    input  wire        read,                   // Read request
    input  wire        write,                  // Write request
    input  wire [7:0]  apb_write_paddr,        // Write address
    input  wire [7:0]  apb_write_data,         // Write data
    input  wire [7:0]  apb_read_paddr,         // Read address

    // Outputs back to user logic
    output wire        pslverr,                // Aggregated slave error
    output wire [7:0]  apb_read_data_out       // Read data from selected slave
);

    // ------------------------------------------------------------
    // Internal APB bus signals
    // Shared between master and slaves
    // ------------------------------------------------------------
    wire        penable;    // APB ENABLE phase signal
    wire        pwrite;     // Read/Write control
    wire [7:0]  paddr;      // Address bus
    wire [7:0]  pwdata;     // Write data bus

    // ------------------------------------------------------------
    // Per-slave response signals
    // ------------------------------------------------------------
    wire [7:0]  prdata1, prdata2;  // Read data from slaves
    wire        pready1, pready2;  // Ready signals from slaves
    wire        pslverr1, pslverr2;// Error signals from slaves

    // ------------------------------------------------------------
    // Slave select and aggregated signals
    // ------------------------------------------------------------
    wire        psel1, psel2;       // Slave select signals
    wire [7:0]  prdata_mux;         // Muxed read data
    wire        pready;              // Aggregated ready signal

    // ------------------------------------------------------------
    // APB Master Instance
    // Generates APB protocol signals and controls transactions
    // ------------------------------------------------------------
    APB_master master_inst (
        .presetn(presetn),
        .pclk(pclk),
        .transfer(transfer),
        .read(read),
        .write(write),
        .apb_write_paddr(apb_write_paddr),
        .apb_read_paddr(apb_read_paddr),
        .apb_write_data(apb_write_data),
        .pready(pready),                 // Aggregated ready from interconnect
        .pslverr(pslverr),               // Aggregated error from interconnect
        .prdata(prdata_mux),             // Selected slave read data
        .psel1(psel1),
        .psel2(psel2),
        .penable(penable),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .apb_read_data_out(apb_read_data_out)
    );

    // ------------------------------------------------------------
    // APB Slave 1
    // Handles address range 0x00 – 0x7F
    // ------------------------------------------------------------
    APB_slave slave1_inst (
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel1),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata1),
        .pready(pready1),
        .pslverr(pslverr1)
    );

    // ------------------------------------------------------------
    // APB Slave 2
    // Handles address range 0x80 – 0xFF
    // ------------------------------------------------------------
    APB_slave slave2_inst (
        .pclk(pclk),
        .presetn(presetn),
        .psel(psel2),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata2),
        .pready(pready2),
        .pslverr(pslverr2)
    );

    // ------------------------------------------------------------
    // Safety logic
    // Detects unmapped addresses and illegal multiple selection
    // ------------------------------------------------------------
    wire no_slave_sel  = ~psel1 & ~psel2;   // No slave selected
    wire multi_sel     =  psel1 &  psel2;   // More than one slave selected

    // ------------------------------------------------------------
    // PREADY aggregation
    // Ensures master always receives a response and
    // prevents deadlock on invalid decode conditions
    // ------------------------------------------------------------
    assign pready = (psel1 && pready1) ||
                    (psel2 && pready2) ||
                    no_slave_sel ||
                    multi_sel;

    // ------------------------------------------------------------
    // PSLVERR aggregation
    // Reports slave errors as well as decode-related faults
    // ------------------------------------------------------------
    assign pslverr = (psel1 && pslverr1) ||
                     (psel2 && pslverr2) ||
                     no_slave_sel ||
                     multi_sel;

    // ------------------------------------------------------------
    // Read data multiplexing
    // Selects read data from the active slave
    // ------------------------------------------------------------
    assign prdata_mux = psel1 ? prdata1 :
                        psel2 ? prdata2 :
                        8'h00;

endmodule
  
