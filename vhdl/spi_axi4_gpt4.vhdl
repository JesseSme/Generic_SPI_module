library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SPI_Master_AXI4 is
    Generic (
        NUM_SENSORS : integer := 4;
        SCLK_SPEED : integer := 1000000
    );
    Port (
        -- AXI4 Interface
        axi_clk     : in  STD_LOGIC;
        axi_resetn  : in  STD_LOGIC;
        axi_awaddr  : in  STD_LOGIC_VECTOR (31 downto 0);
        axi_awvalid : in  STD_LOGIC;
        axi_awready : out STD_LOGIC;
        axi_wdata   : in  STD_LOGIC_VECTOR (31 downto 0);
        axi_wstrb   : in  STD_LOGIC_VECTOR (3 downto 0);
        axi_wvalid  : in  STD_LOGIC;
        axi_wready  : out STD_LOGIC;
        axi_bresp   : out STD_LOGIC_VECTOR (1 downto 0);
        axi_bvalid  : out STD_LOGIC;
        axi_bready : in STD_LOGIC;
        axi_araddr : in STD_LOGIC_VECTOR (31 downto 0);
        axi_arvalid : in STD_LOGIC;
        axi_arready : out STD_LOGIC;
        axi_rdata : out STD_LOGIC_VECTOR (31 downto 0);
        axi_rresp : out STD_LOGIC_VECTOR (1 downto 0);
        axi_rvalid : out STD_LOGIC;
        axi_rready : in STD_LOGIC;
        -- SPI Interface
        sclk        : out STD_LOGIC;
        cs          : out STD_LOGIC;
        sdio        : inout STD_LOGIC_VECTOR (NUM_SENSORS - 1 downto 0)
    );
end SPI_Master_AXI4;


architecture Behavioral of SPI_Master_AXI4 is
    -- Internal signals and constants
    constant SCLK_PERIOD : integer := (1 / SCLK_SPEED) * 1_000_000_000; -- SCLK period in ns
    signal sclk_internal : STD_LOGIC := '0';
    signal spi_state : integer := 0;
    signal data_buffer : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    type sensor_data_array is array (0 to NUM_SENSORS - 1) of STD_LOGIC_VECTOR (31 downto 0);
    signal sensor_data_buffer : sensor_data_array := (others => (others => '0'));

    signal data_index : integer := 0;
begin
    -- SCLK generation
    process (axi_clk)
    begin
        if rising_edge(axi_clk) then
            if sclk_internal = '0' then
                sclk_internal <= '1';   
            else
                sclk_internal <= '0';
            end if;
        end if;
    end process;
    -- Assign sclk_internal to sclk
    sclk <= sclk_internal;

    -- SPI state machine
    process (axi_clk, axi_resetn)
    begin
        if axi_resetn = '0' then
            spi_state <= 0;
        elsif rising_edge(axi_clk) then
            case spi_state is
                when 0 =>
                    -- Idle state
                    if axi_awvalid = '1' and axi_wvalid = '1' then
                        data_buffer <= axi_wdata;
                        data_index <= 0;
                        spi_state <= 1;
                    elsif axi_arvalid = '1' then
                        spi_state <= 2;
                    end if;

                    when 1 =>
                    -- Write state
                    for i in 0 to NUM_SENSORS - 1 loop
                        cs <= '0';
                        sdio(i) <= sensor_data_buffer(i)(31 - data_index);
                    end loop;
                    data_index <= data_index + 1;
                    if data_index = 32 then
                        spi_state <= 0;
                    else
                        spi_state <= 1;
                    end if;
                
                when 2 =>
                    -- Read state
                    for i in 0 to NUM_SENSORS - 1 loop
                        cs <= '0';
                        sensor_data_buffer(i)(31 - data_index) <= sdio(i);
                    end loop;
                    data_index <= data_index + 1;
                    if data_index = 32 then
                        spi_state <= 0;
                    else
                        spi_state <= 2;
                    end if;
        
                    when others =>
                        spi_state <= 0;
        
                end case;
            end if;
        end process;
        
    -- AXI4 Write and Read control logic
    process (axi_clk, axi_resetn)
    begin
        if axi_resetn = '0' then
            axi_awready <= '0';
            axi_wready <= '0';
            axi_bresp <= "00";
            axi_bvalid <= '0';
            axi_arready <= '0';
            axi_rdata <= (others => '0');
            axi_rresp <= "00";
            axi_rvalid <= '0';
        elsif rising_edge(axi_clk) then
            axi_awready <= axi_awvalid;
            axi_wready <= axi_wvalid;
            axi_bresp <= "00";
            axi_bvalid <= axi_awvalid and axi_wvalid;
            axi_arready <= axi_arvalid;
    
            -- Select the sensor data based on axi_araddr
            if axi_arvalid = '1' and axi_rready = '1' then
                axi_rdata <= sensor_data_buffer(to_integer(unsigned(axi_araddr(1 downto 0))));
            else
                axi_rdata <= (others => '0');
            end if;
    
            axi_rresp <= "00";
            axi_rvalid <= axi_arvalid;
        end if;
    end process;
    
    -- Chip Select control
    process (axi_clk, axi_resetn)
    begin
        if axi_resetn = '0' then
            cs <= '1';
        elsif rising_edge(axi_clk) then
            if spi_state = 1 or spi_state = 2 then
                cs <= '0';
            else
                cs <= '1';
            end if;
        end if;
    end process;
end Behavioral;