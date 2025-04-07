module syn_fifo #(
  parameter W_WIDTH = 4,
  parameter R_WIDTH = 4,
  parameter WTOR_RATIO = 1,        // if R>W, init. as 1, option: 1,2,4,8,16,32
  parameter RTOW_RATIO = 1,        // if W>R, init. as 1, option: 1,2,4,8,16,32
  parameter DEPTH = 16,
  parameter AF = 3,               // AF becomes high when this amount of possible writes left 
  parameter AE = 3                // AE becomes high when this amount of possible reads left 
)(
  input syn_clk,
  input wr_en_i,
  input rd_en_i,
  input [W_WIDTH-1:0] wdata,
  input rst_i, //ACTIVE LOW
  
  output wr_ack_o,
  output rd_valid_o,
  
  output almost_full_o,
  output full_o,
  output empty_o,
  output almost_empty_o,
  output [R_WIDTH-1:0] rdata_o,
  output overflow_o,
  output underflow_o,
  output [$clog2(DEPTH):0] data_count_o,
  output [$clog2(DEPTH):0] writeable_count_o,
  output [$clog2(DEPTH):0] readable_count_o,
  
  //Test
  output [4:0] tempmem
);
  
  localparam L_WIDTH = (W_WIDTH > R_WIDTH) ? R_WIDTH : W_WIDTH;
  
  reg [L_WIDTH-1:0] mem [0:(DEPTH*2)-1];
  reg [$clog2(DEPTH):0] wptr;             // MSB for empty-full detection
  reg [$clog2(DEPTH):0] rptr;
  reg [R_WIDTH-1:0] rdata;
  reg wr_ack;
  reg rd_valid;
  reg overflow;
  reg underflow;
  reg [$clog2(DEPTH):0] wdata_count;        
  reg [$clog2(DEPTH):0] rdata_count;
  reg [$clog2(DEPTH):0] writeable_count;        
  reg [$clog2(DEPTH):0] readable_count;
  reg [$clog2(DEPTH):0] data_count;
  
  reg [W_WIDTH-1:0] wtemp;
  reg [L_WIDTH-1:0] temp_mem [0:WTOR_RATIO-1];
  reg [R_WIDTH-1:0] rtemp;
  reg nondivi;
  
  initial begin
    for (int i = 0; i < DEPTH; i = i + 1) begin
      mem[i] <= 0;
    end
    
    wptr <= 0;
    rptr <= 0;
    rdata <= 0;
    wr_ack <= 0;
    rd_valid <= 0;
    overflow <= 0;
    underflow <= 0;
    data_count <= 0;
    wdata_count <= 0;
    rdata_count <= 0;
    writeable_count <= 0;
    readable_count <= 0;
    nondivi <= 0;
  end
  
  // Clear Memory When Reset
  always @(negedge rst_i) begin
    if(~rst_i) begin
      for (int i = 0; i < DEPTH; i = i + 1) begin
        mem[i] <= 0;
      end
      
      for(int i = 0; i < WTOR_RATIO; i = i + 1) begin
        temp_mem[i] <= 0;
      end
    end
  end
  
  
  always @(posedge syn_clk or negedge rst_i) begin
    if(~rst_i) begin
      wptr <= 0;
      rptr <= 0;
      rdata <= 0;
      wr_ack <= 0;
      rd_valid <= 0;
      overflow <= 0;
      underflow <= 0;
    end else begin
      
      // WRITE LOGIC
      if(wr_en_i) begin
        
        if(full_o) begin
          overflow <= 1'b1;
          wptr <= wptr;
          wr_ack <= 0;
        end else begin
          overflow <= 0;
          for (int i = 0; i < WTOR_RATIO; i = i + 1) begin
            mem[wptr+i] <= temp_mem[i];
          end
          wptr <= wptr + WTOR_RATIO;
          wr_ack <= 1'b1;
        end
        
      end else begin
        wr_ack <= 0;
      end
      
      // READ LOGIC
      if(rd_en_i) begin
        
        if(empty_o) begin
          underflow <= 1'b1;
          rptr <= rptr;
          rd_valid <= 0;
        end else begin
          underflow <= 0;
          rdata <= rtemp;
          rptr <= rptr + RTOW_RATIO;
          rd_valid <= 1'b1;
        end
        
      end else begin
        rd_valid <= 0;
      end 
      
    end
  end
  
  // Temp Memory Update at every change in write data
  always @(wdata or rst_i) begin
    wtemp = wdata;
    for(int i = 0; i < WTOR_RATIO; i++) begin
      temp_mem[i] = wtemp[W_WIDTH-1 : W_WIDTH - 1 - (L_WIDTH - 1)];
      wtemp = wtemp << R_WIDTH;
    end
  end
  
  // Rtemp Update at every rptr increment or change in empty flag
  always @(rptr or empty_o) begin
    if(~empty_o) begin
      rtemp = 0;
      for(int i = 0; i < RTOW_RATIO; i = i + 1) begin
        rtemp = (rtemp << L_WIDTH) + mem[rptr+i];
      end
    end
  end
  
  // Datacount logic 
  always @(wptr or rptr) begin
    if(wptr[$clog2(DEPTH)-1:0] === rptr[$clog2(DEPTH)-1:0]) begin
      if(wptr[$clog2(DEPTH)] === rptr[$clog2(DEPTH)]) begin
        data_count = 0;
      end else begin
        data_count = DEPTH;
      end
    end else begin
      if(wptr[$clog2(DEPTH)-1:0] < rptr[$clog2(DEPTH)-1:0]) begin
        data_count = wptr[$clog2(DEPTH)-1:0] + (DEPTH - rptr[$clog2(DEPTH)-1:0]);
      end else begin
        data_count = wptr[$clog2(DEPTH)-1:0] - rptr[$clog2(DEPTH)-1:0];
      end
    end
  end
  
  
  // Readable and Writeable Datacount Logic
  always @(data_count) begin
    
    if(W_WIDTH > R_WIDTH) begin
      
      rdata_count = data_count;
      wdata_count = data_count;
      nondivi = 0;
      
      for(int i = 0; i < WTOR_RATIO; i = i + 2) begin
        if(wdata_count[0] == 1'b1)
          nondivi = 1'b1;
        wdata_count = wdata_count >> 1;
      end
      
      if(nondivi) begin
        wdata_count = wdata_count + 1'b1;
      end 
      
      readable_count = rdata_count;
      writeable_count = (DEPTH >> $clog2(WTOR_RATIO)) - wdata_count;
      
    end else if (R_WIDTH > W_WIDTH) begin
      
      rdata_count = data_count;
      wdata_count = data_count;
      nondivi = 0;
      
      for(int i = 0; i < RTOW_RATIO; i = i + 2) begin
        rdata_count = rdata_count >> 1;
      end
   
      
      writeable_count = DEPTH - wdata_count;
      readable_count = rdata_count;
      
    end else begin           // W_WIDTH == R_WIDTH
      
      rdata_count = data_count;
      wdata_count = data_count;
      readable_count = rdata_count;
      writeable_count = DEPTH - wdata_count;
      nondivi = 0;
      
    end
    
  end
  
  // Output Logic
  assign rdata_o = rdata;
  assign wr_ack_o = wr_ack;
  assign rd_valid_o = rd_valid;
  assign empty_o = (data_count < 0 + RTOW_RATIO);
  assign full_o = (data_count > DEPTH - WTOR_RATIO);
  assign almost_full_o = (data_count >= DEPTH - (WTOR_RATIO * AF));
  assign almost_empty_o = (data_count <= 0 + (RTOW_RATIO * AE));
  assign underflow_o = underflow;
  assign overflow_o = overflow;
  assign data_count_o = data_count;
  assign writeable_count_o = writeable_count;
  assign readable_count_o = readable_count;
  
  // Test
  assign tempmem = temp_mem[0];
  
endmodule