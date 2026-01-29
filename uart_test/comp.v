
module comp (clk, counter);
   input clk;
   output [31:0] counter;

   wire 	 clk;
   reg [31:0] 	 counter;

   always @ (posedge clk)
     begin
	counter <= counter + 1;
     end

endmodule // comp

