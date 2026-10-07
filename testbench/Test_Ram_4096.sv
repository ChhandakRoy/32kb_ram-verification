`timescale 1ns / 1ps

//=============================================================================
// Project       : 4096 x 64 RAM Verification Environment
// Description   : SystemVerilog class-based testbench for Ram_4096
//                  - Transaction-based stimulus generation
//                  - Mailbox-based communication
//                  - Driver / Monitor / Scoreboard architecture
//                  - Associative-array reference memory
//                  - Queue-based valid read-address generation
//
// DUT           : Ram_4096
// RAM Capacity  : 4096 locations x 64 bits
// Address Width : 12 bits
// Data Width    : 64 bits
//=============================================================================


`define RAM_WIDTH 64
`define ADDR_SIZE 12


//=============================================================================
// INTERFACE
//-----------------------------------------------------------------------------
interface ram_if;

   bit clk;                              // RAM clock
   bit [`RAM_WIDTH-1 : 0] data_in;       // Write data
   bit [`ADDR_SIZE-1 : 0] rd_address;    // Read address
   bit [`ADDR_SIZE-1 : 0] wr_address;    // Write address
   bit read;                             // Read enable
   bit write;                            // Write enable

   logic [`RAM_WIDTH-1 : 0] data_out;    // DUT read data

endinterface



//=============================================================================
// TESTBENCH TOP
//=============================================================================

module Test_Ram_4096;

parameter NO_OF_TEST = 40;


//=============================================================================
// TRANSACTION
//-----------------------------------------------------------------------------



class transaction;

   rand bit [`RAM_WIDTH-1:0] data_in;
   rand bit [`ADDR_SIZE-1 : 0] rd_address, wr_address;
   rand bit read, write;

   logic [`RAM_WIDTH-1 : 0] data_out;


   function new();

      $display("------------------------------------------------------------");
      $display("[TRANSACTION] New transaction object created");
      $display("------------------------------------------------------------");

   endfunction

endclass : transaction



//=============================================================================
// GENERATOR
//-----------------------------------------------------------------------------

class generator;

   mailbox gen2drv;
   mailbox gen2mon;

   // Queue containing addresses that have already been written.
   bit [11:0] written_addresses[$];

   int index;


   function new(input mailbox gen2drv,
                input mailbox gen2mon);

      this.gen2mon = gen2mon;
      this.gen2drv = gen2drv;

      $display("[GENERATOR] Generator initialized");

   endfunction


   task run();

      transaction tr;

      $display("");
      $display("============================================================");
      $display("[GENERATOR] Starting stimulus generation");
      $display("============================================================");


      repeat(NO_OF_TEST)
      begin

         tr = new();

         tr.randomize();

         // --------------------------------------------------------------
         // Initial phase:
         // Generate write-only transactions until the queue contains
         // ten valid written addresses.
         // --------------------------------------------------------------

         if(written_addresses.size() < 10)
         begin
            tr.read  = 0;
            tr.write = 1;

            // Store the address so it can be used for a future read.
            written_addresses.push_back(tr.wr_address);

            $display("[GENERATOR] WRITE PHASE");
            $display("            Write Address : %0d", tr.wr_address);
            $display("            Data          : %0d", tr.data_in);
            $display("            Stored Addr.  : %0d",
                     written_addresses.size());

         end

         else
         begin
            tr.read = 1;

            // Select one previously written address randomly.
            index = $urandom_range(0, written_addresses.size()-1);
            tr.rd_address = written_addresses[index];

            // If this transaction also performs a write, remember its
            // address so it becomes a legal read address in future
            // transactions.
            if(tr.write)
               written_addresses.push_back(tr.wr_address);

            $display("[GENERATOR]");
            $display("            Read Address  : %0d", tr.rd_address);
            $display("            Write Enable  : %b", tr.write);
            $display("            Write Address : %0d", tr.wr_address);
            $display("            Data          : %0d", tr.data_in);
            $display("            Valid Addr.  : %0d",
                     written_addresses.size());

         end
         // Send the same transaction object to both components.
         gen2mon.put(tr);
         gen2drv.put(tr);

         $display("[GENERATOR] Transaction dispatched to DRIVER and MONITOR");
         $display("------------------------------------------------------------");

      end

      $display("");
      $display("============================================================");
      $display("[GENERATOR] Stimulus generation completed");
      $display("============================================================");

   endtask

endclass : generator



//=============================================================================
// DRIVER
//-----------------------------------------------------------------------------

class driver;

   virtual ram_if vif;
   transaction tr;
   mailbox gen2drv;


   function new(input virtual ram_if vif,
                input mailbox gen2drv);

      this.vif     = vif;
      this.gen2drv = gen2drv;

      $display("[DRIVER] Driver initialized");

   endfunction


   task run();

      repeat(NO_OF_TEST)
      begin

         // Wait for the next transaction from the generator.
         gen2drv.get(tr);


         // Drive inputs at the falling edge.
         @(negedge vif.clk);

         vif.data_in    <= tr.data_in;
         vif.wr_address <= tr.wr_address;
         vif.rd_address <= tr.rd_address;
         vif.read       <= tr.read;
         vif.write      <= tr.write;


         $display("[DRIVER]");
         $display("         WRITE = %b | WR_ADDR = %0d | DATA = %0d",
                  tr.write, tr.wr_address, tr.data_in);

         $display("         READ  = %b | RD_ADDR = %0d",
                  tr.read, tr.rd_address);

      end

   endtask

endclass : driver


//=============================================================================
// MONITOR
//-----------------------------------------------------------------------------

class monitor;

   virtual ram_if vif;

   mailbox mon2sb;
   mailbox gen2mon;
   transaction tr;
   
   //------------- FUNCTIONAL COVERAGE ----------------
    
covergroup ram_cg @(posedge vif.clk);

    rd_addr_cp: coverpoint vif.rd_address{
    
    bins bank0 ={[0:1023]};
    bins bank1 ={[1024:2047]};
    bins bank2 ={[2048:3071]};
    bins bank3 ={[3072:4095]};
    }
    
    wr_addr_cp: coverpoint vif.wr_address{
    
    bins bank0 ={[0:1023]};
    bins bank1 ={[1024:2047]};
    bins bank2 ={[2048:3071]};
    bins bank3 ={[3072:4095]};
    }
    
     cp_read : coverpoint vif.read {
        bins read_disabled = {0};
        bins read_enabled  = {1};
    }

    cp_write : coverpoint vif.write {
        bins write_disabled = {0};
        bins write_enabled  = {1};
    }
    
    cross_rd_wr : cross cp_read, cp_write;
    

endgroup


   function new(input virtual ram_if vif,
                input mailbox gen2mon,
                input mailbox mon2sb);

      this.vif     = vif;
      this.gen2mon = gen2mon;
      this.mon2sb  = mon2sb;
      
      ram_cg       = new();

      $display("[MONITOR] Monitor initialized");

   endfunction


   task run();

      // Synchronize monitor startup with the clock.
      @(posedge vif.clk);

      repeat(NO_OF_TEST)
      begin

         // Obtain the transaction corresponding to this DUT operation.
         gen2mon.get(tr);

         // Wait for the synchronous RAM read operation to complete.
         @(posedge vif.clk);
         #1;

         // Capture the DUT output only for read transactions.
         tr.data_out = tr.read ?
                       vif.data_out :
                       {`RAM_WIDTH{1'bx}};


         $display("[MONITOR]");
         $display("         READ = %b | RD_ADDR = %0d | DUT_DATA = %0d",
                  tr.read, tr.rd_address, tr.data_out);

         // Forward the observed transaction to the scoreboard.
         mon2sb.put(tr);
      end
      
     //==========================================================================
// FUNCTIONAL COVERAGE SUMMARY
//==========================================================================

$display("");
$display("");
$display("=============================================================================");
$display("                        FUNCTIONAL COVERAGE REPORT");
$display("=============================================================================");

$display("[COVERAGE] Overall Functional Coverage : %0.2f%%",
         ram_cg.get_coverage());

$display("-----------------------------------------------------------------------------");
$display("[COVERAGE] Address Bank Coverage       : %0.2f%%",
         ram_cg.rd_addr_cp.get_coverage());

$display("[COVERAGE] Write Address Bank Coverage : %0.2f%%",
         ram_cg.wr_addr_cp.get_coverage());

$display("[COVERAGE] Read Enable Coverage        : %0.2f%%",
         ram_cg.cp_read.get_coverage());

$display("[COVERAGE] Write Enable Coverage       : %0.2f%%",
         ram_cg.cp_write.get_coverage());

$display("[COVERAGE] Read/Write Cross Coverage   : %0.2f%%",
         ram_cg.cross_rd_wr.get_coverage());

$display("=============================================================================");
$display("                        COVERAGE COLLECTION COMPLETE");
$display("=============================================================================");
$display("");
      
   endtask

endclass : monitor



//=============================================================================
// REFERENCE MODEL
//-----------------------------------------------------------------------------
// ref_mem is an associative array acting as a software reference memory.
//
// Key   : 12-bit RAM address
// Value : 64-bit expected data
//
// Unlike a fixed-size array, the associative array stores only addresses
// that have actually been written during the test.
//=============================================================================

bit [`RAM_WIDTH-1:0] actual;

bit [`RAM_WIDTH-1:0]
    ref_mem [bit[`ADDR_SIZE-1 : 0]];



//=============================================================================
// SCOREBOARD
//-----------------------------------------------------------------------------
// Responsibilities:
//   1. Receive transactions from the monitor.
//   2. Maintain the reference memory.
//   3. Calculate the expected value for each read.
//   4. Compare expected data against actual DUT data.
//   5. Track PASS and FAIL counts.
//
// The scoreboard therefore provides the functional correctness check for
// the RAM.
//=============================================================================

class scoreboard;

   mailbox mon2sb;
   transaction tr;

   int pass_count;
   int fail_count;


   function new(input mailbox mon2sb);

      this.mon2sb = mon2sb;

      $display("[SCOREBOARD] Scoreboard initialized");

   endfunction


   task run();

      repeat(NO_OF_TEST)
      begin

         // Receive the transaction after the monitor has sampled the DUT.
         mon2sb.get(tr);


         // ==============================================================
         // READ CHECK
         // ==============================================================

         if(tr.read)
         begin

            // Obtain expected data from the reference memory.
            if(ref_mem.exists(tr.rd_address))
               actual = ref_mem[tr.rd_address];

            else
               actual = {`RAM_WIDTH{1'bx}};


            // Four-state comparison is used so that X/Z states are
            // considered during comparison.
            if(actual === tr.data_out)
            begin

               pass_count++;

               $display("[SCOREBOARD] READ PASS");
               $display("            Address  : %0d", tr.rd_address);
               $display("            Expected : %0d", actual);
               $display("            Actual   : %0d", tr.data_out);
               $display("            Passes   : %0d", pass_count);

            end

            else
            begin

               fail_count++;

               $display("[SCOREBOARD] READ FAIL");
               $display("            Address  : %0d", tr.rd_address);
               $display("            Expected : %0d", actual);
               $display("            Actual   : %0d", tr.data_out);
               $display("            Fails    : %0d", fail_count);

            end

         end


         // ==============================================================
         // WRITE UPDATE
         // ==============================================================

         if(tr.write)
         begin

            // Update the software reference model with the same write
            // transaction applied to the DUT.
            ref_mem[tr.wr_address] = tr.data_in;

            $display("[SCOREBOARD] REFERENCE MODEL UPDATED");
            $display("            Address : %0d", tr.wr_address);
            $display("            Data    : %0d", tr.data_in);

         end

      end


      // ==============================================================
      // FINAL TEST SUMMARY
      // ==============================================================

      $display("");
      $display("============================================================");
      $display("[SCOREBOARD] VERIFICATION SUMMARY");
      $display("============================================================");
      $display("Total Transactions : %0d", NO_OF_TEST);
      $display("Read Passes        : %0d", pass_count);
      $display("Read Failures      : %0d", fail_count);

      if(fail_count == 0)
         $display("RESULT             : TEST PASSED");
      else
         $display("RESULT             : TEST FAILED");

      $display("============================================================");

   endtask

endclass : scoreboard



//=============================================================================
// DUT INSTANTIATION
//=============================================================================

ram_if vif();

Ram_4096 DUT
(
   .clk        (vif.clk),
   .data_in    (vif.data_in),
   .rd_address (vif.rd_address),
   .wr_address (vif.wr_address),
   .read       (vif.read),
   .write      (vif.write),
   .data_out   (vif.data_out)
);



//=============================================================================
// TESTBENCH COMPONENTS
//=============================================================================

generator  gen;
driver     drv;
monitor    mon;
scoreboard sb;


//=============================================================================
// MAILBOXES
//-----------------------------------------------------------------------------
// gen2drv : Generator → Driver
// gen2mon : Generator → Monitor
// mon2sb  : Monitor → Scoreboard
//=============================================================================

mailbox gen2drv;
mailbox gen2mon;
mailbox mon2sb;



//=============================================================================
// CLOCK GENERATION
//-----------------------------------------------------------------------------
// 10 ns clock period:
//     0 ns → 5 ns  : HIGH/LOW transition
//     5 ns → 10 ns : next transition
//
// The driver applies inputs at negedge.
// The DUT samples them at posedge.
//=============================================================================

initial
begin

   vif.clk = 1'b0;

   forever
      #5 vif.clk = ~vif.clk;

end



//=============================================================================
// TESTBENCH COMPONENT CONSTRUCTION
//=============================================================================

initial
begin

   gen2drv = new();
   gen2mon = new();
   mon2sb  = new();


   gen = new(gen2drv, gen2mon);
   drv = new(vif, gen2drv);
   mon = new(vif, gen2mon, mon2sb);
   sb  = new(mon2sb);


   $display("");
   $display("============================================================");
   $display("        4096 x 64 RAM SYSTEMVERILOG TESTBENCH");
   $display("============================================================");
   $display("RAM Width       : %0d bits", `RAM_WIDTH);
   $display("Address Width   : %0d bits", `ADDR_SIZE);
   $display("RAM Depth      : 4096 locations");
   $display("Transactions   : %0d", NO_OF_TEST);
   $display("============================================================");
   $display("");

end




initial
begin

   fork

      gen.run();
      drv.run();
      mon.run();
      sb.run();

   join

end


endmodule