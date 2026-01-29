library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

entity counter is
    Port (
        P_CLK : in    std_logic;
        P_OUT : out   std_logic_vector(15 downto 0)
        );
end counter;

architecture Behavioral of counter is
    signal count : std_logic_vector(15 downto 0) := (others => '0');
begin
    P_OUT <= count;
    
    process(P_CLK)
    begin
        if (falling_edge(P_CLK)) then
            count <= count + 1;
        end if;
    end process;
end Behavioral;
