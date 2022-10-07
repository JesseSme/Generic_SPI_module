library ieee;
use IEEE.std_logic_1164.all;

use work.spi_cs_generator;
use work.spi_sclk_generator;
use work.spi_sdio;

entity spi_top is
    generic (
        g_clk_freq : integer := 120_000_000;
        g_sclk_freq : integer := 1_000_000;
        g_cs_freq : integer := 1_600;
        g_device_count : integer := 18;
        g_address_width : integer := 6;
        g_write_data_width : integer := 8;
        g_spi_data_inout_buffer_size : integer := 8
    );
    port (
        -- CLK
        i_clk : in std_logic;
        i_rst : in std_logic;
        -- ENABLE
        i_en : in std_logic;
        -- DATA WIDTH
        i_data_width : in integer;
        -- SPI PINS
        data_io : inout std_logic_vector(g_device_count-1 downto 0);
        o_cs : out std_logic;
        o_sclk : out std_logic;
        -- DATA IN
        i_rw : in std_logic_vector(8-g_address_width-1 downto 0);
        i_address : in std_logic_vector(g_address_width-1 downto 0);
        i_data : in std_logic_vector(g_write_data_width-1 downto 0);
        -- DATA OUT
        o_data : out std_logic_vector(g_spi_data_inout_buffer_size-1 downto 0);
        -- DATA VALID
        o_spi_dv : out std_logic_vector(g_device_count-1 downto 0)
    );
end entity;

architecture structural of spi_top is    

    -- STATE MACHINE STATES
    type t_ctrl_state is (s_idle,
                        s_wait_dv,
                        s_done);
    signal s_ctrl_state : t_ctrl_state := s_idle;

    -- SCLK_GEN REGISTERS

    -- SDIO REGISTERS
    signal r_rw : std_logic_vector(8-g_address_width-1 downto 0);
    signal r_address : std_logic_vector(g_address_width-1 downto 0);

    -- DATA TO SEND
    signal r_data : std_logic_vector(g_write_data_width-1 downto 0) := (others => '0');

    -- DATA RECEIVED FROM SDIO
    signal r_data_width : integer := 0;
    signal r_data_received : std_logic_vector(g_spi_data_inout_buffer_size-1 downto 0) := (others => '0');


    -- CS_GEN REGISTERS
    -- DATA VALID FOR CS AND
    signal r_spi_dv : std_logic_vector(g_device_count-1 downto 0) := (others => '0');

    -- ENABLE REGISTER FOR CS
    signal r_cs : std_logic;
    signal r_sclk : std_logic;

begin

    r_rw <= i_rw;
    r_address <= i_address;
    r_data <= i_data;

    r_data_width <= i_data_width;

    o_sclk <= r_sclk;
    o_cs <= r_cs;
    o_data <= r_data_received;
    o_spi_dv <= r_spi_dv;

    CS_gen : entity spi_cs_generator
        generic map (
            g_clk_freq => g_clk_freq,
            g_cs_freq => g_cs_freq
            )
        port map (
            i_clk => i_clk,
            i_rst => i_rst,
            i_done => r_spi_dv(0),
            i_we => i_en,
            o_cs => r_cs);

    SCLK_gen : entity spi_sclk_generator
        generic map (
            g_clk_freq => g_clk_freq,
            g_sclk_freq => g_sclk_freq,
            g_address_width => 8
            )
        port map (
            i_clk => i_clk,
            i_rst => i_rst,
            i_cs => r_cs,
            o_sclk => r_sclk);

    -- TODO:  Add generate for multiple pins
    -- TODO: This shouldnt be duplicated. Instead the pins inside SPI_SDIO should be duplicated
    -- GEN_SPI_PINS : for i in 0 to 17 generate
        SPI_DATA_pin : entity spi_sdio
            generic map (
                g_clk_freq => g_clk_freq,
                g_sclk_freq => g_sclk_freq
                )
            port map (
                i_clk => i_clk,
                i_rst => i_rst,
                i_cs => r_cs,
                io_pin => data_io(0),
                i_data_width => r_data_width,
                i_rw => r_rw,
                i_address => r_address,
                i_data => r_data,
                o_data_received => r_data_received,
                o_spi_dv => r_spi_dv(0)
                );
    -- end generate;


    -- Process that reads the accelerators acceleration registers
    -- TODO: Add a delay to stall the reading of received data.
    p_data_ctrl : process (i_clk, i_rst)
        variable startup_sleep_counter : integer range 0 to g_clk_freq;
    begin
        if i_rst = '1' then
            s_ctrl_state <= s_idle;
        elsif rising_edge(i_clk) then

            case s_ctrl_state is

                when s_idle =>

                when s_wait_dv =>

                when s_done =>

            end case;
        end if;
    end process p_data_ctrl;

end architecture;