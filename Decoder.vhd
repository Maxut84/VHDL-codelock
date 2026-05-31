library ieee;
use ieee.std_logic_1164.all;

package Decoder is

  subtype seg7_t is std_logic_vector(6 downto 0);

  function to_SevenSegment(i : std_logic_vector(3 downto 0))
    return seg7_t;
	 
end package Decoder;

package body Decoder is
  function to_SevenSegment(i : std_logic_vector(3 downto 0))
    return seg7_t is
    variable seg : seg7_t;
	 
  begin
    case i is
      when "0000" => seg := "1111110"; -- 0
      when "0001" => seg := "0110000"; -- 1
      when "0010" => seg := "1101101"; -- 2
      when "0011" => seg := "1111001"; -- 3
      when "0100" => seg := "0110011"; -- 4
      when "0101" => seg := "1011011"; -- 5
      when "0110" => seg := "1011111"; -- 6
      when "0111" => seg := "1110000"; -- 7
      when "1000" => seg := "1111111"; -- 8
      when "1001" => seg := "1111011"; -- 9
      when "1010" => seg := "1110111"; -- A
      when "1011" => seg := "0011111"; -- b
      when "1100" => seg := "1001110"; -- C
      when "1101" => seg := "0111101"; -- d
      when "1110" => seg := "1001111"; -- E
      when others => seg := "1000111"; -- F
    end case;
    return seg(0) & seg(1) & seg(2) & seg(3) & seg(4) & seg(5) & seg(6);
  end function;
end package body Decoder;