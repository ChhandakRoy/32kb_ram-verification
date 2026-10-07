module dual_port_mem ( clk,
                  mem_en,
                  op_en,
                  data_in,
                  rd_address,
                  wr_address,
                  read,
                  write,
                  data_out);
  
   parameter RAM_WIDTH=64,
             RAM_DEPTH=1024,
             ADDR_SIZE=10;


   input clk;                          // RAM Clock
   input [RAM_WIDTH-1 : 0] data_in;    // Data Input
   input [ADDR_SIZE-1 : 0] rd_address; // Read Address
   input [ADDR_SIZE-1 : 0] wr_address; // Write Address
   input read;                         // Read Control
   input write;                        // Write Control
   input mem_en;                       // Memory enable
   input op_en;

   output reg [RAM_WIDTH-1 : 0] data_out;  // Data Output


   // Memory
   reg [RAM_WIDTH-1 : 0] memory [RAM_DEPTH-1 : 0];

   //Write Logic
   always @ (posedge clk)
      if (mem_en)
         begin
            if(write)
               memory[wr_address] <= data_in;
         end 

   //Read Logic
   always @ (posedge clk)
      if (op_en)
         begin
            if(read)
               data_out <= memory[rd_address];
         end
      else
         data_out <= 64'bz;

endmodule

