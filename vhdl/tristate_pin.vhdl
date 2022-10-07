-- Copied from stackoverflow

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY bidir IS
    PORT (
        -- i_clk : IN STD_LOGIC;
        io_pin : INOUT STD_LOGIC;
        i_en : IN STD_LOGIC;
        i_bit : OUT STD_LOGIC;
        o_bit : IN STD_LOGIC
        );
END bidir;

ARCHITECTURE maxpld OF bidir IS
BEGIN
    io_pin <= o_bit when i_en = '1' else 'Z';
    i_bit <= io_pin;
END maxpld;