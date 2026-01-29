--
-- ByteRAM
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.package_defs.all;

entity ByteRAM is
    Port (
        p_clk       : in    std_logic;
        p_addr      : in    std_logic_vector(15 downto 0);
        p_datain    : in    std_logic_vector(7 downto 0);
        p_dataout   : out   std_logic_vector(7 downto 0);
        p_we        : in    std_logic
        );

end ByteRAM;

architecture Behavioral of ByteRAM is
    type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);
    signal ram : ram_t := (others => (others => '0'));

begin
    process(p_clk)
    begin
        if (rising_edge(p_clk)) then
            if (p_we = '1') then
                ram(to_integer(unsigned(p_addr(7 downto 0)))) <= p_datain;
            end if;
            p_dataout <= ram(to_integer(unsigned(p_addr(7 downto 0))));
        end if;
    end process;
    
end Behavioral;



--
-- WordRAM
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.package_defs.all;

entity WordRAM is
    Port (
        p_clk       : in    std_logic;
        p_addr      : in    std_logic_vector(31 downto 0);
        p_dataw     : in    std_logic_vector(31 downto 0);
        p_datar     : out   std_logic_vector(31 downto 0);
        p_we        : in    std_logic;
        p_re        : in    std_logic
        );

end WordRAM;

architecture Behavioral of WordRAM is
    type ram_t is array (0 to 4095) of std_logic_vector(31 downto 0);
    signal ram : ram_t := (others => (others => '0'));

begin
    process(p_clk)
    begin
        if (rising_edge(p_clk)) then
            if (p_we = '1') then
                ram(to_integer(unsigned(p_addr(11 downto 0)))) <= p_dataw;
            end if;
            if (p_re = '1') then
                p_datar <= ram(to_integer(unsigned(p_addr(11 downto 0))));
            end if;
        end if;
    end process;
    
end Behavioral;



--
-- MemoryController
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.package_defs.all;

entity MemoryController is
    Port (
        p_clk       : in    std_logic;
        p_addr      : in    std_logic_vector(15 downto 0);
        p_data      : inout std_logic_vector(15 downto 0);
        p_valid     : out   std_logic;

        p_latch     : in    std_logic;
        p_store     : in    std_logic
        );

    type cache_loc is record
        tag   : cache_tag;
        index : cache_index;
        offset: cache_offset;
    end record;

    type mem_req is record
        addr  : mem_addr;
        data  : mem_word;
        store : std_logic;
        valid : std_logic;
    end record;
end MemoryController;

architecture Behavioral of MemoryController is
    signal cache    : cache_array := (others => (tag => (others => '0'), data => (others => "0101010101010101"), flags => (valid => '1', dirty => '0')));

    signal req      : mem_req := (addr => (others => '0'), data => (others => '0'), store => '0', valid => '0');
    signal next_req : mem_req := (addr => (others => '0'), data => (others => '0'), store => '0', valid => '0');

begin
    process(p_clk, req, p_latch, p_addr, p_data, p_store)
    begin
        if (rising_edge(p_clk)) then
            next_req <= req;
            if (p_latch = '1') then
                next_req.addr <= slv_to_bv(p_addr);
                next_req.valid <= '0';
                if (p_store = '1') then
                    next_req.store <= '1';
                    next_req.data <= slv_to_bv(p_data);
                else
                    next_req.store <= '0';
                end if;
                p_valid <= '0';
            else
                p_data <= bv_to_slv(req.data);
                p_valid <= req.valid and not req.store;
            end if;
        end if;
    end process;

    process(p_clk, next_req)
        variable loc : cache_loc;
    begin
        if (rising_edge(p_clk)) then
            req <= next_req;

            loc.tag := mem_addr_to_cache_tag(next_req.addr);
            loc.index := mem_addr_to_cache_index(next_req.addr);
            loc.offset := mem_addr_to_cache_offset(next_req.addr);

            if (loc.tag /= cache(loc.index).tag) then
                cache(loc.index).tag <= loc.tag;
                cache(loc.index).flags.valid <= '0';
                cache(loc.index).flags.dirty <= '0';
                req.valid <= '0';
            else
                if (cache(loc.index).flags.valid = '0') then
                    for i in 0 to 63 loop
                        cache(loc.index).data(i) <= cache(loc.index).tag & "000000";
                    end loop;  -- i
                    cache(loc.index).flags.valid <= '1';
                    req.valid <= '0';
                else
                    req.valid <= '1';
                    if (next_req.store = '1') then
                        cache(loc.index).data(loc.offset) <= next_req.data;
                        req.store <= '0';
                    else
                        req.data <= cache(loc.index).data(loc.offset);
                    end if;
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;
