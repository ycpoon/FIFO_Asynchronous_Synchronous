module asyn_fifo #(
  parameter W_WIDTH = 4,
  parameter R_WIDTH = 4,
  parameter WTOR_RATIO = 1,        // if R>W, init. as 1, option: 1,2,4,8,16,32
  parameter RTOW_RATIO = 1,        // if W>R, init. as 1, option: 1,2,4,8,16,32
  parameter DEPTH = 16,
  parameter AF = 3,               // AF becomes high when this amount of possible writes left 
  parameter AE = 3                // AE becomes high when this amount of possible reads left 
)(
  input wr_clk_i,
  input rd_clk_i,
  input wr_en_i,
  input rd_en_i,
  input [W_WIDTH-1:0] wdata,
  input a_rst_i, //ACTIVE LOW
  
  // WRITE Flags
  output wr_ack_o,
  output full_o,
  output almost_full_o,
  output overflow_o,
  output [$clog2(DEPTH):0] writeable_count_o,
  
  // READ Flags
  output rd_valid_o,
  output empty_o,
  output almost_empty_o,
  output [R_WIDTH-1:0] rdata_o,
  output underflow_o,
  output [$clog2(DEPTH):0] readable_count_o,
  
  // Synchronized Flag
  output [$clog2(DEPTH):0] syn_data_count_o,
  
  //Test
  output [45:0] tempmem
);
      
  localparam L_WIDTH = (W_WIDTH > R_WIDTH) ? R_WIDTH : W_WIDTH;
  
  reg [L_WIDTH-1:0] mem [0:(DEPTH*2)-1];
  reg [$clog2(DEPTH):0] wptr;             // MSB for empty-full detection
  reg [$clog2(DEPTH):0] rptr;
  wire [$clog2(DEPTH):0] wptr_g;
  wire [$clog2(DEPTH):0] rptr_g;
  reg [$clog2(DEPTH):0] wptr_g_f1;
  reg [$clog2(DEPTH):0] wptr_g_f2;
  reg [$clog2(DEPTH):0] rptr_g_f1;
  reg [$clog2(DEPTH):0] rptr_g_f2;
  reg [$clog2(DEPTH):0] wptr_syn;
  reg [$clog2(DEPTH):0] rptr_syn;
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
  reg nondivi_w;
  
//   initial begin
//     for (int i = 0; i < DEPTH; i = i + 1) begin
//       mem[i] <= 0;
//     end
    
    wptr <= 0;
    rptr <= 0;
    wptr_g_f1 <= 0;
    rptr_g_f1 <= 0;
    wptr_g_f2 <= 0;
    rptr_g_f2 <= 0;
    wptr_syn <= 0;
    rptr_syn <= 0;
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
    nondivi_w <= 0;
  end
  
  // Clear Memory When Reset
  always @(negedge a_rst_i) begin
    if(~a_rst_i) begin
      for (int i = 0; i < DEPTH; i = i + 1) begin
        mem[i] <= 0;
      end
      
      for(int i = 0; i < WTOR_RATIO; i = i + 1) begin
        temp_mem[i] <= 0;
      end
    end
  end
  
  
  // WRITE LOGIC
  always @(posedge wr_clk_i or negedge a_rst_i) begin
    if(~a_rst_i) begin
      wptr <= 0;
      wr_ack <= 0;
      overflow <= 0;
    end else begin
      
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
    
    end
  end
  
  
  // READ LOGIC
  always @(posedge rd_clk_i or negedge a_rst_i) begin
    if(~a_rst_i) begin
      rptr <= 0;
      rdata <= 0;
      rd_valid <= 0;
      underflow <= 0;
    end else begin
      
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
  always @(wdata or a_rst_i) begin
    wtemp = wdata;
    for(int i = 0; i < WTOR_RATIO; i++) begin
      temp_mem[i] = wtemp[W_WIDTH-1 : W_WIDTH - 1 - (L_WIDTH - 1)]; 
      wtemp = wtemp << R_WIDTH;
    end
  end
  
  // Rtemp Update at every rptr increment or change in empty flag
  always @(rptr or empty_o or a_rst_i) begin
    if(~empty_o) begin
      rtemp = 0;
      for(int i = 0; i < RTOW_RATIO; i = i + 1) begin
        rtemp = (rtemp << L_WIDTH) + mem[rptr+i];
      end
    end
  end
  
  
  // WPTR and RPTR gray conversion
  assign wptr_g = wptr ^ (wptr >> 1);
  assign rptr_g = rptr ^ (rptr >> 1);
  
  
  // Two Flop Synchronizer (READ)
  always @(posedge wr_clk_i or negedge a_rst_i) begin
    if(~a_rst_i) begin
      rptr_g_f1 <= 0;
      rptr_g_f2 <= 0;
    end else begin
      rptr_g_f1 <= rptr_g;
      rptr_g_f2 <= rptr_g_f1;
    end
  end
  
  // Two Flop Synchronizer (WRITE)
  always @(posedge rd_clk_i or negedge a_rst_i) begin
    if(~a_rst_i) begin
      wptr_g_f1 <= 0;
      wptr_g_f2 <= 0;
    end else begin
      wptr_g_f1 <= wptr_g;
      wptr_g_f2 <= wptr_g_f1;
    end
  end
  
  
  // Gray to Binary Conversion (READ)
  always @(rptr_g_f2) begin
    rptr_syn[$clog2(DEPTH)] = rptr_g_f2[$clog2(DEPTH)];
    
    for(int i = $clog2(DEPTH) - 1; i >= 0 ; i = i - 1) begin
      rptr_syn[i] = rptr_g_f2[i] ^ rptr_syn[i+1];
    end
  end
  
  // Gray to Binary Conversion (WRITE)
  always @(wptr_g_f2) begin
    wptr_syn[$clog2(DEPTH)] = wptr_g_f2[$clog2(DEPTH)];
    
    for(int i = $clog2(DEPTH) - 1; i >= 0 ; i = i - 1) begin
      wptr_syn[i] = wptr_g_f2[i] ^ wptr_syn[i+1];
    end
  end
  
  
  // WRITE datacount & Writeable Count Logic 
  always @(wptr or rptr_syn) begin
    if(wptr[$clog2(DEPTH)-1:0] === rptr_syn[$clog2(DEPTH)-1:0]) begin
      if(wptr[$clog2(DEPTH)] === rptr_syn[$clog2(DEPTH)]) begin
        wdata_count = 0;
      end else begin
        wdata_count = DEPTH;
      end
    end else begin
      if(wptr[$clog2(DEPTH)-1:0] < rptr_syn[$clog2(DEPTH)-1:0]) begin
        wdata_count = wptr[$clog2(DEPTH)-1:0] + (DEPTH - rptr_syn[$clog2(DEPTH)-1:0]);
      end else begin
        wdata_count = wptr[$clog2(DEPTH)-1:0] - rptr_syn[$clog2(DEPTH)-1:0];
      end
    end
    
    if(W_WIDTH > R_WIDTH) begin
      nondivi_w = 0;
      
      for(int i = 0; i < WTOR_RATIO; i = i + 2) begin
        if(wdata_count[0] == 1'b1)
          nondivi_w = 1'b1;
        wdata_count = wdata_count >> 1;
      end
      
      if(nondivi_w) begin
        wdata_count = wdata_count + 1'b1;
      end
      
      writeable_count = (DEPTH >> $clog2(WTOR_RATIO)) - wdata_count;
      
    end else begin          // W_WIDTH <= R_WIDTH
      
      nondivi_w = 0;
      writeable_count = DEPTH - wdata_count;
      
    end
  end
  
  
  // READ datacount & Readable Count Logic
  always @(rptr or wptr_syn) begin
    if(wptr_syn[$clog2(DEPTH)-1:0] === rptr[$clog2(DEPTH)-1:0]) begin
      if(wptr_syn[$clog2(DEPTH)] === rptr[$clog2(DEPTH)]) begin
        rdata_count = 0;
      end else begin
        rdata_count = DEPTH;
      end
    end else begin
      if(wptr_syn[$clog2(DEPTH)-1:0] < rptr[$clog2(DEPTH)-1:0]) begin
        rdata_count = wptr_syn[$clog2(DEPTH)-1:0] + (DEPTH - rptr[$clog2(DEPTH)-1:0]);
      end else begin
        rdata_count = wptr_syn[$clog2(DEPTH)-1:0] - rptr[$clog2(DEPTH)-1:0];
      end
    end
    
    if(R_WIDTH > W_WIDTH) begin
      
      for(int i = 0; i < RTOW_RATIO; i = i + 2) begin
        rdata_count = rdata_count >> 1;
      end
      
      readable_count = rdata_count;
      
    end else begin         // R_WIDTH <= W_WIDTH
      
      readable_count = rdata_count;
      
    end
  end
  
  // Synchronized DATACOUNT logic
  always @(wptr_syn or rptr_syn) begin
    if(wptr_syn[$clog2(DEPTH)-1:0] === rptr_syn[$clog2(DEPTH)-1:0]) begin
      if(wptr_syn[$clog2(DEPTH)] === rptr_syn[$clog2(DEPTH)]) begin
        data_count = 0;
      end else begin
        data_count = DEPTH;
      end
    end else begin
      if(wptr_syn[$clog2(DEPTH)-1:0] < rptr_syn[$clog2(DEPTH)-1:0]) begin
        data_count = wptr_syn[$clog2(DEPTH)-1:0] + (DEPTH - rptr_syn[$clog2(DEPTH)-1:0]);
      end else begin
        data_count = wptr_syn[$clog2(DEPTH)-1:0] - rptr_syn[$clog2(DEPTH)-1:0];
      end
    end
  end
  
  
  // Output Logic
  assign rdata_o = rdata;
  assign wr_ack_o = wr_ack;
  assign rd_valid_o = rd_valid;
  assign empty_o = (rdata_count*RTOW_RATIO == 0);
  assign full_o = (wdata_count*WTOR_RATIO == DEPTH);
  assign almost_full_o = (wdata_count >= DEPTH - (WTOR_RATIO * AF));
  assign almost_empty_o = (rdata_count <= 0 + (RTOW_RATIO * AE));
  assign underflow_o = underflow;
  assign overflow_o = overflow;
  assign syn_data_count_o = data_count;
  assign writeable_count_o = writeable_count;
  assign readable_count_o = readable_count;
  
  
  // Test
  assign tempmem = wdata_count;
  
endmodule