library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity jese_spi is
    generic (
        g_CLK_FREQ : integer := 100_000_000;
        g_SCLK_FREQ : integer := 2_000_000;
        g_REGISTER_DATA_WIDTH : integer := 32;
        g_BUFFER_WIDTH : integer := 64
    );
    port (
        -- CLK RST
        i_CLK : in std_logic;
        i_RST : in std_logic;
        -- INCOMING DATA
        i_REGISTER : in std_logic_vector(g_REGISTER_DATA_WIDTH-1 downto 0);
        -- SPI
        i_SDI : in std_logic;
        o_SDO : out std_logic;
        o_SCLK : out std_logic;
        o_CS : out std_logic;
        -- OUTGOING DATA
        --
        o_SPI_DONE : out std_logic;
        o_REGISTER1 : out std_logic_vector(g_REGISTER_DATA_WIDTH-1 downto 0);
        o_REGISTER2 : out std_logic_vector(g_REGISTER_DATA_WIDTH-1 downto 0)
    );
end entity jese_spi;

architecture rtl of jese_spi is

    -- Types
    type t_SPI_STATE is (s_IDLE, s_DO_SCLK, s_DONE, s_WAIT_ENABLE);
    signal s_SPI_STATE : t_SPI_STATE := s_IDLE;

    -- Constants
    constant c_SCLK_CLK_CYCLES : integer := (g_CLK_FREQ/g_SCLK_FREQ);
    constant c_SCLK_CLK_CYCLES_HALF : integer := (c_SCLK_CLK_CYCLES/2);
    constant c_SCLK_EDGES_MAX : integer := 128;

    -- SPI Signals
    signal s_ENABLE : std_logic := '0';
    signal s_CS : std_logic := '1';
    signal s_SCLK : std_logic := '1';
    signal s_SDO : std_logic := '1';
    signal s_SDI : std_logic;

    -- SPI data registers
    signal s_SPI_DONE : std_logic := '0';
    signal s_ADDRESS : std_logic_vector(7 downto 0) := (others => '0');
    signal s_TX_BUFFER : std_logic_vector(g_BUFFER_WIDTH-1 downto 0) := (others => '0');
    signal s_RX_BUFFER : std_logic_vector(g_BUFFER_WIDTH-1 downto 0) := (others => '0');
    signal s_BYTES_TO_READ_UNSIGNED : unsigned(7 downto 0) := (others => '0');

    -- Helper registers
    signal s_EDGES_INT : integer := 0;
    signal s_EDGES_BOTTOM_INT : integer := 0;
    signal s_COUNTER_INT : integer := 0;
    signal s_ADDRESS_COUNTER : integer := 0;
    signal s_DATA_COUNTER : integer := 0;
    signal slv_reg12 : std_logic_vector(g_BUFFER_WIDTH-1 downto 0);

begin

    -- Start signal
    s_ENABLE <= i_REGISTER(24);

    -- SPI signal mapping
    o_CS <= s_CS;
    o_SCLK <= s_SCLK;
    o_SDO <= s_SDO;
    s_SDI <= i_SDI;
--    o_CS <= i_REGISTER(24);
--    o_SCLK <= i_REGISTER(16);
--    o_SDO <= i_REGISTER(8);
--    s_SDI <= i_SDI;
    
    o_REGISTER1 <= slv_reg12(63 downto 32);
    o_REGISTER2 <= slv_reg12(31 downto 0);


--    -- Chip Select process
    CS_proc : process(i_CLK, i_RST)
    begin
        if i_RST = '0' then
            s_CS <= '1';
        elsif rising_edge(i_CLK) then
            if s_ENABLE = '1' then
                s_CS <= '0';
            else
                s_CS <= '1';
            end if; -- s_ENABLE
        end if; -- i_RST
    end process CS_proc;

    -- SCLK process
    SPI_proc : process(i_CLK, i_RST)
        -- variable v_DATA_SHIFT_HELPER : std_logic_vector(7 downto 0);
        -- variable v_DATA_INDEX : integer := 0;
        -- variable v_TX_BUFFER : std_logic_vector(g_BUFFER_WIDTH-1 downto 0) := (others => '0');
    begin
        if i_RST = '0' then
            s_SCLK <= '1';
            s_SDO <= '1';
            s_SPI_DONE <= '0';
            s_EDGES_INT <= 0;
            s_EDGES_BOTTOM_INT <= 0;
        elsif rising_edge(i_CLK) then
            case s_SPI_STATE is

                -- s_IDLE
                when s_IDLE =>
                    s_SCLK <= '1';
                    s_EDGES_INT <= 0;
                    s_COUNTER_INT <= 0;

                    if s_CS = '0' then
                        s_EDGES_INT <= c_SCLK_EDGES_MAX;
                        if to_integer(s_BYTES_TO_READ_UNSIGNED) >= 6 then
                            s_EDGES_BOTTOM_INT  <= (c_SCLK_EDGES_MAX-(6*16+16));
                        else
                            s_EDGES_BOTTOM_INT  <= (c_SCLK_EDGES_MAX-(to_integer(s_BYTES_TO_READ_UNSIGNED)*16+16));
                        end if;
                        s_TX_BUFFER(g_BUFFER_WIDTH-1 downto g_BUFFER_WIDTH-(2*8)) <= i_REGISTER(23 downto 16) & i_REGISTER(15 downto 8);
                        s_BYTES_TO_READ_UNSIGNED <= unsigned(i_REGISTER(7 downto 0));
                        s_SPI_STATE        <= s_DO_SCLK;

                    else -- s_CS
                        s_SPI_STATE <= s_IDLE;
                    end if; -- s_CS
                -- s_IDLE
                
                -- s_DO_SCLK
                when s_DO_SCLK =>
                    if s_EDGES_INT = s_EDGES_BOTTOM_INT then
                        s_SPI_STATE <= s_DONE;
                    else
                        if s_COUNTER_INT = 0 then
                            s_SCLK <= not s_SCLK;
                            s_COUNTER_INT <= c_SCLK_CLK_CYCLES_HALF;
                            s_EDGES_INT <= s_EDGES_INT - 1;

                            if s_SCLK = '0' then
                                s_SDO <= s_TX_BUFFER(g_BUFFER_WIDTH-1);
                                s_TX_BUFFER <= s_TX_BUFFER(g_BUFFER_WIDTH-2 downto 0) & '0';
                            end if;

                            if s_SCLK = '1' then
                                s_RX_BUFFER <= s_RX_BUFFER(g_BUFFER_WIDTH-2 downto 0) & s_SDI;
                            end if;
                        else
                            s_COUNTER_INT <= s_COUNTER_INT - 1;
                            s_SPI_STATE <= s_DO_SCLK;
                        end if; -- s_COUNTER_INT
                    end if; -- s_EDGES_INT
                -- s_DO_SCLK

                when s_DONE =>
                    s_SPI_DONE <= '1';
                    slv_reg12 <= s_RX_BUFFER;
                    s_SPI_STATE <= s_WAIT_ENABLE;

                when s_WAIT_ENABLE =>
                    s_SPI_DONE <= '0';
                    if s_ENABLE = '0' then
                        s_SPI_STATE <= s_IDLE;
                    else
                        s_SPI_STATE <= s_WAIT_ENABLE;
                    end if;
                    
                    
            end case; -- s_SPI_STATE
        end if; -- i_RST
    end process SPI_proc;

    

end architecture;