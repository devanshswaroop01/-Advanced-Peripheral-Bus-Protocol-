module APB_top (
    input wire pclk,
    input wire presetn,
    input wire transfer,
    input wire write_enable,
    input wire [8:0] apb_write_paddr,
    input wire [7:0] apb_write_data,
    input wire [8:0] apb_read_paddr,
    output wire pslverr,
    output wire [7:0] apb_read_data_out
);

    // APB interface signals
    wire penable;
    wire pwrite;
    wire [8:0] paddr;
    wire [7:0] pwdata;
    wire [7:0] prdata1, prdata2;
    wire pready1, pready2;
    wire psel1, psel2;
    wire pslverr1, pslverr2;
    
    // Internal ready signal
    wire pready;
    wire [7:0] prdata;
    
    // Master instance
    APB_master master_inst (
        .presetn(presetn),
        .pclk(pclk),
        .transfer(transfer),
        .write_enable(write_enable),
        .apb_write_paddr(apb_write_paddr),
        .apb_write_data(apb_write_data),
        .apb_read_paddr(apb_read_paddr),
        .pready(pready),
        .pslverr(pslverr),
        .prdata(prdata),
        .psel1(psel1),
        .psel2(psel2),
        .penable(penable),
        .paddr(paddr),
        .pwrite(pwrite),
        .pwdata(pwdata),
        .apb_read_data_out(apb_read_data_out)
    );
    
    // Slave 1 instance with parameter
    APB_slave #(.SLAVE_ID(1)) slave1_inst (
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
    
    // Slave 2 instance with parameter
    APB_slave #(.SLAVE_ID(2)) slave2_inst (
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
    
    // Combine ready and error signals
    assign pready = (psel1) ? pready1 : (psel2) ? pready2 : 1'b0;
    assign pslverr = (psel1) ? pslverr1 : (psel2) ? pslverr2 : 1'b0;
    assign prdata = (psel1) ? prdata1 : prdata2;
    
endmodule