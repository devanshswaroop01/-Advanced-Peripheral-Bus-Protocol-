module APB_master (
    input wire presetn,
    input wire pclk,
    input wire transfer,
    input wire write_enable,
    input wire [8:0] apb_write_paddr,
    input wire [7:0] apb_write_data,
    input wire [8:0] apb_read_paddr,
    input wire pready,
    input wire pslverr,
    input wire [7:0] prdata,
    output reg psel1,
    output reg psel2,
    output reg penable,
    output reg [8:0] paddr,
    output reg pwrite,
    output reg [7:0] pwdata,
    output reg [7:0] apb_read_data_out
);

    reg [1:0] state;
    reg transfer_seen;
    
    parameter S_IDLE = 2'b00;
    parameter S_SETUP = 2'b01;
    parameter S_ACCESS = 2'b10;
    
    // Main FSM
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state <= S_IDLE;
            psel1 <= 1'b0;
            psel2 <= 1'b0;
            penable <= 1'b0;
            paddr <= 9'b0;
            pwrite <= 1'b0;
            pwdata <= 8'b0;
            apb_read_data_out <= 8'b0;
            transfer_seen <= 1'b0;
        end else begin
            // Clear transfer_seen flag
            if (transfer_seen && state != S_IDLE) begin
                transfer_seen <= 1'b0;
            end
            
            case (state)
                S_IDLE: begin
                    if (transfer && !transfer_seen) begin
                        // Capture transfer parameters
                        transfer_seen <= 1'b1;
                        
                        // Setup phase
                        state <= S_SETUP;
                        paddr <= write_enable ? apb_write_paddr : apb_read_paddr;
                        pwrite <= write_enable;
                        pwdata <= apb_write_data;
                        
                        // Select slave based on address[8]
                        if (!paddr[8]) begin
                            psel1 <= 1'b1;
                            psel2 <= 1'b0;
                        end else begin
                            psel1 <= 1'b0;
                            psel2 <= 1'b1;
                        end
                    end else begin
                        psel1 <= 1'b0;
                        psel2 <= 1'b0;
                        penable <= 1'b0;
                    end
                end
                
                S_SETUP: begin
                    // Access phase
                    penable <= 1'b1;
                    state <= S_ACCESS;
                end
                
                S_ACCESS: begin
                    if (pready) begin
                        // Transfer complete
                        penable <= 1'b0;
                        psel1 <= 1'b0;
                        psel2 <= 1'b0;
                        
                        // Capture read data
                        if (!pwrite) begin
                            apb_read_data_out <= prdata;
                        end
                        
                        // Check if another transfer is requested
                        if (transfer && !transfer_seen) begin
                            transfer_seen <= 1'b1;
                            state <= S_SETUP;
                            paddr <= write_enable ? apb_write_paddr : apb_read_paddr;
                            pwrite <= write_enable;
                            pwdata <= apb_write_data;
                            
                            // Select slave based on address[8]
                            if (!paddr[8]) begin
                                psel1 <= 1'b1;
                                psel2 <= 1'b0;
                            end else begin
                                psel1 <= 1'b0;
                                psel2 <= 1'b1;
                            end
                        end else begin
                            state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end
endmodule