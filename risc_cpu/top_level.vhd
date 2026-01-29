library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity top_level is
    Port (
        CLK         : in    std_logic;
        A15         : in    std_logic;
        B15         : out   std_logic;
        UART_RX     : in    std_logic;
        UART_TX     : out   std_logic
        );
end top_level;

architecture Structural of top_level is
begin
    MAIN0: entity main port map ( clk => CLK, uart_rx => A15, uart_tx => B15 );
    UART_TX <= UART_RX;
end Structural;
