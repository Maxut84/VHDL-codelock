library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scanner1 is
    port (
        clk   : in  std_logic;
        K     : in  std_logic_vector(3 downto 0);   -- columns, input active-low
        R     : out std_logic_vector(3 downto 0);   -- rows, output active-low
        key   : out std_logic_vector(3 downto 0);   -- key code
        valid : out std_logic;                      -- pulse = new valid key
        star  : out std_logic;                      -- pulse when * pressed
        hash  : out std_logic                       -- pulse when # pressed
    );
end entity;

architecture rtl of scanner1 is


    type state_type is (SCAN, DEBOUNCE, WAIT_RELEASE);
    signal state : state_type := SCAN;


    -- Row scan pattern
    signal row_drive : std_logic_vector(3 downto 0) := "0111";

    -- synkronisera K input
    signal K_meta : std_logic_vector(3 downto 0) := "1111";
    signal K_sync : std_logic_vector(3 downto 0) := "1111";

    
    -- Row dwell counter
    signal row_dwell_cnt : integer range 0 to 999 := 0;
    constant ROW_DWELL_MAX : integer := 999;

    
    -- Debounce counter
    -- 500000 cycles at 50 MHz = ca 10 ms
    signal debounce_cnt : integer range 0 to 500000 := 0;
    constant DEBOUNCE_MAX : integer := 500000;

    
    -- Release timeout counter
    -- Om K flyter eller knappen aldrig släppt ut, går scannern vidare ändå.
    -- 2500000 cycles at 50 MHz = ca 50 ms
    signal release_cnt : integer range 0 to 2500000 := 0;
    constant RELEASE_MAX : integer := 2500000;

    
    -- Outputs
    signal key_out   : std_logic_vector(3 downto 0) := "0000";
    signal valid_out : std_logic := '0';
    signal star_out  : std_logic := '0';
    signal hash_out  : std_logic := '0';

    
    -- Detected key
    signal detected_key  : std_logic_vector(3 downto 0) := "0000";
    signal detected_star : std_logic := '0';
    signal detected_hash : std_logic := '0';

    
    -- Current decode
    signal current_key   : std_logic_vector(3 downto 0) := "0000";
    signal current_press : std_logic := '0';
    signal current_star  : std_logic := '0';
    signal current_hash  : std_logic := '0';

begin

    
    -- Port connections
    R     <= row_drive;
    key   <= key_out;
    valid <= valid_out;
    star  <= star_out;
    hash  <= hash_out;

    
    -- Synchronize keypad columns
    process(clk)
    begin
        if rising_edge(clk) then
            K_meta <= K;
            K_sync <= K_meta;
        end if;
    end process;

    
    -- Combinational key decoding
    -- !!! radordningen är omvänd jämfört med standardlayouten
    process(row_drive, K_sync)
    begin
        current_key   <= "0000";
        current_press <= '0';
        current_star  <= '0';
        current_hash  <= '0';

        case row_drive is

            -- row_drive = "0111" motsvarar: * 0 # D
            when "0111" =>
                case K_sync is
                    when "0111" => current_star <= '1'; current_press <= '1'; -- *
                    when "1011" => current_key  <= "0000"; current_press <= '1'; -- 0
                    when "1101" => current_hash <= '1'; current_press <= '1'; -- #
                    when "1110" => current_key  <= "1101"; current_press <= '1'; -- D
                    when others => null;
                end case;

            
            -- row_drive = "1011" motsvarar: 7 8 9 C
            when "1011" =>
                case K_sync is
                    when "0111" => current_key <= "0111"; current_press <= '1'; -- 7
                    when "1011" => current_key <= "1000"; current_press <= '1'; -- 8
                    when "1101" => current_key <= "1001"; current_press <= '1'; -- 9
                    when "1110" => current_key <= "1100"; current_press <= '1'; -- C
                    when others => null;
                end case;

            
            -- row_drive = "1101" motsvarar: 4 5 6 B
            when "1101" =>
                case K_sync is
                    when "0111" => current_key <= "0100"; current_press <= '1'; -- 4
                    when "1011" => current_key <= "0101"; current_press <= '1'; -- 5
                    when "1101" => current_key <= "0110"; current_press <= '1'; -- 6
                    when "1110" => current_key <= "1011"; current_press <= '1'; -- B
                    when others => null;
                end case;

            
            -- row_drive = "1110" motsvarar: 1 2 3 A
            when "1110" =>
                case K_sync is
                    when "0111" => current_key <= "0001"; current_press <= '1'; -- 1
                    when "1011" => current_key <= "0010"; current_press <= '1'; -- 2
                    when "1101" => current_key <= "0011"; current_press <= '1'; -- 3
                    when "1110" => current_key <= "1010"; current_press <= '1'; -- A
                    when others => null;
                end case;

            when others =>
                null;

        end case;
    end process;

    
    process(clk)
    begin
        if rising_edge(clk) then

            valid_out <= '0';
            star_out  <= '0';
            hash_out  <= '0';

            case state is

                --SCAN state
                when SCAN =>
                
                    debounce_cnt <= 0;
                    release_cnt  <= 0;

                    if current_press = '1' then
                        detected_key  <= current_key;
                        detected_star <= current_star;
                        detected_hash <= current_hash;

                        state <= DEBOUNCE;

                    else
                        detected_key  <= "0000";
                        detected_star <= '0';
                        detected_hash <= '0';

                        if row_dwell_cnt < ROW_DWELL_MAX then
                            row_dwell_cnt <= row_dwell_cnt + 1;
                        else
                            row_dwell_cnt <= 0;

                            case row_drive is
                                when "0111" => row_drive <= "1011";
                                when "1011" => row_drive <= "1101";
                                when "1101" => row_drive <= "1110";
                                when "1110" => row_drive <= "0111";
                                when others => row_drive <= "0111";
                            end case;
                        end if;
                    end if;

                --DEbounce state
                when DEBOUNCE =>
                
                    release_cnt <= 0;

                    if current_press = '1' and
                       current_key  = detected_key and
                       current_star = detected_star and
                       current_hash = detected_hash then

                        if debounce_cnt < DEBOUNCE_MAX then
                            debounce_cnt <= debounce_cnt + 1;
                        else
                            key_out   <= detected_key;
                            valid_out <= '1';

                            if detected_star = '1' then
                                star_out <= '1';
                            end if;

                            if detected_hash = '1' then
                                hash_out <= '1';
                            end if;

                            debounce_cnt <= 0;
                            release_cnt  <= 0;
                            state        <= WAIT_RELEASE;
                        end if;

                    else
                        debounce_cnt <= 0;
                        release_cnt  <= 0;
                        state        <= SCAN;
                    end if;

                --wqit state
						when WAIT_RELEASE =>
							 debounce_cnt <= 0;
							 release_cnt  <= 0;

							 -- Vänta tills alla kolumner är höga igen, alltså ingen knapp nedtryckt.
							 -- Detta stoppar att en lång knapptryckning registreras flera gånger.
							 if K_sync = "1111" then
								  row_dwell_cnt <= 0;
								  state         <= SCAN;
							 end if;

                when others =>
                    debounce_cnt <= 0;
                    release_cnt  <= 0;
                    state        <= SCAN;

            end case;
        end if;
    end process;

end architecture;