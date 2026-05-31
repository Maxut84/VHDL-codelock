library ieee;
use ieee.std_logic_1164.all;

entity lock_controller is
   port (
       clk         : in  std_logic;
       reset       : in  std_logic;

       evaluate    : in  std_logic;
       code_in     : in  std_logic_vector(15 downto 0);

       code_set    : out std_logic;  -- 1 när secret_code är sparad
       open_pulse  : out std_logic;  -- puls vid rätt kod
       error_pulse : out std_logic;  -- puls vid fel kod
       clear_entry : out std_logic   -- puls för att tömma shifter
   );
end entity;

architecture rtl of lock_controller is

   type state_type is (SET_SECRET, CHECK_CODE);
   signal state : state_type := SET_SECRET;

   signal secret_code : std_logic_vector(15 downto 0) := (others => '0');

begin

   process(clk)
   begin
       if rising_edge(clk) then

           -- default: pulser = 0
           open_pulse  <= '0';
           error_pulse <= '0';
           clear_entry <= '0';

           if reset = '1' then
               state       <= SET_SECRET;
               secret_code <= (others => '0');
               code_set    <= '0';

           elsif evaluate = '1' then
               case state is

                   when SET_SECRET =>
                       -- första evaluate sparar hemliga koden
                       secret_code <= code_in;
                       code_set    <= '1';
                       clear_entry <= '1';
                       state       <= CHECK_CODE;

                   when CHECK_CODE =>
                       -- senare evaluate jämför mot hemliga koden
                       if code_in = secret_code then
                           open_pulse <= '1';
                       else
                           error_pulse <= '1';
                       end if;

                       -- töm inmatningen efter varje försök
                       clear_entry <= '1';

               end case;
           end if;
       end if;
   end process;

end architecture;
