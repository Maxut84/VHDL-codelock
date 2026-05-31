library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keypad_display_mux is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        code        : in  std_logic_vector(15 downto 0);
        digit_count : in  integer range 0 to 4;

        hexadecimal : out std_logic_vector(3 downto 0);
        sel         : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of keypad_display_mux is

    constant SEL_ACTIVE_HIGH : boolean := true;
    constant BLANK_UNUSED    : boolean := false;
	 
	 --räknare för swtichning mellan SEL
    signal refresh_counter : unsigned(15 downto 0) := (others => '0');
	 
	 --vilken siffra som visas
    signal digit_select    : unsigned(1 downto 0) := (others => '0');
	 
	 --vilken displau som ska visas
    signal sel_raw         : std_logic_vector(3 downto 0) := "0001";

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                refresh_counter <= (others => '0');
            else
                refresh_counter <= refresh_counter + 1;
            end if;
        end if;
    end process;

    digit_select <= refresh_counter(15 downto 14);

    process(digit_select, code)
    begin
        case digit_select is
            when "00" =>
                hexadecimal <= code(15 downto 12);
                sel_raw     <= "0001";

            when "01" =>
                hexadecimal <= code(11 downto 8);
                sel_raw     <= "0010";

            when "10" =>
                hexadecimal <= code(7 downto 4);
                sel_raw     <= "0100";

            when others =>
                hexadecimal <= code(3 downto 0);
                sel_raw     <= "1000";
        end case;
    end process;

    sel <= sel_raw when SEL_ACTIVE_HIGH else
           not sel_raw;

end architecture;