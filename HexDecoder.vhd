library ieee;
use ieee.std_logic_1164.all;

use work.Decoder.all;

entity HexDecoder is

port(
	hexadecimal : in std_logic_vector(3 downto 0);
	segment 		: out std_logic_vector(6 downto 0)
	);

end entity;


architecture rtl of HexDecoder is
begin

	
	segment <= to_SevenSegment(hexadecimal);
	
end architecture;
