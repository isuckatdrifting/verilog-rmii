module rmii_control(
  input wire        clk,
  input wire        resetn,

    // AXI master for MII ethernetlite
 output reg  [31:0] m_axi_awaddr,
 output reg  [31:0] m_axi_wdata,
 output reg         m_axi_awvalid,
 output reg         m_axi_wvalid,
  input wire        m_axi_awready,
  input wire        m_axi_wready,
 output reg         m_axi_bready,
  input wire        m_axi_bvalid,
 output wire  [3:0] m_axi_wstrb,
 output wire  [1:0] m_axi_bresp,
 output reg  [31:0] m_axi_araddr,
  input wire [31:0] m_axi_rdata,
  input wire        m_axi_arready,
 output reg         m_axi_arvalid,
 output reg         m_axi_rready,
  input wire        m_axi_rvalid,
  input wire  [1:0] m_axi_rresp,
  input wire        eth_intr,
 
 output reg   [7:0] led
);

localparam CH_NUM = 32;

assign m_axi_wstrb = 4'hf;
assign m_axi_bresp = 2'b00;
(* dont_touch = "true" *) reg [3:0] state, next_state;
localparam  CTRL_IDLE = 0, CTRL_GIE = 1, CTRL_QUERYCFG = 2, CTRL_READCFG = 3, CTRL_SENDDATA = 4, CTRL_GAPTIME = 5;
// FSM jump signals
reg gie_done, query_done, readcfg_done, senddata_done, gaptime_done;
// axi ethernet transmit flow related registers
reg  [7:0] row_counter;
reg  [7:0] axi_traffic_cnt;
reg        axi_m_idle;
// axi ethernet read memory
localparam RMEM_BASE = 32'h0000_1000;
reg  [31:0] rmem_offset;
reg  [15:0] ip_length;

reg [15:0] gap_cnt;

always @(posedge clk or negedge resetn) begin
  if(!resetn) state <= CTRL_IDLE;
  else state <= next_state;
end

always @* begin
  case(state)
    // initializing
    CTRL_IDLE:          next_state = CTRL_GIE;
    CTRL_GIE:           next_state = gie_done? CTRL_QUERYCFG: CTRL_GIE;
    CTRL_QUERYCFG:      next_state = query_done? CTRL_READCFG: CTRL_QUERYCFG;
    CTRL_READCFG:       next_state = readcfg_done? CTRL_SENDDATA: CTRL_READCFG;
    // operating
    CTRL_SENDDATA:  if(senddata_done) begin
                      next_state = CTRL_GAPTIME;
                    end else begin
                      next_state = CTRL_SENDDATA;
                    end
    CTRL_GAPTIME:   if(gaptime_done) begin
                      next_state = CTRL_SENDDATA;
                    end else begin
                      next_state = CTRL_GAPTIME;
                    end
    default: next_state = CTRL_IDLE;
  endcase
end

always @(posedge clk or negedge resetn) begin
  if(!resetn) begin
    gie_done <= 0;
    query_done <= 0;
    readcfg_done <= 0;
    senddata_done <= 0;
    gaptime_done <= 0;
    gap_cnt <= 8'h00;

    row_counter <= 8'h00;
    axi_traffic_cnt <= 0;
    axi_m_idle <= 1;
    rmem_offset <= 0;
    ip_length <= 0;
    m_axi_awaddr <= 32'h0000_0000;
    m_axi_wdata <= 32'h0000_0000;
    m_axi_awvalid <= 0;
    m_axi_wvalid <= 0;
    m_axi_bready <= 0;
    m_axi_araddr <= 32'h0000_0000;
    m_axi_arvalid <= 0;
    m_axi_rready <= 0;
    led <= 8'h00;
  end else begin
    case(next_state)
/*0*/ CTRL_IDLE: begin
        gie_done <= 0;
        query_done <= 0;
        readcfg_done <= 0;
        senddata_done <= 0;
        gaptime_done <= 0;
        gap_cnt <= 8'h00;

        row_counter <= 8'h00;
        axi_traffic_cnt <= 0;
        axi_m_idle <= 1;
        rmem_offset <= 0;
        ip_length <= 0;
        m_axi_awaddr <= 32'h0000_0000;
        m_axi_wdata <= 32'h0000_0000;
        m_axi_awvalid <= 0;
        m_axi_wvalid <= 0;
        m_axi_bready <= 0;
        m_axi_araddr <= 32'h0000_0000;
        m_axi_arvalid <= 0;
        m_axi_rready <= 0;
        led <= 8'h00;
      end
/*1*/ CTRL_GIE: begin
        if(axi_m_idle) begin
          axi_m_idle <= 0;
          case(axi_traffic_cnt)
            0: begin
              m_axi_awaddr <= 32'h0000_07f8;
              m_axi_wdata <= 32'h8000_0000;
            end
            1: begin
              m_axi_awaddr <= 32'h0000_17fc;
              m_axi_wdata <= 32'h0000_0008;
            end
            default:;
          endcase
          m_axi_awvalid <= 1;
          m_axi_wvalid <= 1;
          m_axi_bready <= 1;
        end

        if(m_axi_awready) begin
          m_axi_awvalid <= 0;
        end
        if(m_axi_wready) begin
          m_axi_wvalid <= 0;
        end
        if(m_axi_bvalid) begin
          m_axi_bready <= 0;
          axi_m_idle <= 1;
          if(axi_traffic_cnt == 1) begin
            gie_done <= 1;
          end else begin
            axi_traffic_cnt <= axi_traffic_cnt + 1;
          end
        end
      end
/*2*/ CTRL_QUERYCFG: begin
        axi_traffic_cnt <= 0;
        if(eth_intr) begin
          query_done <= 1;
        end
      end
/*3*/ CTRL_READCFG: begin
        if(axi_m_idle) begin
          axi_m_idle <= 0;
          m_axi_araddr <= RMEM_BASE + rmem_offset;
          m_axi_arvalid <= 1;
          m_axi_rready <= 1;
        end
        if(m_axi_arready) m_axi_arvalid <= 0;
        if(m_axi_rvalid) begin
          m_axi_rready <= 0;
          axi_m_idle <= 1;
          rmem_offset <= rmem_offset + 4;
          if(rmem_offset == 'h10) begin
            ip_length <= m_axi_rdata[15:8];
          end 
          // decode UDP/IP packets
          if(rmem_offset >= 'h28) begin
            if(m_axi_rdata[31]) begin
              case(m_axi_rdata[30:24])
                7'h01: led <= m_axi_rdata[7:0];
                default:;
              endcase
            end
          end
          // 14 is the len of dst.mac(6B) + src.mac(6B) + type(2B), 4 stands for the len of each axi word transaction
          if(rmem_offset == ip_length + 14 - 4 && ip_length > 0) begin
            // assert readcfg_done after getting all configs
            readcfg_done <= 1;
          end
        end
      end
/*12*/CTRL_SENDDATA: begin
        // TODO: single point mode
        if(axi_m_idle) begin
          axi_m_idle <= 0;
          case(axi_traffic_cnt)
            0: begin // [31] ETH GIE
              m_axi_awaddr <= 32'h0000_07f8;
              m_axi_wdata <= 32'h8000_0000;
            end
            1: begin // [31:0] ETH TRANSMIT LENGTH
              m_axi_awaddr <= 32'h0000_07f4;
              m_axi_wdata <= 32'd42 + 32'd2 + (CH_NUM<<2); // (42 + 2byte padding + data.length)
            end
            2: begin // [31:0] dest mac address
              m_axi_awaddr <= 32'h0000_0000;
              m_axi_wdata <= 32'hffff_ffff;
            end
            3: begin // [15:0] dest mac address, [31:16] src mac address
              m_axi_awaddr <= 32'h0000_0004;
              m_axi_wdata <= 32'h0000_ffff;
            end
            4: begin // [31:0] src mac address 
              m_axi_awaddr <= 32'h0000_0008;
              m_axi_wdata <= 32'hcefa_005e;
            end
            5: begin // [15:0] eth.type, [23:16] ip.hdr_len, [31:24] ip.dsfield.ecn
              m_axi_awaddr <= 32'h0000_000c;
              m_axi_wdata <= 32'h0045_0008;
            end
            6: begin // [15:0] ip.len, [31:0] ip.id
              m_axi_awaddr <= 32'h0000_0010;                              // |-------seting HByte to 8'h00, assuming that data.length won't excceed 225 Bytes
              m_axi_wdata <= 32'h0100_0000 + {16'h0000, 8'd30+(CH_NUM<<2), 8'h00}; // (28 + 2byte padding + data.length), [7:0]HByte, [15:8]LByte
            end
            7: begin // [15:0] ip.frag_offset, [23:16] ip.ttl, [31:24] ip.ttl
              m_axi_awaddr <= 32'h0000_0014;
              m_axi_wdata <= 32'h1180_0040;
            end
            8: begin // [15:0] ip.checksum, [31:16] ip.src
              m_axi_awaddr <= 32'h0000_0018;
              m_axi_wdata <= 32'ha8c0_8472;
            end
            9: begin // [15:0] ip.src, [31:16] ip.dst
              m_axi_awaddr <= 32'h0000_001c;
              m_axi_wdata <= 32'ha8c0_7b03;
            end
            10: begin // [15:0] ip.dst, [31:16] udp.srcport
              m_axi_awaddr <= 32'h0000_0020;
              m_axi_wdata <= 32'hd204_6603;
            end
            11: begin // [15:0] udp.dstport, [31:16] udp.length
              m_axi_awaddr <= 32'h0000_0024;
              m_axi_wdata <= 32'h0000_d204 + {8'd10+(CH_NUM<<2), 8'h00, 16'h0000}; // (8 + 2byte padding + data.length), [23:16]HByte, [31:24]LByte
            end
            12: begin // [15:0] udp.checksum, [31:16] padding(2 Byte no use in data field)
              m_axi_awaddr <= 32'h0000_0028;
              m_axi_wdata <= 32'h0000_0000;
            end
            13+CH_NUM: begin // ETH TRANSMIT CONTROL
              m_axi_awaddr <= 32'h0000_07fc;
              m_axi_wdata <= 32'h0000_0009;
            end
            14+CH_NUM: begin // ETH TRANSMIT CONTROL
              m_axi_awaddr <= 32'h0000_07fc;
              m_axi_wdata <= 32'h0000_0008;
            end
            15+CH_NUM: begin // ETH READ
              m_axi_awaddr <= 32'h0000_17fc;
              m_axi_wdata <= 32'h0000_0001;
            end
            default: begin // user data field, from 13 to 13+CH_NUM-1
              m_axi_awaddr <= row_counter; // send packets
              // SERIALIZE through CH_NUM channels
              row_counter <= row_counter + 1;
              m_axi_awaddr <= 32'h0000_002c + (row_counter << 2);
              m_axi_wdata <= m_axi_wdata + 1;
            end
          endcase
          m_axi_awvalid <= 1;
          m_axi_wvalid <= 1;
          m_axi_bready <= 1;
        end

        if(m_axi_awready) begin
          m_axi_awvalid <= 0;
        end
        if(m_axi_wready) begin
          m_axi_wvalid <= 0;
        end
        if(m_axi_bvalid) begin
          m_axi_bready <= 0;
          axi_m_idle <= 1;
          if(axi_traffic_cnt == 15+CH_NUM) begin
            //TODO: add delay counter
            senddata_done <= 1;
            row_counter <= 0;
            axi_traffic_cnt <= 0;
          end else begin
            axi_traffic_cnt <= axi_traffic_cnt + 1;
          end
        end
        gap_cnt <= 0;
        gaptime_done <= 0;
      end
      CTRL_GAPTIME: begin
        senddata_done <= 0;
        if(gap_cnt < 2000) begin
          gap_cnt <= gap_cnt + 1;
        end else begin
          gap_cnt <= 0;
          gaptime_done <= 1;
        end
      end
      default:;
    endcase
  end
end

endmodule