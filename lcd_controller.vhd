--------------------------------------------------------------------------------
--
-- FileName: lcd_controller.vhd
--
-- Based on:
-- https://github.com/Maeur1/16x2-LCD-Controller-VHDL/blob/master/lcd_controller.vhd
--
-- Original version history from the referenced controller:
-- Version 1.0 6/2/2006 Scott Larson
-- Version 2.0 6/13/2012 Scott Larson
-- Version 3.0 10/01/2017 Mayur Panchal
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_controller is
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;

        code_set    : in  std_logic;
        open_pulse  : in  std_logic;
        error_pulse : in  std_logic;
        clear_entry : in  std_logic;
        digit_count : in  integer range 0 to 4;

        lcd_rs      : out std_logic;
        lcd_en      : out std_logic;
        lcd_rw      : out std_logic;
        lcd_on      : out std_logic;
        lcd_bl      : out std_logic;
        lcd_db      : out std_logic_vector(7 downto 0)
    );
end entity;

architecture controller of lcd_controller is

    -- olika steg som lcd:n går igenom när den ska skriva text
    type control is (power_up, initialize, resetline, line1, line2, send);

	 
    -- egna states bara för vad som ska stå på displayen
    type lcd_status_type is (set_code, closed, open_door, error_code, saved_code);

	 
    -- klockan på kortet är 50 MHz, används för att räkna tider
    constant freq : integer := 50;

	 
    -- hur länge de olika meddelandena ska visas innan den går tillbaka
    constant open_ticks  : unsigned(28 downto 0) := to_unsigned(500000000, 29);
    constant error_ticks : unsigned(27 downto 0) := to_unsigned(150000000, 28);
    constant saved_ticks : unsigned(26 downto 0) := to_unsigned(100000000, 27);

	 
    -- state är vart lcd-styrningen är just nu
    signal state : control := power_up;

	 
    -- ptr pekar på vilken bokstav i raden som ska skickas
    signal ptr   : natural range 0 to 16 := 15;

	 
    -- line säger om vi skriver rad 1 eller rad 2
    signal line  : std_logic := '1';

	 
    -- status är vad kodlåset vill visa på första raden
    signal status      : lcd_status_type := closed;

	 
    -- sparar gamla code_set så man kan se när den precis ändras
    signal code_set_d  : std_logic := '0';

	 
    -- timer används för door open/error/code saved så det inte visas för alltid
    signal timer       : unsigned(28 downto 0) := (others => '0');

	 
    -- här sparas hela texten som ska skickas till lcd:n, 16 tecken per rad
    signal line1_buffer : std_logic_vector(127 downto 0);
    signal line2_buffer : std_logic_vector(127 downto 0);
	 

    -- gör om en bokstav till ascii-tal som lcd:n fattar
    function ascii(c : character) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(character'pos(c), 8));
    end function;

    -- gör om en text med 16 tecken till en 128-bitars buss
    function text16(s : string) return std_logic_vector is
        variable result : std_logic_vector(127 downto 0) := (others => '0');
    begin
        for i in 0 to 15 loop
            result((15 - i) * 8 + 7 downto (15 - i) * 8) := ascii(s(s'low + i));
        end loop;

        return result;
    end function;

begin

    -- vi skriver bara till lcd:n, alltså rw alltid 0
    lcd_rw <= '0';

    -- slår på displayen och bakgrundsljuset
    lcd_on <= '1';
    lcd_bl <= '1';

    -- Bestämmer vilket läge displayen ska visa
    process(clk)
    begin
        if rising_edge(clk) then
            -- sparar förra värdet så vi kan upptäcka när koden precis sparades
            code_set_d <= code_set;
				
				-- reset gör att allt börjar från stängd dörr igen
            if reset = '1' then
                status     <= closed;
                code_set_d <= '0';
                timer      <= (others => '0');
            
				-- rätt kod, visa att dörren är öppen
				elsif open_pulse = '1' then
                status <= open_door;
                timer  <= open_ticks;
            
				-- fel kod, visa error
				elsif error_pulse = '1' then
                status <= error_code;
                timer  <= resize(error_ticks, timer'length);
            
				
				-- när första koden sparas 
				elsif code_set = '1' and code_set_d = '0' then
                status <= saved_code;
                timer  <= resize(saved_ticks, timer'length);
            
				-- om man reset när dörren är öppen går den tillbaka till stängd
				elsif clear_entry = '1' and status = open_door then
                status <= closed;
                timer  <= (others => '0');
            
				-- innan kod är satt visar vi bara stängd dörr
				elsif code_set = '0' then
                status <= closed;
                timer  <= (others => '0');
            
				-- räknar ner tiden för tillfälliga meddelanden
				elsif timer /= 0 then
				
                timer <= timer - 1;

                if timer = 1 then
                    status <= closed;
                end if;
            end if;
        end if;
    end process;

    -- denna process väljer själva texten som ska ligga i rad-buffertarna
    process(status, digit_count)
    begin
        -- rad 1 visar dörrstatus
        case status is
            when open_door =>
                line1_buffer <= text16("DOOR OPEN       ");

            when error_code =>
                line1_buffer <= text16("ERROR           ");

            when saved_code =>
                line1_buffer <= text16("CODE SAVED      ");

            when set_code =>
                line1_buffer <= text16("DOOR CLOSED     ");

            when others =>
                line1_buffer <= text16("DOOR CLOSED     ");
        end case;

        -- rad 2 visar alltid stjärnor för hur många siffror som är inskrivna
        case digit_count is
            when 0      => line2_buffer <= text16("                ");
            when 1      => line2_buffer <= text16("*               ");
            when 2      => line2_buffer <= text16("**              ");
            when 3      => line2_buffer <= text16("***             ");
            when others => line2_buffer <= text16("****            ");
        end case;
    end process;

    -- denna process är lcd-bibliotekets skickare, den skickar en byte i taget
    
	 process(clk)
        variable clk_count : integer := 0;
    begin
        if rising_edge(clk) then
            case state is
                when power_up =>
                    -- lcd:n behöver vänta lite efter strömmen suttits på
                    if clk_count < (50000 * freq) then
                        clk_count := clk_count + 1;
                        state <= power_up;
                    else
                        clk_count := 0;
                        lcd_rs <= '0';
                        lcd_db <= "00110000";
                        state <= initialize;
                    end if;

                when initialize =>
                    -- skickar startkommandon så lcd:n hamnar i rätt läge
                    clk_count := clk_count + 1;

                    if clk_count < (10 * freq) then
                        lcd_db <= "00111100";
                        lcd_en <= '1';
                        state <= initialize;
                    elsif clk_count < (60 * freq) then
                        lcd_db <= "00000000";
                        lcd_en <= '0';
                        state <= initialize;
                    elsif clk_count < (70 * freq) then
                        lcd_db <= "00001100";
                        lcd_en <= '1';
                        state <= initialize;
                    elsif clk_count < (120 * freq) then
                        lcd_db <= "00000000";
                        lcd_en <= '0';
                        state <= initialize;
                    elsif clk_count < (130 * freq) then
                        lcd_db <= "00000001";
                        lcd_en <= '1';
                        state <= initialize;
                    elsif clk_count < (2130 * freq) then
                        lcd_db <= "00000000";
                        lcd_en <= '0';
                        state <= initialize;
                    elsif clk_count < (2140 * freq) then
                        lcd_db <= "00000110";
                        lcd_en <= '1';
                        state <= initialize;
                    elsif clk_count < (2200 * freq) then
                        lcd_db <= "00000000";
                        lcd_en <= '0';
                        state <= initialize;
                    else
                        clk_count := 0;
                        state <= resetline;
                    end if;

                when resetline =>
                    -- flyttar cursor till början på rad 1 eller rad 2
                    ptr <= 16;
                    lcd_rs <= '0';
                    clk_count := 0;

                    if line = '1' then
                        lcd_db <= "10000000";
                    else
                        lcd_db <= "11000000";
                    end if;

                    state <= send;

                when line1 =>
                    -- hämtar nästa tecken från rad 1 bufferten
                    line <= '1';
                    lcd_db <= line1_buffer(ptr * 8 + 7 downto ptr * 8);
                    lcd_rs <= '1';
                    clk_count := 0;
                    state <= send;

                when line2 =>
                    -- hämtar nästa tecken från rad 2 bufferten
                    line <= '0';
                    lcd_db <= line2_buffer(ptr * 8 + 7 downto ptr * 8);
                    lcd_rs <= '1';
                    clk_count := 0;
                    state <= send;

                when send =>
                    -- här pulsas enable så lcd:n faktiskt tar emot byten
                    if clk_count < (50 * freq) then
                        if clk_count < freq then
                            lcd_en <= '0';
                        elsif clk_count < (14 * freq) then
                            lcd_en <= '1';
                        elsif clk_count < (27 * freq) then
                            lcd_en <= '0';
                        end if;

                        clk_count := clk_count + 1;
                        state <= send;
                    else
                        clk_count := 0;

                        if line = '1' then
                            if ptr = 0 then
                                line <= '0';
                                state <= resetline;
                            else
                                ptr <= ptr - 1;
                                state <= line1;
                            end if;
                        else
                            if ptr = 0 then
                                line <= '1';
                                state <= resetline;
                            else
                                ptr <= ptr - 1;
                                state <= line2;
                            end if;
                        end if;
                    end if;
            end case;

            if reset = '1' then
                -- reset av själva lcd-skrivaren också
                state <= power_up;
                ptr <= 15;
                line <= '1';
                clk_count := 0;
                lcd_rs <= '0';
                lcd_en <= '0';
                lcd_db <= (others => '0');
            end if;
        end if;
    end process;

end architecture;
