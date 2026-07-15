-------------------------------------------------------------------------------
--
-- Copyright Missing Link Electronics Inc. (C) 2026
-- ALL RIGHTS RESERVED/UNPUBLISHED WORK
--
-- This software shall not be reproduced without the express
-- written permission of Missing Link Electronics, Inc.
--
--      Missing Link Electronics, Inc.
--      2880 Zanker Road, Suite 203
--      San Jose, CA 95134
--
--      https://www.missinglinkelectronics.com
--
-- Licensed in accordance to your Proof-of-License
-- and https://www.missinglinkelectronics.com/US-license
--
-------------------------------------------------------------------------------
--
-- File Name: axi4_dummy_master.vhd
--
-------------------------------------------------------------------------------
--
-- File Summary: Inactive AXI4 Master interfaces for BD AXI4 Slave interfaces
--
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- libraries
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- entity
-------------------------------------------------------------------------------
entity axi4_dummy_master is
generic (
    VERSION_MAJOR : integer range 1 to 1 := 1;
    VERSION_MINOR : integer range 0 to 0 := 0;
    VERSION_PATCH : integer range 0 to 0 := 0;
    -- AXI4 interface select: 0 - AXI4-Lite, 1 - AXI4-Stream, 2 - AXI4
    AXI4_INTERFACE : integer range 0 to 2 := 0;
    -- AXI4-Lite or AXI4 generics
    ADDR_WIDTH : integer range 12 to 64 := 12;
    DATA_WIDTH : integer range 1 to 4095 := 32;
    -- AXI4-Stream generics
    TDATA_WIDTH : integer range 1 to 4095 := 32;
    TUSER_WIDTH : integer range 1 to 4095 := 32;
    TDEST_WIDTH : integer range 1 to 4095 := 32
);
port (
    axi_aclk_in : in std_logic;
    axi_aresetn_in : in std_logic;

    -- AXI4-Lite dummy Master interface
    m_axil_awaddr_out : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    m_axil_awprot_out : out std_logic_vector(2 downto 0);
    m_axil_awvalid_out : out std_logic;
    m_axil_awready_in : in std_logic;

    m_axil_wdata_out : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_axil_wstrb_out : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
    m_axil_wvalid_out : out std_logic;
    m_axil_wready_in : in std_logic;

    m_axil_bresp_in : in std_logic_vector(1 downto 0);
    m_axil_bvalid_in : in std_logic;
    m_axil_bready_out : out std_logic;

    m_axil_araddr_out : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    m_axil_arprot_out : out std_logic_vector(2 downto 0);
    m_axil_arvalid_out : out std_logic;
    m_axil_arready_in : in std_logic;

    m_axil_rdata_in : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_axil_rresp_in : in std_logic_vector(1 downto 0);
    m_axil_rvalid_in : in std_logic;
    m_axil_rready_out : out std_logic;

    -- AXI4-Stream dummy Master interface
    m_axis_tdata_out : out std_logic_vector(TDATA_WIDTH - 1 downto 0);
    m_axis_tkeep_out : out std_logic_vector((TDATA_WIDTH / 8) - 1 downto 0);
    m_axis_tuser_out : out std_logic_vector(TUSER_WIDTH - 1 downto 0);
    m_axis_tdest_out : out std_logic_vector(TDEST_WIDTH - 1 downto 0);
    m_axis_tlast_out : out std_logic;
    m_axis_tvalid_out : out std_logic;
    m_axis_tready_in : in std_logic;

    -- AXI4 dummy Master interface
    m_axi_awaddr_out : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    m_axi_awburst_out : out std_logic_vector(1 downto 0);
    m_axi_awcache_out : out std_logic_vector(3 downto 0);
    m_axi_awid_out : out std_logic;
    m_axi_awlen_out : out std_logic_vector(7 downto 0);
    m_axi_awlock_out : out std_logic;
    m_axi_awprot_out : out std_logic_vector(2 downto 0);
    m_axi_awqos_out : out std_logic_vector(3 downto 0);
    m_axi_awsize_out : out std_logic_vector(2 downto 0);
    m_axi_awvalid_out : out std_logic;
    m_axi_awready_in : in std_logic;

    m_axi_wdata_out : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_axi_wstrb_out : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
    m_axi_wlast_out : out std_logic;
    m_axi_wvalid_out : out std_logic;
    m_axi_wready_in : in std_logic;

    m_axi_bresp_in : in std_logic_vector(1 downto 0);
    m_axi_bid_in : in std_logic;
    m_axi_bvalid_in : in std_logic;
    m_axi_bready_out : out std_logic;

    m_axi_araddr_out : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
    m_axi_arburst_out : out std_logic_vector(1 downto 0);
    m_axi_arcache_out : out std_logic_vector(3 downto 0);
    m_axi_arid_out : out std_logic;
    m_axi_arlen_out : out std_logic_vector(7 downto 0);
    m_axi_arlock_out : out std_logic;
    m_axi_arprot_out : out std_logic_vector(2 downto 0);
    m_axi_arqos_out : out std_logic_vector(3 downto 0);
    m_axi_arsize_out : out std_logic_vector(2 downto 0);
    m_axi_arvalid_out : out std_logic;
    m_axi_arready_in : in std_logic;

    m_axi_rdata_in : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    m_axi_rresp_in : in std_logic_vector(1 downto 0);
    m_axi_rid_in : in std_logic;
    m_axi_rlast_in : in std_logic;
    m_axi_rvalid_in : in std_logic;
    m_axi_rready_out : out std_logic
);
end entity;

-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture behavioral of axi4_dummy_master is

-------------------------------------------------------------------------------
-- constants / types / signals / attributes / functions
-------------------------------------------------------------------------------
attribute X_INTERFACE_INFO : string;
attribute X_INTERFACE_PARAMETER : string;
attribute X_INTERFACE_MODE : STRING;

-- clock
attribute X_INTERFACE_INFO of axi_aclk_in : signal is "xilinx.com:signal:clock:1.0 AXI_ACLK CLK";
attribute X_INTERFACE_PARAMETER of axi_aclk_in : signal is "ASSOCIATED_BUSIF M_AXIS:M_AXIL:M_AXIF, ASSOCIATED_RESET axi_aresetn_in";

-- reset
attribute X_INTERFACE_INFO of axi_aresetn_in : signal is "xilinx.com:signal:reset:1.0 AXI_ARESETN RST";
attribute X_INTERFACE_PARAMETER of axi_aresetn_in : signal is "POLARITY ACTIVE_LOW";

-- AXI4-Lite dummy Master Interface
attribute X_INTERFACE_INFO of m_axil_awaddr_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL AWADDR";
attribute X_INTERFACE_INFO of m_axil_awvalid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL AWVALID";
attribute X_INTERFACE_INFO of m_axil_awready_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL AWREADY";
attribute X_INTERFACE_INFO of m_axil_wdata_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL WDATA";
attribute X_INTERFACE_INFO of m_axil_wstrb_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL WSTRB";
attribute X_INTERFACE_INFO of m_axil_wvalid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL WVALID";
attribute X_INTERFACE_INFO of m_axil_wready_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL WREADY";
attribute X_INTERFACE_INFO of m_axil_bresp_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL BRESP";
attribute X_INTERFACE_INFO of m_axil_bvalid_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL BVALID";
attribute X_INTERFACE_INFO of m_axil_bready_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL BREADY";
attribute X_INTERFACE_INFO of m_axil_araddr_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL ARADDR";
attribute X_INTERFACE_INFO of m_axil_arvalid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL ARVALID";
attribute X_INTERFACE_INFO of m_axil_arready_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL ARREADY";
attribute X_INTERFACE_INFO of m_axil_rdata_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL RDATA";
attribute X_INTERFACE_INFO of m_axil_rresp_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL RRESP";
attribute X_INTERFACE_INFO of m_axil_rvalid_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIL RVALID";
attribute X_INTERFACE_INFO of m_axil_rready_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIL RREADY";

-- AXI4-Stream dummy Master Interface
attribute X_INTERFACE_INFO of m_axis_tdata_out : signal is "xilinx.com:interface:axis:1.0 M_AXIS TDATA";
attribute X_INTERFACE_INFO of m_axis_tkeep_out : signal is "xilinx.com:interface:axis:1.0 M_AXIS TKEEP";
attribute X_INTERFACE_INFO of m_axis_tuser_out : signal is "xilinx.com:interface:axis:1.0 M_AXIS TUSER";
attribute X_INTERFACE_INFO of m_axis_tdest_out : signal is "xilinx.com:interface:axis:1.0 M_AXIS TDEST";
attribute X_INTERFACE_INFO of m_axis_tlast_out : signal is "xilinx.com:interface:axis:1.0 M_AXIS TLAST";
attribute X_INTERFACE_INFO of m_axis_tvalid_out : signal is "xilinx.com:interface:axis:1.0 M_AXIS TVALID";
attribute X_INTERFACE_INFO of m_axis_tready_in : signal is "xilinx.com:interface:axis:1.0 M_AXIS TREADY";

-- AXI4 dummy Master Interface
attribute X_INTERFACE_INFO of m_axi_awaddr_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWADDR";
attribute X_INTERFACE_INFO of m_axi_awburst_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWBURST";
attribute X_INTERFACE_INFO of m_axi_awcache_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWCACHE";
attribute X_INTERFACE_INFO of m_axi_awid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWID";
attribute X_INTERFACE_INFO of m_axi_awlen_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWLEN";
attribute X_INTERFACE_INFO of m_axi_awlock_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWLOCK";
attribute X_INTERFACE_INFO of m_axi_awprot_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWPROT";
attribute X_INTERFACE_INFO of m_axi_awqos_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWQOS";
attribute X_INTERFACE_INFO of m_axi_awsize_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWSIZE";
attribute X_INTERFACE_INFO of m_axi_awvalid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWVALID";
attribute X_INTERFACE_INFO of m_axi_awready_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF AWREADY";
attribute X_INTERFACE_INFO of m_axi_wdata_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF WDATA";
attribute X_INTERFACE_INFO of m_axi_wstrb_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF WSTRB";
attribute X_INTERFACE_INFO of m_axi_wlast_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF WLAST";
attribute X_INTERFACE_INFO of m_axi_wvalid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF WVALID";
attribute X_INTERFACE_INFO of m_axi_wready_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF WREADY";
attribute X_INTERFACE_INFO of m_axi_bresp_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF BRESP";
attribute X_INTERFACE_INFO of m_axi_bid_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF BID";
attribute X_INTERFACE_INFO of m_axi_bvalid_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF BVALID";
attribute X_INTERFACE_INFO of m_axi_bready_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF BREADY";
attribute X_INTERFACE_INFO of m_axi_araddr_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARADDR";
attribute X_INTERFACE_INFO of m_axi_arburst_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARBURST";
attribute X_INTERFACE_INFO of m_axi_arcache_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARCACHE";
attribute X_INTERFACE_INFO of m_axi_arid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARID";
attribute X_INTERFACE_INFO of m_axi_arlen_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARLEN";
attribute X_INTERFACE_INFO of m_axi_arlock_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARLOCK";
attribute X_INTERFACE_INFO of m_axi_arprot_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARPROT";
attribute X_INTERFACE_INFO of m_axi_arqos_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARQOS";
attribute X_INTERFACE_INFO of m_axi_arsize_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARSIZE";
attribute X_INTERFACE_INFO of m_axi_arvalid_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARVALID";
attribute X_INTERFACE_INFO of m_axi_arready_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF ARREADY";
attribute X_INTERFACE_INFO of m_axi_rdata_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF RDATA";
attribute X_INTERFACE_INFO of m_axi_rresp_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF RRESP";
attribute X_INTERFACE_INFO of m_axi_rid_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF RID";
attribute X_INTERFACE_INFO of m_axi_rlast_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF RLAST";
attribute X_INTERFACE_INFO of m_axi_rvalid_in : signal is "xilinx.com:interface:aximm:1.0 M_AXIF RVALID";
attribute X_INTERFACE_INFO of m_axi_rready_out : signal is "xilinx.com:interface:aximm:1.0 M_AXIF RREADY";

begin

-------------------------------------------------------------------------------
-- assignments
-------------------------------------------------------------------------------
-- AXI4-Lite dummy Master interface
m_axil_awaddr_out <= (others => '0');
m_axil_awvalid_out <= '0';

m_axil_wdata_out <= (others => '0');
m_axil_wstrb_out <= (others => '0');
m_axil_wvalid_out <= '0';

m_axil_bready_out <= '1';

m_axil_araddr_out <= (others => '0');
m_axil_arvalid_out <= '0';

m_axil_rready_out <= '1';

-- AXI4-Stream dummy Master interface
m_axis_tdata_out <= (others => '0');
m_axis_tkeep_out <= (others => '0');
m_axis_tuser_out <= (others => '0');
m_axis_tdest_out <= (others => '0');
m_axis_tlast_out <= '0';
m_axis_tvalid_out <= '0';

-- AXI4 dummy Master interface
m_axi_awaddr_out <= (others => '0');
m_axi_awburst_out <= (others => '0');
m_axi_awcache_out <= (others => '0');
m_axi_awid_out <= '0';
m_axi_awlen_out <= (others => '0');
m_axi_awlock_out <= '0';
m_axi_awprot_out <= (others => '0');
m_axi_awqos_out <= (others => '0');
m_axi_awsize_out <= (others => '0');
m_axi_awvalid_out <= '0';

m_axi_wdata_out <= (others => '0');
m_axi_wstrb_out <= (others => '0');
m_axi_wlast_out <= '0';
m_axi_wvalid_out <= '0';

m_axi_bready_out <= '1';

m_axi_araddr_out <= (others => '0');
m_axi_arburst_out <= (others => '0');
m_axi_arcache_out <= (others => '0');
m_axi_arid_out <= '0';
m_axi_arlen_out <= (others => '0');
m_axi_arlock_out <= '0';
m_axi_arprot_out <= (others => '0');
m_axi_arqos_out <= (others => '0');
m_axi_arsize_out <= (others => '0');
m_axi_arvalid_out <= '0';

m_axi_rready_out <= '1';

end architecture;

