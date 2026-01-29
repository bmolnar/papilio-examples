library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity project is
    Port (
        CLK         : in    std_logic;
        A           : out   std_logic_vector(15 downto 0);
        B           : out   std_logic_vector(15 downto 0);
        C           : out   std_logic_vector(15 downto 0)
        );
end project;

architecture Behavioral of project is
    signal countA : std_logic_vector(15 downto 0) := (others => '0');
    signal countB : std_logic_vector(15 downto 0) := (others => '0');
    signal countC : std_logic_vector(15 downto 0) := (others => '0');
begin
    A <= countA;
    B <= countB;
    C <= countC;

    counterA: entity counter port map (P_CLK => CLK,        P_OUT => countA);
    counterB: entity counter port map (P_CLK => countA(15), P_OUT => countB);
    counterC: entity counter port map (P_CLK => countB(15), P_OUT => countC);
end Behavioral;
