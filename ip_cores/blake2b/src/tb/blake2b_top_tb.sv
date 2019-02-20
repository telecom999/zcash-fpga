/*
  The BLAKE2b testbench. Uses parameters so can test either the basic Blake2b
  or the Blake2b_pipe version.
  
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

module blake2b_top_tb();

parameter USE_BLAKE2B_PIPE = 0; // This instantiates the pipelined version instead
parameter USE_BLAKE2B_PIPE_MSG_LEN = 140; // Has to be the maximum of whatever test case
parameter MSG_VAR_BYTS = USE_BLAKE2B_PIPE_MSG_LEN;

import blake2b_pkg::*;
import common_pkg::*;

logic clk, rst;
logic [7:0] i_byte_len;
logic [64*8-1:0] parameters;

logic [64*8-1:0] expected;
if_axi_stream #(.DAT_BYTS(USE_BLAKE2B_PIPE == 0 ? 128 : USE_BLAKE2B_PIPE_MSG_LEN)) i_block(clk);
if_axi_stream #(.DAT_BYTS(64)) out_hash(clk);

initial begin
  rst = 0;
  #100ns rst = 1;
  #100ns rst = 0;
end

initial begin
  clk = 0;
  forever #10ns clk = ~clk;
end

generate if ( USE_BLAKE2B_PIPE == 0 ) begin: DUT_GEN
  blake2b_top DUT (
    .i_clk ( clk ),
    .i_rst ( rst ),
    .i_parameters ( parameters ),
    .i_byte_len   ( i_byte_len ),
    .i_block ( i_block ),
    .o_hash  ( out_hash )
  );
end else begin
  blake2b_pipe_top #(
    .MSG_LEN      ( USE_BLAKE2B_PIPE_MSG_LEN ),
    .MSG_VAR_BYTS ( MSG_VAR_BYTS             ),
    .CTL_BITS ( 8 )
  )
  DUT (
    .i_clk ( clk ),
    .i_rst ( rst ),
    .i_parameters ( parameters ),
    .i_byte_len   ( i_byte_len ),
    .i_block ( i_block  ),
    .o_hash  ( out_hash )
  );
end
endgenerate

// This test runs the hash which is shown in the RFC, for "abc"
task rfc_test();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  $display("Running rfc_test...\n");
  expected = 'h239900d4ed8623b95a92f1dba88ad31895cc3345ded552c22d79ab2a39c5877dd1a2ffdb6fbb124bb7c45a68142f214ce9f6129fb697276a0d4d1c983fa580ba;
  i_byte_len = 3;
  i_block.put_stream("cba", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("rfc_test PASSED");
end
endtask

// This is a test for hashing random string of 128 bytes
task test_128_bytes();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  $display("Running test_128_bytes...");
  expected = 'hd2a56bb7bb1ff1fffcf2f151522455e32969ddfeb409b105f45299b8cbd68eb370fd6d45d63981d23cd2686dfd9a76f5b1d134be076f7d08ecc457522042e34a;
  i_byte_len = 128;
  i_block.put_stream("monek14SFMpNgHz12zMfplMfcHkx6JhKhSWTNwzGiq8UiPa4n4Ehq363oHG92GPDVpvQut4ui5e6XxieeKTn1THLWiMZ0iaOFndxcT6FGPgmHXQ5zJU96X71zfWbvUQs", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("test_128_bytes PASSED");
end
endtask

// This is a test for hashing random string of 140 bytes (does two passes which is required for equihash)
task test_140_bytes();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  $display("Running test_140_bytes...");
  expected = 'h2012a869a3b89a69ffc954f6855c7f61a61190553dc487171ec3fe944d04c83cd4c842fff5a8258d5e14b05b7b6f30e8ddcb754d719137ec42fb5cdb562f8c89;
  i_byte_len = 140;
  i_block.put_stream("YbEAEzgJ1tgC3t6vDaJFqlWp1PaL482f7iZZzRj3xXpY2PPupwdTKAaBzB6KuN6j0alaoaFQfNboDbkNv5KDs5d7zN9JssrtOjGJdrVLfvb7uAdnVYoIgIv2zbXUQIPpwWdzEzj1CzX5", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("test_140_bytes PASSED");
end
endtask

// This is a test for hashing random string of 127 bytes
task test_127_bytes();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  $display("Running test_127_bytes...");
  expected = 'h14aee933634b9fa905fcf52aa64de25a8d9216e3bbb740f09d7b6d4dac498661c50e0cd1eb7e968bfe57f7107cd038e47777c2404229a6413067a008b36cc8da;
  i_byte_len = 127;
  i_block.put_stream("34h1im4zJ7w4rLLGGARc4FM3UT5JKPNkiLS4ojxRroYjvdzIApWsdVtEP2kzHMc7CKqbWRxOdkLxAb8XnWGHgwU5kmyDQqMvYOFrXf7rVaEXCU3IlZITlJ03sjjI0Jc", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("test_127_bytes PASSED");
end
endtask

// This is a test for hashing random string of 129 bytes
task test_129_bytes();
begin
  integer signed get_len;
  logic [common_pkg::MAX_SIM_BYTS*8-1:0] get_dat;
  $display("Running test_129_bytes...");
  expected = 'hb9e848de6ee548d1bbe3395648c8c9a4c14e4d984f9d16159e0ff585bdedc5ff4d6f8566c207cb437622cf0173a4735e1b1797a49f2cda96bb7aa675ed310fbd;
  i_byte_len = 129;
  i_block.put_stream("u7UwRVQMmt3jK8ghQjntQEqF0eiw7P2s3Q6tkXZMyObLyhRb6Yhw8VUj2gy4aZsIRVtFO0yJjzjjqkIB2vuIkLxU8eiY7nfJnct1OvRIny7CVQNuIhbc9WTfADOlxx1bu", i_byte_len);
  out_hash.get_stream(get_dat, get_len);
  common_pkg::compare_and_print(get_dat, expected);
  $display("test_129_bytes_bytes PASSED");
end
endtask

// Main testbench calls
initial begin
  i_block.reset_source();
  i_byte_len = 3;
  out_hash.rdy = 1;
  parameters = {32'd0, 8'd1, 8'd1, 8'd0, 8'd64};
  #200ns;
  
  rfc_test();
  test_127_bytes();
  test_128_bytes();
  test_129_bytes();
  test_140_bytes();

  #10us $finish();

end

endmodule