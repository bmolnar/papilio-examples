library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package package_defs is
    --type bit_vector is array (natural range <>) of bit;

    constant cache_entries : integer := 4;
    constant BAUD_9600 : std_logic_vector(15 downto 0) := X"0D05";
    constant BAUD_38400 : std_logic_vector(15 downto 0) := X"0341";

    subtype nibble is std_logic_vector(3 downto 0);
    subtype byte is std_logic_vector(7 downto 0);
    subtype word is std_logic_vector(31 downto 0);

    type nibble_vector is array (natural range <>) of nibble;
    type byte_vector is array (natural range <>) of byte;
    type word_vector is array (natural range <>) of word;

    subtype mem_byte is bit_vector(7 downto 0);
    subtype mem_word is bit_vector(15 downto 0);
    subtype mem_addr is bit_vector(15 downto 0);

    subtype cache_tag is bit_vector(9 downto 0);
    type cache_line is array(63 downto 0) of mem_word;
    type cache_flags is record
        valid : bit;
        dirty : bit;
    end record;

    type cache_entry is record
        tag   : cache_tag;
        data  : cache_line;
        flags : cache_flags;
    end record;

    subtype cache_offset is natural;
    subtype cache_index is natural;

    type cache_array is array(0 to (cache_entries - 1)) of cache_entry;
    
    function slv_to_bv (slv : std_logic_vector) return bit_vector;
    function bv_to_slv (bv : bit_vector) return std_logic_vector;
    function bv_to_integer (bv : bit_vector) return integer;

    function slv_to_mem_addr (slv : std_logic_vector) return mem_addr;
    function slv_to_mem_word (slv : std_logic_vector) return mem_word;
    
    function mem_addr_to_cache_tag (addr : mem_addr) return cache_tag;
    function mem_addr_to_cache_offset (addr : mem_addr) return cache_offset;
    function mem_addr_to_cache_index (addr : mem_addr) return cache_index;

    constant str_crlf : byte_vector(0 to 1) := (X"0D", X"0A");
    constant str_ok : byte_vector(0 to 3) := (X"4F", X"4B", X"0D", X"0A");

    constant buf_limit : integer := 16;

    type byte_buffer is record
        limit : integer range 0 to 32;
        pos   : integer range 0 to 32;
        data  : byte_vector(0 to (buf_limit-1));
    end record;

    constant buf_init : byte_buffer := (limit => buf_limit, pos => 0, data => (others => X"00"));
    function buf_new (bv : byte_vector) return byte_buffer;
    function buf_set (buf : byte_buffer; bv : byte_vector) return byte_buffer;
    function buf_set (buf : byte_buffer; b : byte) return byte_buffer;
    function buf_clear (buf : byte_buffer) return byte_buffer;
    function buf_slice (buf : byte_buffer; num : integer) return byte_buffer;
    function buf_shift (buf : byte_buffer; b : byte) return byte_buffer;
    function buf_shift (buf : byte_buffer) return byte_buffer;
    function buf_shift (buf : byte_buffer; num : integer) return byte_buffer;
    function buf_push (buf : byte_buffer; b : byte) return byte_buffer;
    function buf_push (buf : byte_buffer; bv : byte_vector) return byte_buffer;
    function buf_pop (buf : byte_buffer) return byte_buffer;
    function buf_pop (buf : byte_buffer; num : integer) return byte_buffer;
    function buf_find (buf : byte_buffer; b : byte) return integer;
    function buf_eol_idx (buf : byte_buffer) return integer;
    function buf_len (buf : byte_buffer) return integer;
    function buf_free (buf : byte_buffer) return integer;

end package_defs;


package body package_defs is
    function slv_to_bv (slv : std_logic_vector) return bit_vector is
    begin
        return (to_bitvector(slv));
    end function slv_to_bv;

    function bv_to_slv (bv : bit_vector) return std_logic_vector is
    begin
        return (to_stdlogicvector(bv));
    end function bv_to_slv;

        
    function slv_to_mem_addr (slv : std_logic_vector) return mem_addr is
    begin
        return slv_to_bv(slv);
    end function slv_to_mem_addr;
    
    function slv_to_mem_word (slv : std_logic_vector) return mem_word is
    begin
        return slv_to_bv(slv);
    end function slv_to_mem_word;

    function bv_to_integer (bv : bit_vector) return integer is
    begin
        return (to_integer(unsigned(to_stdlogicvector(bv))));
    end function bv_to_integer;

    
    function mem_addr_to_cache_tag (addr : mem_addr) return cache_tag is
    begin
        return addr(15 downto 6);
    end function mem_addr_to_cache_tag;

    function mem_addr_to_cache_offset (addr : mem_addr) return cache_offset is
    begin
        return bv_to_integer(addr(5 downto 0));
    end function mem_addr_to_cache_offset;

    function mem_addr_to_cache_index (addr : mem_addr) return cache_index is
    begin
        return bv_to_integer(mem_addr_to_cache_tag(addr)(1 downto 0));
    end function mem_addr_to_cache_index;


    --
    -- buf_new
    --
    function buf_new (bv : byte_vector) return byte_buffer is
        variable result : byte_buffer := buf_init;
        variable count  : integer := bv'length;
    begin
        if (count > buf_limit) then
            count := buf_limit;
        end if;
        
        for i in 0 to (count-1) loop
            result.data(i) := bv(i);
        end loop;  -- i
        result.pos := count;
        return result;
    end function buf_new;

    --
    -- buf_set
    --
    function buf_set (buf : byte_buffer; bv : byte_vector) return byte_buffer is
        variable result : byte_buffer := buf_clear(buf);
        variable count  : integer := bv'length;
    begin
        if (count > buf.limit) then
            count := buf.limit;
        end if;
        
        for i in 0 to (count-1) loop
            result.data(i) := bv(i);
        end loop;  -- i
        result.pos := count;
        return result;
    end function buf_set;

    --
    -- buf_set
    --
    function buf_set (buf : byte_buffer; b : byte) return byte_buffer is
        variable result : byte_buffer := buf_clear(buf);
    begin
        if (buf.limit > 0) then
            result.data(0) := b;
            result.pos     := 1;
        end if;
        return result;
    end function buf_set;


    --
    -- buf_clear
    --
    function buf_clear (buf : byte_buffer) return byte_buffer is
        variable result : byte_buffer := buf_init;
    begin
        result.limit := buf.limit;
        return result;
    end function buf_clear;


    --
    -- buf_slice
    --
    function buf_slice (buf : byte_buffer; num : integer) return byte_buffer is
        variable result : byte_buffer := buf_clear(buf);
    begin
        if (num < buf.pos) then
            result.data(0 to (num-1)) := buf.data(0 to (num-1));
            result.pos                := num;
        else
            result.data(0 to buf.pos) := buf.data(0 to buf.pos);
            result.pos                := buf.pos;
        end if;
        return result;
    end function buf_slice;


    --
    -- buf_shift
    --
    function buf_shift (buf : byte_buffer; b : byte) return byte_buffer is
        variable result : byte_buffer := buf_clear(buf);
    begin
        result.data(0 to buf.limit-1) := buf.data(1 to buf.limit-1) & b;
        result.pos := buf.pos;
        return result;
    end function buf_shift;

    function buf_shift (buf : byte_buffer) return byte_buffer is
    begin
        return buf_shift(buf, X"00");
    end function buf_shift;

    function buf_shift (buf : byte_buffer; num : integer) return byte_buffer is
        variable result : byte_buffer := buf;
        variable count  : integer := num;
    begin
        while (count > 0) loop
            result := buf_shift(result);
            count := count - 1;
        end loop;
        return result;
    end function buf_shift;


    --
    -- buf_push
    --
    function buf_push (buf : byte_buffer; b : byte) return byte_buffer is
        variable result : byte_buffer := buf_clear(buf);
    begin
        if (buf.pos >= buf.limit) then
            return buf_shift(buf, b);
        else
            result.data(0 to buf.limit-1) := buf.data(0 to buf.limit-1);
            result.data(buf.pos)          := b;
            result.pos                    := buf.pos + 1;
            return result;
        end if;
    end function buf_push;

    function buf_push (buf : byte_buffer; bv : byte_vector) return byte_buffer is
        variable result : byte_buffer := buf;
    begin
        for i in 0 to (bv'length-1) loop
            result := buf_push(buf, bv(0));
        end loop;  -- i
        return result;
    end function buf_push;

    --
    -- buf_pop
    --
    function buf_pop (buf : byte_buffer) return byte_buffer is
        variable result : byte_buffer := buf_clear(buf);
    begin
        if (buf.pos > 0) then
            result     := buf_shift(buf);
            result.pos := buf.pos - 1;
        end if;
        return result;
    end function buf_pop;

    function buf_pop (buf : byte_buffer; num : integer) return byte_buffer is
        variable result : byte_buffer := buf;
        variable count : integer := num;
    begin
        while (count > 0) and (result.pos > 0) loop
            result := buf_pop(result);
        end loop;
        return result;
    end function buf_pop;

    
    function buf_find (buf : byte_buffer; b : byte) return integer is
        variable result : integer := buf_limit;
    begin
        result := buf_limit;
        for i in 0 to (buf_limit-1) loop
            if (result = buf_limit and i < buf.pos and buf.data(i) = b) then
                result := i;
            end if;
        end loop;  -- i
        return result;
    end function buf_find;

    function buf_eol_idx (buf : byte_buffer) return integer is
        variable result : integer;
    begin
        result := buf_limit;
        for i in 0 to (buf_limit-1) loop
            if (result = buf_limit and i < buf.pos and i < buf.limit and buf.data(i) = X"0D") then
                result := i;
            end if;
        end loop;  -- i
        return result;
    end function buf_eol_idx;

    function buf_len (buf : byte_buffer) return integer is
    begin
        return buf.pos;
    end function buf_len;

    function buf_free (buf : byte_buffer) return integer is
    begin
        return (buf.limit - buf.pos);
    end function buf_free;

end package_defs;
