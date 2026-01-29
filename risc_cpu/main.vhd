library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;

use work.package_defs.all;
use work.asciibin.all;

entity main is
    Port (
        clk         : in    std_logic;
        uart_rx     : in    std_logic;
        uart_tx     : out   std_logic
        );
end main;

architecture Behavioral of main is

    --
    -- uart_t
    --
    type uart_t is record
        baud     : std_logic_vector(15 downto 0);
        tx_pin   : std_logic;
        tx_cts   : std_logic;
        tx_send  : std_logic;
        tx_data  : std_logic_vector(7 downto 0);
        rx_pin   : std_logic;
        rx_dr    : std_logic;
        rx_clr   : std_logic;
        rx_data  : std_logic_vector(7 downto 0);
    end record;
    constant uart_init : uart_t := (baud => BAUD_9600,
                                    tx_pin => '0', tx_cts => '1', tx_send => '0', tx_data => (others => '0'),
                                    rx_pin => '0', rx_dr => '0', rx_clr => '1', rx_data => (others => '0'));

    --
    -- mem_t
    --
    type mem_t is record
        addr     : std_logic_vector(31 downto 0);
        dataw    : std_logic_vector(31 downto 0);
        datar    : std_logic_vector(31 downto 0);
        we       : std_logic;
        re       : std_logic;
    end record;
    constant mem_init : mem_t := (addr => (others => '0'), dataw => (others => '0'), datar => (others => '0'), we => '0', re => '0');

    --
    -- cpu_t
    --
    type cpu_t is record
        clk      : std_logic;
        counter  : std_logic_vector(31 downto 0);
        mem      : mem_t;
        reg_sel  : std_logic_vector(2 downto 0);
        reg_data : std_logic_vector(31 downto 0);
    end record;
    constant cpu_init : cpu_t := (clk => '0', counter => (others => '0'), mem => mem_init, reg_sel => (others => '0'), reg_data => (others => '0'));

    --
    -- stack_t
    --
    type frame_t is record
        state    : integer range 0 to 255;
        step     : integer range 0 to 255;
    end record;
    type frames_t is array (natural range <>) of frame_t;
    type stack_t is record
        depth    : integer range 0 to 7;
        frames   : frames_t(0 to 7);
    end record;
    constant stack_init : stack_t := (depth => 0, frames => (others => (state => 0, step => 0)));

    type argv_t is array (natural range <>) of integer range 0 to 31;
    type args_t is record
        argc   : integer range 0 to 15;
        argv   : argv_t(0 to 3);
    end record;
    constant args_init : args_t := (argc => 0, argv => (others => 0));

    --
    -- ctx_t
    --
    type ctx_t is record
        uart           : uart_t;
        mem            : mem_t;
        cpu            : cpu_t;
        
        stack          : stack_t;
        counter        : std_logic_vector(31 downto 0);

        -- Command buffer
        cmd_rxidx      : integer range 0 to 31;
        cmd_buffer     : byte_vector(0 to 15);
        cmd_args       : args_t;

        -- Result buffer
        res_buffer     : byte_vector(0 to 31);

        -- Scratch buffer
        scr_buffer     : byte_vector(0 to 63);
    end record;

    constant ctx_init : ctx_t := (uart => uart_init, mem => mem_init, cpu => cpu_init, stack => stack_init,
                                  counter => (others => '0'),
                                  cmd_rxidx => 0, cmd_buffer => (others => X"00"), cmd_args => args_init,
                                  res_buffer => (others => X"00"), scr_buffer => (others => X"00"));

    --
    -- Context
    --
    signal ctx : ctx_t := ctx_init;
    

    --
    -- Control Flow Procedures
    --
    procedure call(signal nctx : inout ctx_t; nstate : in integer; retstep : in integer) is
    begin
        nctx.stack.frames(nctx.stack.depth).step <= retstep;
        nctx.stack.frames(nctx.stack.depth + 1).step <= 0;
        nctx.stack.frames(nctx.stack.depth + 1).state <= nstate;
        nctx.stack.depth <= nctx.stack.depth + 1;
    end procedure call;

    procedure call(signal nctx : inout ctx_t; nstate : in integer) is
    begin
        nctx.stack.frames(nctx.stack.depth).step <= nctx.stack.frames(nctx.stack.depth).step + 1;
        nctx.stack.frames(nctx.stack.depth + 1).step <= 0;
        nctx.stack.frames(nctx.stack.depth + 1).state <= nstate;
        nctx.stack.depth <= nctx.stack.depth + 1;
    end procedure call;

    procedure ret(signal nctx : inout ctx_t) is
    begin
        nctx.stack.depth <= nctx.stack.depth - 1;
    end procedure ret;

    procedure goto(signal nctx : inout ctx_t; nstep : in integer) is
    begin
        nctx.stack.frames(nctx.stack.depth).step <= nstep;
    end procedure goto;

    procedure step(signal nctx : inout ctx_t) is
    begin
        nctx.stack.frames(nctx.stack.depth).step <= nctx.stack.frames(nctx.stack.depth).step + 1;
    end procedure step;

    procedure reset(signal nctx : inout ctx_t) is
    begin
        nctx.stack.depth           <= 0;
        nctx.stack.frames(0).step  <= 0;
        nctx.stack.frames(0).state <= 0;
    end procedure reset;



    --
    -- State Machine Procedures
    --
    constant state_main      : integer := 0;
    constant state_noop      : integer := 1;
    constant state_init      : integer := 2;
    constant state_loop      : integer := 3;
    constant state_counter   : integer := 4;
    constant state_getscr    : integer := 5;
    constant state_txcrlf    : integer := 6;
    constant state_txscr     : integer := 7;
    constant state_txcmd     : integer := 8;
    constant state_rxcmd     : integer := 9;
    constant state_txres     : integer := 10;
    constant state_cmd       : integer := 11;
    constant state_cpureg    : integer := 12;
    constant state_cpuclk    : integer := 13;
    constant state_memdump   : integer := 14;
    constant state_memstore  : integer := 15;
    constant state_setaddr   : integer := 16;
    constant state_parsecmd  : integer := 17;
    
    --
    -- proc_noop
    --
    procedure proc_noop(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (step = 0) then
            step(nctx);
        else
            ret(nctx);
        end if;
    end procedure proc_noop;


    --
    -- proc_counter
    --
    procedure proc_counter(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (step = 0) then
            nctx.counter <= std_logic_vector(unsigned(nctx.counter) + 1);
            ret(nctx);
        else
            ret(nctx);
        end if;
    end procedure proc_counter;

    --
    -- proc_getscr
    --
    procedure proc_getscr(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (step = 0) then
            -- Counter
            nctx.scr_buffer(0 to 7)   <= to_hexchars(nctx.counter(31 downto 0));
            nctx.scr_buffer(8)        <= char_to_byte(',');

            -- Mem registers
            nctx.scr_buffer(9 to 16)  <= to_hexchars(nctx.mem.addr(31 downto 0));
            nctx.scr_buffer(17)       <= char_to_byte(':');
            nctx.scr_buffer(18 to 25) <= to_hexchars(nctx.mem.dataw(31 downto 0));
            nctx.scr_buffer(26)       <= char_to_byte(':');
            nctx.scr_buffer(27 to 34) <= to_hexchars(nctx.mem.datar(31 downto 0));
            nctx.scr_buffer(35)       <= char_to_byte(':');
            nctx.scr_buffer(36)       <= bit_to_binchar(nctx.mem.we);
            nctx.scr_buffer(37)       <= char_to_byte(',');

            -- CPU registers
            nctx.scr_buffer(38 to 45) <= to_hexchars(nctx.cpu.counter(31 downto 0));
            nctx.scr_buffer(46)       <= char_to_byte(':');
            nctx.scr_buffer(47 to 47) <= to_hexchars(nctx.cpu.reg_sel(2 downto 0));
            nctx.scr_buffer(48)       <= char_to_byte(':');
            nctx.scr_buffer(49 to 56) <= to_hexchars(nctx.cpu.reg_data(31 downto 0));

            step(nctx);
        else
            ret(nctx);
        end if;
    end procedure proc_getscr;


    --
    -- proc_txcrlf
    --
    procedure proc_txcrlf(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (nctx.uart.tx_cts = '1') then
            if (step = 0) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= X"0D";
                step(nctx);
            elsif (step = 1) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= X"0A";
                step(nctx);
            else
                nctx.uart.tx_send <= '0';
                nctx.uart.tx_data <= X"00";
                ret(nctx);
            end if;
        end if;
    end procedure proc_txcrlf;

    --
    -- proc_txscr
    --
    procedure proc_txscr(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (nctx.uart.tx_cts = '1') then
            if (step = 0) then
                nctx.uart.tx_send <= '0';
                call(nctx, state_txcrlf);
            elsif (step = 1) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= char_to_byte('=');
                step(nctx);
            elsif (step = 2) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= char_to_byte(' ');
                step(nctx);
            elsif (step < 66) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= nctx.scr_buffer(step - 3);
                step(nctx);
            elsif (step = 66) then
                nctx.uart.tx_send <= '0';
                call(nctx, state_txcrlf);
            else
                nctx.uart.tx_send <= '0';
                nctx.uart.tx_data <= X"00";
                ret(nctx);
            end if;
        end if;
    end procedure proc_txscr;


    --
    -- proc_txcmd
    --
    procedure proc_txcmd(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (nctx.uart.tx_cts = '1') then
            if (step = 0) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= X"0D";
                step(nctx);
            elsif (step = 1) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= char_to_byte('>');
                step(nctx);
            elsif (step = 2) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= char_to_byte(' ');
                step(nctx);
            elsif (step < 19) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= nctx.cmd_buffer(step - 3);
                step(nctx);
            else
                nctx.uart.tx_send <= '0';
                ret(nctx);
            end if;
        end if;
    end procedure proc_txcmd;

    --
    -- proc_txres
    --
    procedure proc_txres(signal nctx : inout ctx_t; step : in integer) is
    begin
        if (nctx.uart.tx_cts = '1') then
            if (step = 0) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= char_to_byte('<');
                step(nctx);
            elsif (step = 1) then
                nctx.uart.tx_send <= '1';
                nctx.uart.tx_data <= char_to_byte(' ');
                step(nctx);
            elsif (step < 34) then
                if (nctx.res_buffer(step - 2) = X"00") then
                    nctx.uart.tx_send <= '0';
                    nctx.uart.tx_data <= nctx.res_buffer(step - 2);
                    goto(nctx, 34);
                else
                    nctx.uart.tx_send <= '1';
                    nctx.uart.tx_data <= nctx.res_buffer(step - 2);
                    step(nctx);
                end if;
            elsif (step = 34) then
                nctx.uart.tx_send <= '0';
                call(nctx, state_txcrlf);
            else
                nctx.uart.tx_send <= '0';
                ret(nctx);
            end if;
        end if;        
    end procedure proc_txres;


    --
    -- proc_rxcmd
    --
    procedure proc_rxcmd(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                nctx.cmd_rxidx <= 0;
                nctx.cmd_buffer(0 to 15) <= (others => X"00");
                step(nctx);
            when 1 =>
                call(nctx, state_txcmd);
            when 2 =>
                if (nctx.uart.rx_dr = '1') then
                    if (nctx.uart.rx_data = X"0D" or nctx.uart.rx_data = X"0A") then
                        nctx.uart.rx_clr <= '1';
                        nctx.cmd_buffer(nctx.cmd_rxidx) <= X"00";
                        nctx.cmd_rxidx <= nctx.cmd_rxidx + 1;
                        goto(nctx, 3);
                    elsif (nctx.uart.rx_data = X"08") then
                        nctx.uart.rx_clr <= '1';
                        nctx.cmd_buffer(nctx.cmd_rxidx - 1) <= X"00";
                        nctx.cmd_rxidx <= nctx.cmd_rxidx - 1;
                        goto(nctx, 1);
                    else
                        nctx.uart.rx_clr <= '1';
                        nctx.cmd_buffer(nctx.cmd_rxidx) <= nctx.uart.rx_data;
                        nctx.cmd_rxidx <= nctx.cmd_rxidx + 1;
                        goto(nctx, 1);
                    end if;
                end if;
            when 3 =>
                call(nctx, state_txcrlf);
            when others =>
                --nctx.uart.rx_clr <= '1';
                ret(nctx);
        end case;
    end procedure proc_rxcmd;

    --
    -- proc_parsecmd
    --
    procedure proc_parsecmd(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                if (nctx.cmd_buffer(1) = X"20") then
                    nctx.cmd_args.argc <= 2;
                    nctx.cmd_args.argv(0) <= 0;
                    nctx.cmd_args.argv(1) <= 2;
                else
                    nctx.cmd_args.argc <= 1;
                    nctx.cmd_args.argv(0) <= 0;
                end if;
                step(nctx);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_parsecmd;




    
    --
    -- proc_setaddr
    --
    procedure proc_setaddr(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                if (nctx.cmd_buffer(1) = X"00") then
                    nctx.mem.addr <= (others => '0');
                else
                    nctx.mem.addr <= decode_hexchars(nctx.cmd_buffer(1 to 15), 32);
                end if;
                step(nctx);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_setaddr;

    --
    -- proc_memdump
    --
    procedure proc_memdump(signal nctx : inout ctx_t; step : in integer) is
        variable mem_len : std_logic_vector(31 downto 0) := (others => '0');
        variable mem_end : std_logic_vector(31 downto 0) := (others => '0');
    begin
        case step is
            when 0 =>
                if (nctx.cmd_buffer(1) = X"00") then
                    mem_len := X"00000010";
                else
                    mem_len := decode_hexchars(nctx.cmd_buffer(1 to 15), 32);
                end if;

                -- Set mem_end
                mem_end                 := std_logic_vector(unsigned(nctx.mem.addr) + unsigned(mem_len));

                -- Store ending address in scratch buffer
                nctx.scr_buffer(0 to 3) <= to_bytes(mem_end);
                nctx.mem.re             <= '1';
            
                step(nctx);
            when 1 =>
                -- Load mem_end from scratch buffer
                mem_end := to_bits(nctx.scr_buffer(0 to 3));

                if (nctx.mem.addr = mem_end) then
                    goto(nctx, 3);
                else
                    nctx.res_buffer(0 to 7)  <= to_hexchars(nctx.mem.addr(31 downto 0));
                    nctx.res_buffer(8)       <= char_to_byte(':');
                    nctx.res_buffer(9 to 16) <= to_hexchars(nctx.mem.datar(31 downto 0));
                    nctx.res_buffer(17)      <= X"00";
                    call(nctx, state_txres);
                end if;
            when 2 =>
                nctx.mem.addr <= std_logic_vector(unsigned(nctx.mem.addr) + 1);
                goto(nctx, 1);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_memdump;

    --
    -- proc_memstore
    --
    procedure proc_memstore(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                nctx.mem.dataw <= decode_hexchars(nctx.cmd_buffer(1 to 15), 32);
                nctx.mem.we    <= '1';
                step(nctx);
            when 1 =>
                nctx.mem.we    <= '0';
                nctx.mem.addr  <= std_logic_vector(unsigned(nctx.mem.addr) + 1);
                step(nctx);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_memstore;

    --
    -- proc_cpureg
    --
    procedure proc_cpureg(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                nctx.cpu.reg_sel <= "000";
                step(nctx);
            when 1 =>
                nctx.res_buffer(0 to 0) <= to_hexchars(nctx.cpu.reg_sel(2 downto 0));
                nctx.res_buffer(1)      <= char_to_byte(':');
                nctx.res_buffer(2 to 9) <= to_hexchars(nctx.cpu.reg_data(31 downto 0));
                nctx.res_buffer(10)     <= X"00";
                call(nctx, state_txres);
            when 2 =>
                if (nctx.cpu.reg_sel = "111") then
                    goto(nctx, 3);
                else
                    nctx.cpu.reg_sel <= std_logic_vector(unsigned(nctx.cpu.reg_sel) + 1);
                    goto(nctx, 1);
                end if;
            when others =>
                ret(nctx);
        end case;
    end procedure proc_cpureg;

    --
    -- proc_cpuclk
    --
    procedure proc_cpuclk(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                nctx.cpu.clk <= '1';
                step(nctx);
            when 1 =>
                nctx.cpu.clk     <= '0';
                nctx.cpu.counter <= std_logic_vector(unsigned(nctx.cpu.counter) + 1);
                step(nctx);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_cpuclk;


    
    --
    -- proc_cmd
    --
    procedure proc_cmd(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                nctx.res_buffer(0) <= X"00";
                step(nctx);
            when 1 =>
                if (nctx.cmd_buffer(0) = char_to_byte('C')) then
                    call(nctx, state_cpuclk);
                elsif (nctx.cmd_buffer(0) = char_to_byte('R')) then
                    call(nctx, state_cpureg);
                elsif (nctx.cmd_buffer(0) = char_to_byte('M')) then
                    call(nctx, state_memdump);
                elsif (nctx.cmd_buffer(0) = char_to_byte('A')) then
                    call(nctx, state_setaddr);
                elsif (nctx.cmd_buffer(0) = char_to_byte('S')) then
                    call(nctx, state_memstore);
                else
                    goto(nctx, 3);
                end if;
            when 2 =>
                -- OK
                nctx.res_buffer(0) <= char_to_byte('O');
                nctx.res_buffer(1) <= char_to_byte('K');
                nctx.res_buffer(2) <= X"00";
                goto(nctx, 4);
            when 3 =>
                -- INVALID
                nctx.res_buffer(0) <= char_to_byte('I');
                nctx.res_buffer(1) <= char_to_byte('N');
                nctx.res_buffer(2) <= char_to_byte('V');
                nctx.res_buffer(3) <= char_to_byte('A');
                nctx.res_buffer(4) <= char_to_byte('L');
                nctx.res_buffer(5) <= char_to_byte('I');
                nctx.res_buffer(6) <= char_to_byte('D');
                nctx.res_buffer(7) <= X"00";
                goto(nctx, 4);
            when 4 =>
                call(nctx, state_txres);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_cmd;


    --
    -- proc_init
    --
    procedure proc_init(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                nctx.counter <= (others => '0');
                step(nctx);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_init;


    --
    -- proc_loop
    --
    procedure proc_loop(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                call(nctx, state_counter);
            when 1 =>
                call(nctx, state_getscr);
            when 2 =>
                call(nctx, state_txscr);
            when 3 =>
                call(nctx, state_rxcmd);
            when 4 =>
                call(nctx, state_cmd);
            when others =>
                ret(nctx);
        end case;
    end procedure proc_loop;
    
    --
    -- proc_main
    --
    procedure proc_main(signal nctx : inout ctx_t; step : in integer) is
    begin
        case step is
            when 0 =>
                call(nctx, state_init);
            when 1 =>
                call(nctx, state_loop);
            when others =>
                goto(nctx, 1);
        end case;
    end procedure proc_main;



    --
    -- State Machine
    --
    procedure state_machine(signal nctx : inout ctx_t) is
        variable frame : frame_t := nctx.stack.frames(nctx.stack.depth);
    begin
        case frame.state is
            when state_main        => proc_main(nctx, frame.step);
            when state_init        => proc_init(nctx, frame.step);
            when state_loop        => proc_loop(nctx, frame.step);
            when state_counter     => proc_counter(nctx, frame.step);
            when state_txscr       => proc_txscr(nctx, frame.step);
            when state_txcrlf      => proc_txcrlf(nctx, frame.step);
            when state_rxcmd       => proc_rxcmd(nctx, frame.step);
            when state_txcmd       => proc_txcmd(nctx, frame.step);
            when state_txres       => proc_txres(nctx, frame.step);
            when state_getscr      => proc_getscr(nctx, frame.step);
            when state_cmd         => proc_cmd(nctx, frame.step);
            when state_cpureg      => proc_cpureg(nctx, frame.step);
            when state_cpuclk      => proc_cpuclk(nctx, frame.step);
            when state_memdump     => proc_memdump(nctx, frame.step);
            when state_memstore    => proc_memstore(nctx, frame.step);
            when state_setaddr     => proc_setaddr(nctx, frame.step);
            when state_parsecmd    => proc_parsecmd(nctx, frame.step);
            when state_noop        => proc_noop(nctx, frame.step);
            when others            => reset(nctx);
        end case;
    end procedure state_machine;
    
begin
    --MEMCTRL_0: entity MemoryController port map (
    --    p_clk => clk, p_addr => mem_addr, p_data => mem_data, p_valid => mem_valid, p_latch => mem_latch, p_store => mem_store);
    
    UART0: entity UART port map (
        p_clk => clk, p_baud => ctx.uart.baud,
        p_rx_pin => uart_rx, p_tx_pin => uart_tx,
        p_rx_dr => ctx.uart.rx_dr, p_rx_clr => ctx.uart.rx_clr, p_rx_data => ctx.uart.rx_data,
        p_tx_cts => ctx.uart.tx_cts, p_tx_send => ctx.uart.tx_send, p_tx_data => ctx.uart.tx_data);

    RAM0: entity WordRAM port map (
        p_clk => clk, p_addr => ctx.mem.addr, p_dataw => ctx.mem.dataw, p_datar => ctx.mem.datar, p_we => ctx.mem.we, p_re => ctx.mem.re);

    CPU0: entity CPUCore port map (
        clk => ctx.cpu.clk,
        mem_addr => ctx.cpu.mem.addr, mem_dataw => ctx.cpu.mem.dataw, mem_datar => ctx.cpu.mem.datar,
        mem_we => ctx.cpu.mem.we, mem_re => ctx.cpu.mem.re,
        reg_sel => ctx.cpu.reg_sel, reg_data => ctx.cpu.reg_data);
    
    
    --
    -- Memory signals
    --
    --ctx.mem.addr      <= ctx.cpu.mem.addr;
    --ctx.mem.dataw     <= ctx.cpu.mem.dataw;
    --ctx.cpu.mem.datar <= ctx.mem.datar;
    --ctx.mem.we        <= ctx.cpu.mem.we;
    --ctx.mem.re        <= ctx.cpu.mem.re;
    
    process(clk, ctx)
    begin
        if (rising_edge(clk)) then
            state_machine(ctx);
        end if;
    end process;

end Behavioral;
