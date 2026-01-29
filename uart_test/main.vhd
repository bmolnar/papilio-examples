library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity main is
    Port (
        CLK         : in    std_logic;
        A15         : in    std_logic;
        B15         : out   std_logic;
        UART_RX     : in    std_logic;
        UART_TX     : out   std_logic
        );
end main;

architecture Behavioral of main is
    constant BAUD_9600 : std_logic_vector(15 downto 0) := X"0D05";

    subtype byte is std_logic_vector(7 downto 0);
    type byte_vector is array (natural range <>) of byte;
    type byte_buf is record
        pos  : integer range 0 to 8;
        data : byte_vector(0 to 7);
    end record;
    constant byte_buf_init : byte_buf := (pos => 0, data => (others => X"00"));

    constant crlf : byte_vector(0 to 1) := (X"0D", X"0A");


    function bytebuf_push(buf : byte_buf; b : byte) return byte_buf is
        variable result : byte_buf := buf;
    begin
        if (buf.pos + 1 <= 8) then
            result.data(buf.pos) := b;
            result.pos           := buf.pos + 1;
        end if;
        return result;
    end function;
    
    function bytebuf_push(buf : byte_buf; bv : byte_vector) return byte_buf is
        variable result : byte_buf := buf;
    begin
        for i in 0 to (bv'length-1) loop
            result := bytebuf_push(result, bv(i));
        end loop;
        return result;
    end function;

    function bytebuf_pop(buf : byte_buf) return byte_buf is
        variable result : byte_buf := buf;
    begin
        if (buf.pos > 0) then
            result.data(0 to 6) := buf.data(1 to 7);
            result.pos          := buf.pos - 1;
        end if;
        return result;
    end function;

    function hexdigit(b : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case b is
            when X"0" => return X"30";
            when X"1" => return X"31";
            when X"2" => return X"32";
            when X"3" => return X"33";
            when X"4" => return X"34";
            when X"5" => return X"35";
            when X"6" => return X"36";
            when X"7" => return X"37";
            when X"8" => return X"38";
            when X"9" => return X"39";
            when X"A" => return X"41";
            when X"B" => return X"42";
            when X"C" => return X"43";
            when X"D" => return X"44";
            when X"E" => return X"45";
            when X"F" => return X"46";
            when (others => '0') => return X"30";
        end case;
    end function;

    function hexbyte(b : in byte) return byte_vector is
        variable result : byte_vector(0 to 1) := (X"00", X"00");
    begin
        result(0) := hexdigit(b(7 downto 4));
        result(1) := hexdigit(b(3 downto 0));
        return result;
    end function;

    function translate(b : in byte) return byte_vector is
        variable result : byte_vector(0 to 0) := (others => b);
    begin
        if (b = X"0D" or b = X"0A") then
            return crlf;
        else
            return result;
        end if;
    end function;


    --
    -- uart_t
    --
    type uart_t is record
        rx_dr   : std_logic;
        rx_clr  : std_logic;
        rx_data : std_logic_vector(7 downto 0);
        tx_cts  : std_logic;
        tx_send : std_logic;
        tx_data : std_logic_vector(7 downto 0);
    end record;
    constant uart_init : uart_t := (rx_dr => '0', rx_clr => '0', rx_data => (others => '0'),
                                    tx_cts => '1', tx_send => '0', tx_data => (others => '0'));

    --
    -- ctx_t
    --
    type ctx_t is record
        uart0         : uart_t;
        txbuf0        : byte_buf;
        cantx0        : std_logic;
        canrx0        : std_logic;
        
        uart1         : uart_t;
        txbuf1        : byte_buf;
        cantx1        : std_logic;
        canrx1        : std_logic;
    end record;
    constant ctx_init : ctx_t := (uart0 => uart_init, txbuf0 => byte_buf_init, cantx0 => '0', canrx0 => '0',
                                  uart1 => uart_init, txbuf1 => byte_buf_init, cantx1 => '0', canrx1 => '0');


    signal ctx : ctx_t := ctx_init;

    
begin
    UART0: entity UART port map (
        p_clk => CLK, p_baud => BAUD_9600, p_rx_pin => A15, p_tx_pin => B15,
        p_rx_dr => ctx.uart0.rx_dr, p_rx_clr => ctx.uart0.rx_clr, p_rx_data => ctx.uart0.rx_data,
        p_tx_cts => ctx.uart0.tx_cts, p_tx_send => ctx.uart0.tx_send, p_tx_data => ctx.uart0.tx_data);

    UART1: entity UART port map (
        p_clk => CLK, p_baud => BAUD_9600, p_rx_pin => UART_RX, p_tx_pin => UART_TX,
        p_rx_dr => ctx.uart1.rx_dr, p_rx_clr => ctx.uart1.rx_clr, p_rx_data => ctx.uart1.rx_data,
        p_tx_cts => ctx.uart1.tx_cts, p_tx_send => ctx.uart1.tx_send, p_tx_data => ctx.uart1.tx_data);

    ctx.cantx0 <= '1' when (ctx.txbuf0.pos > 0 and ctx.uart0.tx_cts = '1') else '0';
    ctx.uart0.tx_send <= ctx.cantx0;
    ctx.uart0.tx_data <= ctx.txbuf0.data(0);
    
    ctx.cantx1 <= '1' when (ctx.txbuf1.pos > 0 and ctx.uart1.tx_cts = '1') else '0';
    ctx.uart1.tx_send <= ctx.cantx1;
    ctx.uart1.tx_data <= ctx.txbuf1.data(0);

    ctx.canrx0 <= '1' when (ctx.txbuf1.pos < 7 and ctx.uart0.rx_dr = '1') else '0';
    ctx.canrx1 <= '1' when (ctx.txbuf0.pos < 7 and ctx.uart1.rx_dr = '1') else '0';
    
    process(CLK)
    begin
        if (rising_edge(CLK)) then            
            if (ctx.cantx0 = '1') then
                ctx.txbuf0 <= bytebuf_pop(ctx.txbuf0);
            elsif (ctx.canrx1 = '1') then
                ctx.txbuf0 <= bytebuf_push(ctx.txbuf0, translate(ctx.uart1.rx_data));
                ctx.uart1.rx_clr <= '1';
            end if;

            if (ctx.cantx1 = '1') then
                ctx.txbuf1 <= bytebuf_pop(ctx.txbuf1);
            elsif (ctx.canrx0 = '1') then
                ctx.txbuf1 <= bytebuf_push(ctx.txbuf1, translate(ctx.uart0.rx_data));
                ctx.uart0.rx_clr <= '1';
            end if;
        end if;
    end process;
end Behavioral;
