library ieee;
use ieee.std_logic_1164.all;

entity spi_sclk_generator is
    generic (
        g_clk_freq : integer := 120_000_000;
        g_sclk_freq : integer := 1_000_000;
        g_address_width : integer := 7;
        g_max_data_width : integer := 64 + 8
        );
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_cs : in std_logic;
        i_data_width : in integer;
        o_sclk : out std_logic
        );
end entity;


architecture rtl of spi_sclk_generator is

    type t_sclk_state is (s_idle, s_do_sclk);
    signal s_sclk_state : t_sclk_state := s_idle;

    constant c_sclk_freq : integer := (g_clk_freq/g_sclk_freq);
    constant c_half_sclk : integer := (c_sclk_freq/2);
    constant c_dw_x2 : integer := (g_max_data_width*2);

    signal r_half_sclk_counter : integer range 0 to c_half_sclk := 0;

    signal r_data_width : integer;

    signal r_cs : std_logic;
    signal r_sclk : std_logic := '1';
    signal r_sclk_edge_counter : integer range 0 to c_dw_x2 := c_dw_x2;

begin

    -- IN SIGNALS
    r_cs <= i_cs;
    r_data_width <= i_data_width*2 when i_data_width*2 < c_dw_x2 else c_dw_x2;

    -- OUT SIGNALS
    o_sclk <= r_sclk;

    p_generate_sclk : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_sclk <= '1';
            r_half_sclk_counter <= 0;
            r_sclk_edge_counter <= 0;
            s_sclk_state <= s_idle;
        elsif rising_edge(i_clk) then

            case s_sclk_state is

                -- Wait until CS goes down
                when s_idle =>
                    r_sclk <= '1';
                    r_half_sclk_counter <= 0;
                    r_sclk_edge_counter <= 0;
                    if r_cs = '0' then
                        r_sclk <= not r_sclk;
                        r_sclk_edge_counter <= r_sclk_edge_counter + 1;
                        s_sclk_state <= s_do_sclk;
                    else
                        s_sclk_state <= s_idle;
                    end if;


                when s_do_sclk =>
                    -- Count up until half sclk speed
                    if r_cs = '1' then
                        s_sclk_state <= s_idle;
                    else
                        r_half_sclk_counter <= r_half_sclk_counter + 1;
                        if r_half_sclk_counter = c_half_sclk then
                            -- r_data_index <= r_data_index + 1;
                            if r_sclk_edge_counter = r_data_width then
                                r_sclk <= '1';
                            else
                                r_sclk_edge_counter <= r_sclk_edge_counter + 1;
                                r_half_sclk_counter <= 0;
                                r_sclk <= not r_sclk;
                            end if;
                        end if;
                    end if;
            end case;
        end if;
    end process p_generate_sclk;
    
end architecture rtl;