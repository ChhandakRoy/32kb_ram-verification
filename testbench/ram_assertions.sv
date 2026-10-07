module ram_assertions (

    input logic clk,

    input logic mem_rd0,
    input logic mem_rd1,
    input logic mem_rd2,
    input logic mem_rd3,

    input logic mem_wr0,
    input logic mem_wr1,
    input logic mem_wr2,
    input logic mem_wr3

);

    //==========================================================
    // READ BANK DECODER CHECK
    //==========================================================

    assert property (
        @(posedge clk)
        $onehot0({mem_rd3, mem_rd2, mem_rd1, mem_rd0})
    )
    else
        $error("[SVA] Multiple read banks selected!");


    //==========================================================
    // WRITE BANK DECODER CHECK
    //==========================================================

    assert property (
        @(posedge clk)
        $onehot0({mem_wr3, mem_wr2, mem_wr1, mem_wr0})
    )
    else
        $error("[SVA] Multiple write banks selected!");

endmodule


//==============================================================
// BIND ASSERTION MODULE TO DUT
//==============================================================

bind Ram_4096 ram_assertions sva_i (

    .clk     (clk),

    .mem_rd0 (mem_rd0),
    .mem_rd1 (mem_rd1),
    .mem_rd2 (mem_rd2),
    .mem_rd3 (mem_rd3),

    .mem_wr0 (mem_wr0),
    .mem_wr1 (mem_wr1),
    .mem_wr2 (mem_wr2),
    .mem_wr3 (mem_wr3)

);