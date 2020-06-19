`timescale 1ns/1ps
`define CFG_PLENGTH 24
`define DFF 0.1

module rmii_fpga_tb;

reg clk, resetn;
// Config registers
reg [31:0] cfg [0:`CFG_PLENGTH-1];
reg  [7:0] cfg_counter;

reg        eth_crs_dv, eth_rxerr;
wire       eth_ref_clk, eth_tx_en; 
reg  [1:0] eth_rxd;
wire [1:0] eth_txd;   
reg        eth_rxdv_en;    

rmii_fpga u_rmii_fpga(
  .clk          (clk),
  .resetn       (resetn),

  .eth_ref_clk  (eth_ref_clk),
  .eth_crs_dv   (eth_crs_dv),
  .eth_rxd      (eth_rxd),
  .eth_tx_en    (eth_tx_en),
  .eth_txd      (eth_txd),
  .led          (led)
  );

initial begin
  clk = 0; resetn = 0; eth_rxdv_en = 0;
  eth_crs_dv = 0; eth_rxerr = 0; eth_rxd = 4'h0;
	#10
	resetn = 1;
  #2012
  eth_rxdv_en = 1;
  #(40*8*`CFG_PLENGTH);
  eth_rxdv_en = 0;
	// $finish();
end
always #5 clk = ~clk;

// RMII shift counter
reg [4:0] sft [0:15];
reg [4:0] sft_cnt;
initial begin
  sft[0] = 5'd0;
  sft[1] = 5'd2;
  sft[2] = 5'd4;
  sft[3] = 5'd6;
  sft[4] = 5'd8;
  sft[5] = 5'd10;
  sft[6] = 5'd12;
  sft[7] = 5'd14;
  sft[8] = 5'd16;
  sft[9] = 5'd18;
  sft[10] = 5'd20;
  sft[11] = 5'd22;
  sft[12] = 5'd24;
  sft[13] = 5'd26;
  sft[14] = 5'd28;
  sft[15] = 5'd30;
end
// 4-bit nibble serdes
always @(posedge eth_ref_clk) begin
  if(eth_rxdv_en) begin
    // synchronize rxdv
    eth_crs_dv <= #`DFF 1;
    eth_rxd <= #`DFF cfg[cfg_counter][sft[sft_cnt]+:2];
      if(sft_cnt == 15) begin
        cfg_counter <= #`DFF cfg_counter + 1;
        sft_cnt <= #`DFF 0;
      end else begin
        sft_cnt <= #`DFF sft_cnt + 1;
      end
  end else begin
    eth_crs_dv <= #`DFF 0;
  end
end

// MII ethernet config
initial begin
  cfg[0]  = {32'h55555555}; // preamble(8B)
  cfg[1]  = {32'hd5555555}; 
  cfg[2]  = {32'h005e0000}; // dest mac(6B)                                       0x1000
  cfg[3]  = {32'h76f0cefa}; // dest mac - src mac(6B)                             0x1004
  cfg[4]  = {32'h2e4da91c}; // src mac                                            0x1008
  cfg[5]  = {32'h00450008}; // eth.type(2B), ip.hdr_len(1B), ip.dsfield.ecn(1B)   0x100c
  cfg[6]  = {32'hf7514600}; // ip.len(2B), ip.id(2B)                              0x1010
  cfg[7]  = {32'h11400040}; // ip.frag_offset(2B), ip.ttl(1B), ip.proto(1B)       0x1014
  cfg[8]  = {32'ha8c09660}; // ip.checksum(2B), ip.src(4B)                        0x1018
  cfg[9]  = {32'ha8c06603}; // ip.src - ip.dst(4B)                                0x101c
  cfg[10] = {32'ha7bd7b03}; // ip.dst, udp.srcport(2B)                            0x1020
  cfg[11] = {32'h3200d204}; // udp.dstport(2B), udp.length(2B)                    0x1024
  cfg[12] = {32'h00000000}; // udp.checksum(2B)                                   0x1028
  // User config start
  // VCO frequency 600M - 1600M, clkin 200M
  cfg[13] = {1'b1, 7'h00, {23{1'b0}}, 1'b1}; // system reset                      0x102c
  cfg[14] = {1'b1, 7'h01, {8{1'b0}}, 16'd100}; // pulse count                     0x1030
  //                      pw, freq_div
  cfg[15] = {1'b1, 7'h02, {12{1'b0}}, 4'd0, 8'd20}; // pulse config               0x1034
  //               row_sp,col_sp,           frame,measure
  cfg[16] = {1'b1, 7'h03, 8'h00, 8'h00, {6{1'b0}}, 1'b1, 1'b0}; //                0x1038
  //                          hist_mode_flag
  cfg[17] = {1'b1, 7'h04, {22{1'b0}}, 2'b01}; //                                  0x103c
  //               hist_c2, hist_c1
  cfg[18] = {1'b1, 7'h05, 12'd25, 12'd25}; //                                     0x1040
  //               hist_c4, hist_c3
  cfg[19] = {1'b1, 7'h06, 12'd25, 12'd25}; //                                     0x1044
  //               hist_upth, hist_loth
  cfg[20] = {1'b1, 7'h07, 12'hFFF, 12'h000}; //                                   0x1048
  //                          cfg_ready
  cfg[21] = {1'b1, 7'h08, {23{1'b0}}, 1'b1}; //                                   0x104c
  //                       1: oneshot/0: cont, system start
  cfg[22] = {1'b1, 7'h09, {22{1'b0}}, 1'b0, 1'b1}; //                             0x1050
  // User config ends
  cfg[23] = {32'hD69456DB}; // fcs
  cfg_counter = 8'h00;
  sft_cnt = 0;
end

// https://crccalc.com/
// 00005e00 facef076 1ca94d2e 08004500 004651f7 40004011 6096c0a8 0366c0a8 037bbda7 04d20032 00000000
// 01000080 64000081 14000082 02000083 01000084 19900185 19900186 00f0ff87 01000088 01000089 
// 0xD69456DB

endmodule