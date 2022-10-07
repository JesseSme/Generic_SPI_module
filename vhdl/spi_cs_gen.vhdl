library ieee;
use ieee.std_logic_1164.all;

entity spi_cs_generator is
    generic (
        g_clk_freq : integer := 120_000_000;
        g_cs_freq  : integer := 1600
    );
    port (
        i_clk  : in std_logic;
        i_rst  : in std_logic;
        i_done : in std_logic;
        i_we   : in std_logic;
        o_cs   : out std_logic
    );
end entity;
architecture rtl of spi_cs_generator is

    type t_cs_state is (s_idle, s_cs, s_cs_deassertion);
    signal s_cs_state : t_cs_state := s_idle;

    -- Amount of clock cycles between pulling CS down
    constant c_cs_freq            : integer := (g_clk_freq/g_cs_freq);
    constant c_clk_in_ns          : integer := (1_000_000_000/g_clk_freq);
    constant c_cs_deassertion_max : integer := (150/c_clk_in_ns) + 5;

    signal r_cs_counter : integer range 0 to c_cs_freq := 0;

    signal r_cs   : std_logic := '1';
    signal r_done : std_logic;
    signal r_we   : std_logic;

begin
    o_cs   <= r_cs;
    r_done <= i_done;
    r_we   <= i_we;
    p_generate_cs : process (i_clk, i_rst)
        -- Clock cycles between reads. MIN 150ns
        variable v_deassertation_counter : integer range 0 to c_cs_deassertion_max := 0;
    begin
        if i_rst = '1' then
            v_deassertation_counter := 0;
            r_cs_counter <= 0;
            r_cs         <= '1';
            s_cs_state   <= s_idle;
        elsif rising_edge(i_clk) then
            case s_cs_state is
                when s_idle =>
                    if r_we = '1' then
                        r_cs <= '1';
                        if r_cs_counter = c_cs_freq then
                            r_cs_counter <= 0;
                            s_cs_state   <= s_cs;
                        else
                            r_cs_counter <= r_cs_counter + 1;
                        end if;
                    else
                        r_cs_counter <= 0;
                        r_cs         <= '1';
                    end if;

                when s_cs =>
                    r_cs <= '0';

                    if r_done = '1' then
                        s_cs_state <= s_cs_deassertion;
                    end if;

                when s_cs_deassertion =>
                    r_cs <= '1';

                    if v_deassertation_counter = c_cs_deassertion_max then
                        s_cs_state <= s_idle;
                    else
                        v_deassertation_counter := v_deassertation_counter + 1;
                    end if;
            end case;
        end if;
    end process;

end architecture rtl;