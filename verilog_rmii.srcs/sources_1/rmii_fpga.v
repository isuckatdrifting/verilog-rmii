module rmii_fpga(
  input wire        clk,
  input wire        resetn,

 output wire        eth_ref_clk,
  input wire        eth_crs_dv,
  // input wire        eth_rxerr,
  input wire  [1:0] eth_rxd,
 output wire        eth_tx_en,
 output wire  [1:0] eth_txd,       
 output wire  [7:0] led
);

/**
 * MMCM, clk = 100M * CLKFBOUT_MULT_F / CLKOUT5_DIVIDE
 */
wire clk_buf, CLKFB_int, CLKOUT5, CLKOUT6, clk, locked;
// Clocking Primitive
MMCME2_ADV #(
  .BANDWIDTH("HIGH"),        // Jitter programming
  .CLKFBOUT_MULT_F(8.000),          // Multiply value for all CLKOUT
  .CLKFBOUT_PHASE(0.0),           // Phase offset in degrees of CLKFB
  .CLKFBOUT_USE_FINE_PS("FALSE"), // Fine phase shift enable (TRUE/FALSE)
  .CLKIN1_PERIOD(5),            // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
  .CLKOUT5_DIVIDE(8.000),         // Divide amount for CLKOUT5
  .CLKOUT5_DUTY_CYCLE(0.5),       // Duty cycle for CLKOUT5
  .CLKOUT5_PHASE(0.0),            // Phase offset for CLKOUT5
  .CLKOUT6_DIVIDE(16.000),         // Divide amount for CLKOUT6
  .CLKOUT6_DUTY_CYCLE(0.5),       // Duty cycle for CLKOUT6
  .CLKOUT6_PHASE(0.0),            // Phase offset for CLKOUT6
  .CLKOUT5_USE_FINE_PS("FALSE"),  // Fine phase shift enable (TRUE/FALSE)
  .CLKOUT6_USE_FINE_PS("FALSE"),  // Fine phase shift enable (TRUE/FALSE)
  .COMPENSATION("ZHOLD"),          // Clock input compensation
  .DIVCLK_DIVIDE(1),              // Master division value
  .STARTUP_WAIT("FALSE")          // Delays DONE until MMCM is locked
  )
MMCME2_ADV_inst (
  .CLKFBOUT     (CLKFB_int),         // 1-bit output: Feedback clock
  .CLKFBOUTB    (),       // 1-bit output: Inverted CLKFBOUT
  .CLKFBSTOPPED (), // 1-bit output: Feedback clock stopped
  .CLKINSTOPPED (), // 1-bit output: Input clock stopped
  .CLKOUT5      (CLKOUT5),           // 1-bit output: CLKOUT5
  .CLKOUT6      (CLKOUT6),           // 1-bit output: CLKOUT6
  .DO           (),                     // 16-bit output: DRP data output
  .DRDY         (),                 // 1-bit output: DRP ready
  .LOCKED       (locked),             // 1-bit output: LOCK
  .PSDONE       (),             // 1-bit output: Phase shift done
  .CLKFBIN      (CLKFB_int),           // 1-bit input: Feedback clock
  .CLKIN1       (clk),             // 1-bit input: Primary clock
  .CLKIN2       (1'b0),             // 1-bit input: Secondary clock
  .CLKINSEL     (1'b1),         // 1-bit input: Clock select, High=CLKIN1 Low=CLKIN2
  .DADDR        (7'h0),               // 7-bit input: DRP address
  .DCLK         (1'b0),                 // 1-bit input: DRP clock
  .DEN          (1'b0),                   // 1-bit input: DRP enable
  .DI           (16'h0),                     // 16-bit input: DRP data input
  .DWE          (1'b0),                   // 1-bit input: DRP write enable
  .PSCLK        (1'b0),               // 1-bit input: Phase shift clock
  .PSEN         (1'b0),                 // 1-bit input: Phase shift enable
  .PSINCDEC     (1'b0),         // 1-bit input: Phase shift increment/decrement
  .PWRDWN       (1'b0),             // 1-bit input: Power-down
  .RST          (1'b0)                    // 1-bit input: Reset
);
// Output buffering
BUFG u_mainclk (
  .O(main_clk),
  .I(CLKOUT5)
);

// Output buffering
BUFG u_ethclk (
  .O(eth_ref_clk),
  .I(CLKOUT6)
);

wire [12:0] s_axi_araddr;
wire        s_axi_arready;
wire        s_axi_arvalid;
wire [12:0] s_axi_awaddr;
wire        s_axi_awready;
wire        s_axi_awvalid;
wire        s_axi_bready;
wire  [1:0] s_axi_bresp;
wire        s_axi_bvalid;
wire [31:0] s_axi_rdata;
wire        s_axi_rready;
wire  [1:0] s_axi_rresp;
wire        s_axi_rvalid;
wire [31:0] s_axi_wdata;
wire        s_axi_wready;
wire  [3:0] s_axi_wstrb;
wire        s_axi_wvalid;
wire        eth_intr;

rmii_control u_rmii_control(
  .clk            (main_clk),
  .resetn         (resetn & locked),

  .m_axi_awaddr   (s_axi_awaddr),
  .m_axi_awready  (s_axi_awready),
  .m_axi_awvalid  (s_axi_awvalid),
  .m_axi_bready   (s_axi_bready),
  .m_axi_bresp    (s_axi_bresp),
  .m_axi_bvalid   (s_axi_bvalid),
  .m_axi_wdata    (s_axi_wdata),
  .m_axi_wready   (s_axi_wready),
  .m_axi_wstrb    (s_axi_wstrb),
  .m_axi_wvalid   (s_axi_wvalid),
  .m_axi_araddr   (s_axi_araddr),
  .m_axi_rdata    (s_axi_rdata),
  .m_axi_arready  (s_axi_arready),
  .m_axi_arvalid  (s_axi_arvalid),
  .m_axi_rready   (s_axi_rready),
  .m_axi_rvalid   (s_axi_rvalid),
  .m_axi_rresp    (s_axi_rresp),
  .eth_intr       (eth_intr),
  .led            (led)
);

wire rmii2mac_col, rmii2mac_crs, rmii2mac_rx_clk, rmii2mac_tx_clk,
    rmii2mac_rx_dv, rmii2mac_rx_er, mac2rmii_tx_en;
wire [3:0] rmii2mac_rxd, mac2rmii_txd;

axi_ethernetlite_0 u_eth(
  .s_axi_aclk     (main_clk),
  .s_axi_aresetn  (resetn & locked),
  .s_axi_araddr   (s_axi_araddr),
  .s_axi_arready  (s_axi_arready),
  .s_axi_arvalid  (s_axi_arvalid),
  .s_axi_awaddr   (s_axi_awaddr),
  .s_axi_awready  (s_axi_awready),
  .s_axi_awvalid  (s_axi_awvalid),
  .s_axi_bready   (s_axi_bready),
  .s_axi_bresp    (s_axi_bresp),
  .s_axi_bvalid   (s_axi_bvalid),
  .s_axi_rdata    (s_axi_rdata),
  .s_axi_rready   (s_axi_rready),
  .s_axi_rresp    (s_axi_rresp),
  .s_axi_rvalid   (s_axi_rvalid),
  .s_axi_wdata    (s_axi_wdata),
  .s_axi_wready   (s_axi_wready),
  .s_axi_wstrb    (s_axi_wstrb),
  .s_axi_wvalid   (s_axi_wvalid),

  .phy_col        (rmii2mac_col),
  .phy_crs        (rmii2mac_crs),
  .phy_rst_n      (eth_rst_n),
  .phy_rx_clk     (rmii2mac_rx_clk),
  .phy_dv         (rmii2mac_rx_dv),
  .phy_rx_er      (rmii2mac_rx_er),
  .phy_rx_data    (rmii2mac_rxd),
  .phy_tx_clk     (rmii2mac_tx_clk),
  .phy_tx_en      (mac2rmii_tx_en),
  .phy_tx_data    (mac2rmii_txd),
  .ip2intc_irpt   (eth_intr)
);

mii_to_rmii_0 u_mii_to_rmii(
  .ref_clk        (eth_ref_clk),
  .rst_n          (eth_rst_n),
  .rmii2mac_col   (rmii2mac_col),
  .rmii2mac_crs   (rmii2mac_crs),
  .rmii2mac_rx_clk(rmii2mac_rx_clk),
  .rmii2mac_rx_dv (rmii2mac_rx_dv),
  .rmii2mac_rx_er (rmii2mac_rx_er),
  .rmii2mac_rxd   (rmii2mac_rxd),
  .rmii2mac_tx_clk(rmii2mac_tx_clk),
  .mac2rmii_tx_en (mac2rmii_tx_en),
  .mac2rmii_tx_er (1'b0),
  .mac2rmii_txd   (mac2rmii_txd),

  .phy2rmii_crs_dv(eth_crs_dv),
  .phy2rmii_rx_er (1'b0),
  .phy2rmii_rxd   (eth_rxd),
  .rmii2phy_tx_en (eth_tx_en),
  .rmii2phy_txd   (eth_txd)
);

reg [7:0] led_reg;
always@(posedge main_clk or negedge resetn) begin
  if(!resetn) begin
    led_reg <= 8'h00;
  end else begin
    led_reg <= led;
  end
end
ila_0 u_ila(
  .clk(main_clk),
  .probe0(rmii2mac_rx_dv),
  .probe1(mac2rmii_tx_en),
  .probe2(rmii2mac_rxd),
  .probe3(mac2rmii_txd),
  .probe4(led_reg),
  .probe5(u_rmii_control.state),
  .probe6(u_rmii_control.next_state),
  .probe7(u_rmii_control.rmem_offset[30:0])
);
endmodule