module APB_slave #(
    parameter SLAVE_ID = 0  // 0 for Slave 1, 1 for Slave 2
)(
    input wire pclk,
    input wire presetn,
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [8:0] paddr,
    input wire [7:0] pwdata,
    output reg [7:0] prdata,
    output reg pready,
    output reg pslverr
);

    // Internal memory (256 locations per slave)
    reg [7:0] memory [0:255];
    
    // Memory address (lower 8 bits)
    wire [7:0] mem_addr = paddr[7:0];
    
    // Initialize memory with zeros - EACH SLAVE GETS ITS OWN MEMORY
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 8'h00;
        end
        $display("Slave %0d memory initialized", SLAVE_ID);
    end
    
    // Control signals and memory operations
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 1'b0;
            pslverr <= 1'b0;
            prdata <= 8'b0;
        end else begin
            // Default values
            pready <= 1'b0;
            pslverr <= 1'b0;
            
            // When slave is selected and in ACCESS phase
            if (psel && penable) begin
                pready <= 1'b1;
                
                // Check for address error
                if (mem_addr > 8'd255) begin
                    pslverr <= 1'b1;
                end
                
                if (pwrite) begin
                    // WRITE operation - store data
                    memory[mem_addr] <= pwdata;
                    $display("[%0t] Slave %0d WRITE: Addr=0x%h, Data=0x%h", 
                             $time, SLAVE_ID, mem_addr, pwdata);
                end else begin
                    // READ operation - output data
                    prdata <= memory[mem_addr];
                    $display("[%0t] Slave %0d READ: Addr=0x%h, Data=0x%h", 
                             $time, SLAVE_ID, mem_addr, memory[mem_addr]);
                end
            end else if (psel && !penable) begin
                // SETUP phase - prepare for read if needed
                if (!pwrite) begin
                    prdata <= memory[mem_addr];
                end
            end else begin
                prdata <= 8'b0;
            end
        end
    end
endmodule

module APB_slave1 (
    input wire pclk,
    input wire presetn,
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [8:0] paddr,
    input wire [7:0] pwdata,
    output reg [7:0] prdata,
    output reg pready,
    output reg pslverr
);

    // Internal memory (256 locations for Slave 1)
    reg [7:0] memory1 [0:255];
    
    // Memory address (lower 8 bits)
    wire [7:0] mem_addr = paddr[7:0];
    
    // Initialize memory with zeros
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            memory1[i] = 8'h00;
        end
        $display("Slave 1 memory initialized");
    end
    
    // ... rest of Slave 1 code same as before ...
endmodule

module APB_slave2 (
    input wire pclk,
    input wire presetn,
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [8:0] paddr,
    input wire [7:0] pwdata,
    output reg [7:0] prdata,
    output reg pready,
    output reg pslverr
);

    // Internal memory (256 locations for Slave 2)
    reg [7:0] memory2 [0:255];
    
    // Memory address (lower 8 bits)
    wire [7:0] mem_addr = paddr[7:0];
    
    // Initialize memory with zeros
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            memory2[i] = 8'h00;
        end
        $display("Slave 2 memory initialized");
    end
    
    // ... rest of Slave 2 code same as before ...
endmodule
