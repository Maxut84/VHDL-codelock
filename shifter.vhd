library ieee;
use ieee.std_logic_1164.all;

entity shifter is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        valid    : in  std_logic;
        hash     : in  std_logic;
        star     : in  std_logic;
        key      : in  std_logic_vector(3 downto 0);

        code     : out std_logic_vector(15 downto 0);
        evaluate : out std_logic;
        count    : out integer range 0 to 4
    );
end entity;

architecture rtl of shifter is

    signal digit0 : std_logic_vector(3 downto 0) := "0000"; -- oldest
    signal digit1 : std_logic_vector(3 downto 0) := "0000";
    signal digit2 : std_logic_vector(3 downto 0) := "0000";
    signal digit3 : std_logic_vector(3 downto 0) := "0000"; -- newest

    signal digit_count  : integer range 0 to 4 := 0;
    signal evaluate_reg : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            -- default: evaluate bara en klockpuls
            evaluate_reg <= '0';

            
            -- "Reset" eller * rensar inmatningen
            if reset = '1' or star = '1' then
                digit0      <= "0000";
                digit1      <= "0000";
                digit2      <= "0000";
                digit3      <= "0000";
                digit_count <= 0;

            
            -- hantera före valid, annars problem
            elsif hash = '1' then
				
                evaluate_reg <= '1';
                digit_count  <= 0;

            
            -- Valid knapptryckning
            elsif valid = '1' and star = '0' and hash = '0' and digit_count < 4 then
                digit0      <= digit1;
                digit1      <= digit2;
                digit2      <= digit3;
                digit3      <= key;
                digit_count <= digit_count + 1;

            end if;

        end if;
    end process;
	 
	 --Outputs
    code     <= digit0 & digit1 & digit2 & digit3;
    count    <= digit_count;
    evaluate <= evaluate_reg;

end architecture;