library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.RAMController.all;

entity UART is
    Port (
        p_clk       : in    std_logic;
        p_baud      : in    std_logic_vector(15 downto 0);

        p_rx_pin    : in    std_logic;
        p_tx_pin    : out   std_logic;

        p_rx_dr     : out   std_logic;
        p_rx_clr    : in    std_logic;
        p_rx_data   : out   std_logic_vector(7 downto 0);

        p_tx_cts    : out   std_logic;
        p_tx_send   : in    std_logic;
        p_tx_data   : in    std_logic_vector(7 downto 0)
        );
end UART;

architecture Behavioral of UART is
    signal tx_reg     : std_logic_vector(9 downto 0) := (others => '0');
    signal tx_busy    : std_logic_vector(9 downto 0) := (others => '0');
    signal tx_timer   : std_logic_vector(12 downto 0) := (others => '0');
    signal tx_data    : std_logic_vector(7 downto 0);

    signal rx_reg     : std_logic_vector(9 downto 0) := (others => '0');
    signal rx_busy    : std_logic_vector(9 downto 0) := (others => '0');
    signal rx_timer   : std_logic_vector(12 downto 0) := (others => '0');
    signal rx_data    : std_logic_vector(7 downto 0);

begin
    p_tx_pin  <= tx_reg(0);
    p_tx_cts  <= not tx_busy(0);
  
    process(p_clk)
    begin
        if rising_edge(p_clk) then
            -- Active TX Frame
            if tx_busy(0) = '1' then
                if tx_timer = (p_baud - 1) then
                    tx_reg  <= '1' & tx_reg(9 downto 1);
                    tx_busy <= '0' & tx_busy(9 downto 1);
                    tx_timer <= (others => '0');
                else
                    tx_timer <= tx_timer + 1;
                end if;
            else
                -- New TX Data
                if p_tx_send = '1' then
                    tx_reg <= '1' & p_tx_data & '0';
                    tx_busy <= (others => '1');
                    tx_timer <= (others => '0');
                end if;
            end if;

            -- Active RX Frame
            if rx_busy(0) = '1' then
                if rx_timer = (p_baud - 1) then
                    if rx_busy(1) = '0' then
                        p_rx_dr   <= '1';
                        p_rx_data <= rx_reg(8 downto 1);
                    end if;
                    rx_busy <= '0' & rx_busy(9 downto 1);
                    rx_timer <= (others => '0');
                else
                    if rx_timer = 128 then
                        rx_reg <= p_rx_pin & rx_reg(9 downto 1);
                    end if;
                    rx_timer <= rx_timer + 1;
                end if;
            else
                -- RX Clear
                if p_rx_clr = '1' then
                    p_rx_dr <= '0';
                end if;
                
                -- Start RX Frame
                if p_rx_pin = '0' then
                    rx_busy <= (others => '1');
                    rx_timer <= (others => '0');
                end if;
            end if;            
        end if;
    end process;
end Behavioral;
