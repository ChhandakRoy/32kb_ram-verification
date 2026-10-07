
module mem_decoder ( mem_in1,
                 mem_in0,
                 mem_out3,
                 mem_out2,
                 mem_out1,
                 mem_out0);

   input mem_in1,
         mem_in0;

   output reg mem_out3,
              mem_out2,
              mem_out1,
              mem_out0;

   always@(*)
      begin
         case ({mem_in1,mem_in0})
            2'b00 : {mem_out3,mem_out2,mem_out1,mem_out0} = 4'b0001;
            2'b01 : {mem_out3,mem_out2,mem_out1,mem_out0} = 4'b0010;
            2'b10 : {mem_out3,mem_out2,mem_out1,mem_out0} = 4'b0100;
            2'b11 : {mem_out3,mem_out2,mem_out1,mem_out0} = 4'b1000;
         endcase
      end
endmodule
