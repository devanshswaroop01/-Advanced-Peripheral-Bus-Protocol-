`timescale 1ns / 1ps

//============================================================
// APB MASTER
// Implements a protocol-compliant APB master with
// IDLE–SETUP–ENABLE FSM, signal latching, and wait-state support
//============================================================
module APB_master (
    input  wire        presetn,              // Active-low reset
    input  wire        pclk,                  // APB clock

    // High-level request interface
    input  wire        transfer,              // Transfer request
    input  wire        read,                  // Read request
    input  wire        write,                 // Write request

    // Address/data inputs from user logic
    input  wire [7:0]  apb_write_paddr,       // Write address
    input  wire [7:0]  apb_write_data,        // Write data
    input  wire [7:0]  apb_read_paddr,        // Read address

    // APB slave response signals
    input  wire        pready,                // Transfer complete
    input  wire        pslverr,               // Slave error
    input  wire [7:0]  prdata,                // Read data from slave

    // APB bus outputs
    output reg         psel1,                 // Slave 1 select
    output reg         psel2,                 // Slave 2 select
    output reg         penable,               // ENABLE phase indicator
    output reg         pwrite,                // Read/Write control
    output reg [7:0]   paddr,                 // Address bus
    output reg [7:0]   pwdata,                // Write data bus

    // Latched read data for user logic
    output reg [7:0]   apb_read_data_out
);

    // ------------------------------------------------------------
    // APB FSM state encoding
    // IDLE   : No active transfer
    // SETUP  : Address/control phase (PSEL asserted, PENABLE low)
    // ENABLE : Data phase (PENABLE high, wait for PREADY)
    // ------------------------------------------------------------
    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ENABLE = 2'b10;

    reg [1:0] state, next_state;

    // ------------------------------------------------------------
    // Transfer edge detection
    // Ensures one APB transaction per request and
    // prevents retriggering during an active transfer
    // ------------------------------------------------------------
    reg transfer_d;
    wire transfer_pulse;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            transfer_d <= 1'b0;
        else
            transfer_d <= transfer;
    end

    // Rising-edge detect on transfer signal
    assign transfer_pulse = transfer & ~transfer_d;

    // ------------------------------------------------------------
    // Latched control signals
    // APB requires address, PWRITE, and PSEL to remain
    // stable from SETUP through ENABLE
    // ------------------------------------------------------------
    reg [7:0] latched_addr;
    reg [7:0] latched_wdata;
    reg       latched_write;
    reg       latched_psel1;
    reg       latched_psel2;

    // ------------------------------------------------------------
    // FSM state register
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------
    // FSM next-state logic
    // - IDLE   → SETUP   on new transfer request
    // - SETUP  → ENABLE  unconditionally
    // - ENABLE → IDLE or SETUP depending on PREADY and new request
    // ------------------------------------------------------------
    always @(*) begin
        case (state)
            IDLE:   next_state = transfer_pulse ? SETUP : IDLE;
            SETUP:  next_state = ENABLE;
            ENABLE: next_state = pready ? (transfer_pulse ? SETUP : IDLE)
                                        : ENABLE;
            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // Latch address and control signals during SETUP phase
    // This enforces APB timing rules by freezing signals
    // for the entire ENABLE phase
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            latched_addr   <= 8'h00;
            latched_wdata  <= 8'h00;
            latched_write  <= 1'b0;
            latched_psel1  <= 1'b0;
            latched_psel2  <= 1'b0;
        end
        else if (state == SETUP) begin
            // Read transaction
            if (read && !write) begin
                latched_addr  <= apb_read_paddr;
                latched_write <= 1'b0;
                latched_psel1 <= (apb_read_paddr[7] == 1'b0);
                latched_psel2 <= (apb_read_paddr[7] == 1'b1);
            end
            // Write transaction
            else if (write && !read) begin
                latched_addr  <= apb_write_paddr;
                latched_wdata <= apb_write_data;
                latched_write <= 1'b1;
                latched_psel1 <= (apb_write_paddr[7] == 1'b0);
                latched_psel2 <= (apb_write_paddr[7] == 1'b1);
            end
        end
    end

    // ------------------------------------------------------------
    // APB output logic
    // Outputs are driven only from latched values to
    // guarantee signal stability during ENABLE
    // ------------------------------------------------------------
    always @(*) begin
        // Default inactive values
        psel1   = 1'b0;
        psel2   = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = 8'h00;
        pwdata  = 8'h00;

        case (state)
            // SETUP phase: PSEL asserted, PENABLE low
            SETUP: begin
                psel1  = latched_psel1;
                psel2  = latched_psel2;
                pwrite = latched_write;
                paddr  = latched_addr;
                pwdata = latched_wdata;
            end

            // ENABLE phase: PENABLE asserted, wait for PREADY
            ENABLE: begin
                penable = 1'b1;
                psel1   = latched_psel1;
                psel2   = latched_psel2;
                pwrite  = latched_write;
                paddr   = latched_addr;
                pwdata  = latched_wdata;
            end
        endcase
    end

    // ------------------------------------------------------------
    // Read data capture
    // Data is sampled only when the read transfer
    // completes (ENABLE + PREADY)
    // ------------------------------------------------------------
    always @(posedge pclk or negedge presetn) begin
        if (!presetn)
            apb_read_data_out <= 8'h00;
        else if (state == ENABLE && penable && !pwrite && pready)
            apb_read_data_out <= prdata;
    end

endmodule
 
 
