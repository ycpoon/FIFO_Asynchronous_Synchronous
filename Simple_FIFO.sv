// Simple FIFO with parametrizable depth and width

`include "memDP.sv"

module FIFO #(
    parameter DEPTH = 16,
    parameter WIDTH = 32,
    parameter MAX_CNT = 3,
    localparam CNT_BITS = $clog2(MAX_CNT+1)
) (
    input                       clock, 
    input                       reset,
    input                       wr_en,
    input                       rd_en,
    input           [WIDTH-1:0] wr_data,
    output logic                wr_valid,
    output logic                rd_valid,
    output logic    [WIDTH-1:0] rd_data,
    output logic [CNT_BITS-1:0] spots,
    output logic                full,
    output logic                empty
);

    // Extra bit for partity calculation of datacount
    logic [$clog2(DEPTH):0] head, next_head;
    logic [$clog2(DEPTH):0] tail, next_tail;

    memDP #(
        .WIDTH     (WIDTH),
        .DEPTH     (DEPTH),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    fifo_mem (
        .clock(clock),
        .reset(reset),
        .re(rd_valid),
        .raddr(head[$clog2(DEPTH)-1:0]),
        .rdata(rd_data),
        .we(wr_valid),
        .waddr(tail[$clog2(DEPTH)-1:0]),
        .wdata(wr_data)

    );

    // assign empty = (head == tail);
    // assign full = (head == {~tail[$clog2(DEPTH)], tail[$clog2(DEPTH)-1:0]});
    logic [$clog2(DEPTH):0] datacount;
    assign full = (spots == 0);
    assign empty = (datacount == 0);


    always_comb begin
        if(tail[$clog2(DEPTH)-1:0] === head[$clog2(DEPTH)-1:0]) begin
            if(tail[$clog2(DEPTH)] === head[$clog2(DEPTH)]) begin
                datacount = 0;
            end else begin
                datacount = DEPTH;
            end
        end else begin
            if(tail[$clog2(DEPTH)-1:0] < head[$clog2(DEPTH)-1:0]) begin
                datacount = tail[$clog2(DEPTH)-1:0] + (DEPTH - head[$clog2(DEPTH)-1:0]);
            end else begin
                datacount = tail[$clog2(DEPTH)-1:0] - head[$clog2(DEPTH)-1:0];
            end
        end
    end

    assign spots = ((DEPTH - datacount) > MAX_CNT) ? MAX_CNT : (DEPTH - datacount);
    
    always_comb begin
        if(rd_en) begin
            if(empty)   rd_valid = 1'b0;
            else        rd_valid = 1'b1;
        end else begin
            rd_valid = 1'b0;
        end

        if(wr_en) begin
            if(full) begin
                if(rd_en)   wr_valid = 1'b1;
                else        wr_valid = 1'b0;
            end else begin
                wr_valid = 1'b1;
            end
        end else begin
            wr_valid = 1'b0;
        end

        if(rd_valid) begin
            if(head[$clog2(DEPTH)-1:0] == DEPTH - 1'b1) begin
                next_head[$clog2(DEPTH)] = ~head[$clog2(DEPTH)];
                next_head[$clog2(DEPTH)-1:0] = 0;
            end else begin
                next_head = head + 1'b1;
            end
        end else begin
            next_head = head;
        end


        if(wr_valid) begin
            if(tail[$clog2(DEPTH)-1:0] == DEPTH - 1'b1) begin
                next_tail[$clog2(DEPTH)] = ~tail[$clog2(DEPTH)];
                next_tail[$clog2(DEPTH)-1:0] = 0;
            end else begin
                next_tail = tail + 1'b1;
            end
        end else begin
            next_tail = tail;
        end

    end


    always_ff @(posedge clock) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
        end else begin
            head <= next_head;
            tail <= next_tail;
        end
    end

endmodule