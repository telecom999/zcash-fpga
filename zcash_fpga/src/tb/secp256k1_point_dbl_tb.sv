/*
  Copyright (C) 2019  Benjamin Devlin and Zcash Foundation

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/
`timescale 1ps/1ps

module secp256k1_point_dbl_tb ();
import common_pkg::*;
import secp256k1_pkg::*;

localparam CLK_PERIOD = 100;

logic clk, rst;

if_axi_stream #(.DAT_BYTS(256*3/8)) in_if(clk); // Point is X, Y, Z
if_axi_stream #(.DAT_BYTS(256*3/8)) out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) mult_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) mult_out_if(clk);

if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) sub_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) sub_out_if(clk);
if_axi_stream #(.DAT_BYTS(256*2/8), .CTL_BITS(8)) add_in_if(clk);
if_axi_stream #(.DAT_BYTS(256/8), .CTL_BITS(8)) add_out_if(clk);

jb_point_t in_p, out_p;

always_comb begin
  in_p = in_if.dat; 
  out_if.dat = out_p;
end

initial begin
  rst = 0;
  repeat(2) #(20*CLK_PERIOD) rst = ~rst;
end

initial begin
  clk = 0;
  forever #CLK_PERIOD clk = ~clk;
end

always_comb begin
  out_if.sop = 1;
  out_if.eop = 1;
  out_if.ctl = 0;
  out_if.mod = 0;
end

// Check for errors
always_ff @ (posedge clk)
  if (out_if.val && out_if.err)
    $error(1, "%m %t ERROR: output .err asserted", $time);

ec_point_dbl
#(
  .FP_TYPE ( jb_point_t ),
  .FE_TYPE ( fe_t )
) ec_point_dbl (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_p   ( in_p      ),
  .i_val ( in_if.val ),
  .o_rdy ( in_if.rdy ),
  .o_p   ( out_p     ),
  .o_err ( out_if.err ),
  .i_rdy ( out_if.rdy ),
  .o_val  ( out_if.val ) ,
  // Interface to multiplier (mod p)
  .o_mul_if ( mult_in_if ),
  .i_mul_if ( mult_out_if ),
  .o_add_if ( add_in_if ),
  .i_add_if ( add_out_if ),
  .o_sub_if ( sub_in_if ),
  .i_sub_if ( sub_out_if )
);

always_comb begin
  add_in_if.rdy = add_out_if.rdy;
  add_out_if.val = add_in_if.val;
  add_out_if.dat = fe_add(add_in_if.dat[0 +: 256], add_in_if.dat[256 +: 256]);
  add_out_if.ctl = add_in_if.ctl;

  sub_in_if.rdy = sub_out_if.rdy;
  sub_out_if.val = sub_in_if.val;
  sub_out_if.dat = fe_sub(sub_in_if.dat[0 +: 256], sub_in_if.dat[256 +: 256]);
  sub_out_if.ctl = sub_in_if.ctl;
end

// Attach a mod reduction unit and multiply - mod unit
// In full design these could use dedicated multipliers or be arbitrated

secp256k1_mult_mod #(
  .CTL_BITS ( 8 )
)
secp256k1_mult_mod (
  .i_clk ( clk ),
  .i_rst ( rst ),
  .i_dat_a ( mult_in_if.dat[0 +: 256] ),
  .i_dat_b ( mult_in_if.dat[256 +: 256] ),
  .i_val ( mult_in_if.val ),
  .i_err ( mult_in_if.err ),
  .i_ctl ( mult_in_if.ctl ),
  .i_cmd ( 2'd0           ),
  .o_rdy ( mult_in_if.rdy ),
  .o_dat ( mult_out_if.dat ),
  .i_rdy ( mult_out_if.rdy ),
  .o_val ( mult_out_if.val ),
  .o_ctl ( mult_out_if.ctl ),
  .o_err ( mult_out_if.err ) 
);

task test_0();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] expected,  get_dat;
  logic [255:0] in_a, in_b;
  jb_point_t p_in, p_exp, p_out;
  $display("Running test_0...");

  p_in = g_point;
  p_exp = dbl_jb_point(p_in);
  
  fork
    in_if.put_stream(p_in, 256*3/8);
    out_if.get_stream(get_dat, get_len);
  join
  
  p_out = get_dat;
  
  if (p_exp != p_out) begin
    $display("Expected:");
    print_jb_point(p_exp);
    $display("Was:");
    print_jb_point(p_out);
    $fatal(1, "%m %t ERROR: test_0 point was wrong", $time);
  end 
  
  $display("test_0 PASSED");
end
endtask;

function compare_point();
  
endfunction

initial begin
  out_if.rdy = 0;
  in_if.val = 0;
  #(40*CLK_PERIOD);
  
  test_0();

  #1us $finish();
end
endmodule