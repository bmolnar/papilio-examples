library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.package_defs.all;

package asciibin is
    function is_hexchar(b : std_logic_vector(7 downto 0)) return boolean;
    function is_printable(b : std_logic_vector(7 downto 0)) return boolean;

    function zero_bits(width : integer) return std_logic_vector;

    function str_len(b : byte_vector) return integer;
    function str_hexlen(b : byte_vector) return integer;
    
    function bit_to_binchar(b : std_logic) return std_logic_vector;
    function byte_to_char(b : std_logic_vector(7 downto 0)) return std_logic_vector;
    function char_to_byte(c : character) return std_logic_vector;
    function nibble_to_hexchar(b : std_logic_vector(3 downto 0)) return std_logic_vector;
    function hexchar_to_nibble(b : std_logic_vector(7 downto 0)) return std_logic_vector;

    function decode_hexchars(b : byte_vector; width : integer) return std_logic_vector;
    
    function group_cnt(b : std_logic_vector; width : integer) return integer;
    function get_group(b : std_logic_vector; width : integer; num : integer) return std_logic_vector;
    
    function to_nibbles(b : std_logic_vector) return nibble_vector;
    function to_bytes(b : std_logic_vector) return byte_vector;
    function to_bits(b : byte_vector) return std_logic_vector;
    
    function to_hexchars(b : std_logic_vector) return byte_vector;
    function to_hexchars(b : byte_vector) return byte_vector;
    function to_hexchars(b : nibble_vector) return byte_vector;

    function to_chars(b : byte_vector) return byte_vector;
end asciibin;

package body asciibin is
    function is_hexchar(b : std_logic_vector(7 downto 0)) return boolean is
    begin
        return ((b >= X"30" and b <= X"39") or (b >= X"41" and b <= X"46") or (b >= X"61" and b <= X"66"));
    end function is_hexchar;

    function is_printable(b : std_logic_vector(7 downto 0)) return boolean is
    begin
        return (b >= X"20" and b <= X"7E");
    end function is_printable;

    function zero_bits(width : integer) return std_logic_vector is
        variable result : std_logic_vector((width-1) downto 0) := (others => '0');
    begin
        return result;
    end function zero_bits;
    
    function str_len(b : byte_vector) return integer is
        variable result : integer range 0 to 255 := b'length;
    begin
        for i in 0 to (b'length-1) loop
            if ((b(i) = X"00") and (i < result)) then
                result := i;
            end if;
        end loop;
        return result;
    end function str_len;

    function str_hexlen(b : byte_vector) return integer is
        variable result : integer range 0 to 255 := b'length;
        variable iter : byte;
    begin
        for i in 1 to (b'length-1) loop
            iter := b(i);
            if (not is_hexchar(iter)) and (i < result) then
                result := i;
            end if;
        end loop;
        return result;
    end function str_hexlen;

    
    function bit_to_binchar(b : std_logic) return std_logic_vector is
    begin
        if (b = '1') then
            return X"31";
        else
            return X"30";
        end if;
    end function bit_to_binchar;

    function byte_to_char(b : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        if (b >= X"20" and b <= X"7E") then
            return b;
        else
            return X"2E";
        end if;
    end function byte_to_char;

    function char_to_byte(c : character) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(natural(character'pos(c)), 8));
    end function char_to_byte;
    
    function nibble_to_hexchar(b : std_logic_vector(3 downto 0)) return std_logic_vector is
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
    end function nibble_to_hexchar;

    function hexchar_to_nibble(b : std_logic_vector(7 downto 0)) return std_logic_vector is
    begin
        case b is
            when X"30" => return X"0";
            when X"31" => return X"1";
            when X"32" => return X"2";
            when X"33" => return X"3";
            when X"34" => return X"4";
            when X"35" => return X"5";
            when X"36" => return X"6";
            when X"37" => return X"7";
            when X"38" => return X"8";
            when X"39" => return X"9";
            when X"41" => return X"A";
            when X"42" => return X"B";
            when X"43" => return X"C";
            when X"44" => return X"D";
            when X"45" => return X"E";
            when X"46" => return X"F";
            when X"61" => return X"A";
            when X"62" => return X"B";
            when X"63" => return X"C";
            when X"64" => return X"D";
            when X"65" => return X"E";
            when X"66" => return X"F";
            when others => return X"0";
        end case;
    end function hexchar_to_nibble;

    function decode_hexchars(b : byte_vector; width : integer) return std_logic_vector is
        variable len     : integer := str_hexlen(b);
        variable bidx    : integer range -128 to 127;
        variable left    : integer;
        variable nibble  : std_logic_vector(3 downto 0);
        variable result  : std_logic_vector((width-1) downto 0) := (others => '0');
    begin
        for i in (((width+3)/4) - 1) downto 0 loop
            bidx := ((len - 1) - i);
            if (bidx >= 0) then
                nibble := hexchar_to_nibble(b(bidx));
            else
                nibble := "0000";
            end if;

            left := (width - 4*i);
            if (left < 4) then
                result((4*i + left - 1) downto (4*i)) := nibble((left-1) downto 0);
            else
                result((4*i+3) downto (4*i)) := nibble(3 downto 0);
            end if;
        end loop;
        return result;
    end function decode_hexchars;

    function group_cnt(b : std_logic_vector; width : integer) return integer is
    begin
        return ((b'length + (width - 1)) / width);
    end function group_cnt;
    
    function get_group(b : std_logic_vector; width : integer; num : integer) return std_logic_vector is
        alias bv : std_logic_vector(b'length-1 downto 0) is b;
        variable result   : std_logic_vector((width-1) downto 0) := (others => '0');
        variable offset   : integer;
        variable left     : integer;
    begin
        offset := (width * num);
        left   := (b'length - offset);

        if (left >= width) then
            result                      := bv((offset + width - 1) downto offset);
        elsif (left > 0) then
            result((left - 1) downto 0) := bv((offset + left - 1) downto offset);
        end if;
        return result;
    end function get_group;



    function to_nibbles(b : std_logic_vector) return nibble_vector is
        variable result : nibble_vector(0 to (group_cnt(b, 4) - 1));
    begin
        for i in 0 to (group_cnt(b, 4) - 1) loop
            result(i) := get_group(b, 4, (group_cnt(b, 4) - 1 - i));
        end loop;  -- i
        return result;
    end function to_nibbles;

    function to_bytes(b : std_logic_vector) return byte_vector is
        variable result : byte_vector(0 to (group_cnt(b, 8) - 1));
    begin
        for i in 0 to (group_cnt(b, 8) - 1) loop
            result(i) := get_group(b, 8, (group_cnt(b, 8) - 1 - i));
        end loop;  -- i
        return result;
    end function to_bytes;

    function to_words(b : std_logic_vector) return word_vector is
        variable result : word_vector(0 to (group_cnt(b, 32) - 1));
    begin
        for i in 0 to (group_cnt(b, 32) - 1) loop
            result(i) := get_group(b, 32, (group_cnt(b, 32) - 1 - i));
        end loop;  -- i
        return result;
    end function to_words;

    function to_bits(b : byte_vector) return std_logic_vector is
        variable result : std_logic_vector((b'length*8)-1 downto 0);
    begin
        for i in 0 to (b'length-1) loop
            result((8*i+7) downto (8*i)) := b((b'length-1) - i);
        end loop;  -- i
        return result;
    end function to_bits;
        

    function to_hexchars(b : nibble_vector) return byte_vector is
        variable result   : byte_vector(0 to (b'length-1));
    begin
        for i in 0 to (b'length-1) loop
            result(i)   := nibble_to_hexchar(b(i));
        end loop;  -- i
        return result;
    end function to_hexchars;
    
    function to_hexchars(b : std_logic_vector) return byte_vector is
    begin
        return to_hexchars(to_nibbles(b));
    end function to_hexchars;

    function to_hexchars(b : byte_vector) return byte_vector is
        variable result   : byte_vector(0 to ((b'length*2)-1));
    begin
        for i in 0 to (b'length-1) loop
            result(2*i)   := nibble_to_hexchar(b(i)(7 downto 4));
            result(2*i+1) := nibble_to_hexchar(b(i)(3 downto 0));
        end loop;  -- i
        return result;
    end function to_hexchars;


    function to_chars(b : byte_vector) return byte_vector is
        variable result : byte_vector(0 to (b'length-1));
    begin
        for i in 0 to (b'length-1) loop
            result(i) := byte_to_char(b(i));
        end loop;  -- i
        return result;
    end function to_chars;

end asciibin;


--
-- asciibin_bool
--

library IEEE;
use IEEE.std_logic_1164.all;
use work.asciibin.all;

entity asciibin_bool is
    Port (
        datain    : in    std_logic;
        charout   : out   std_logic_vector(7 downto 0)
        );
end entity asciibin_bool;

architecture Behavioral of asciibin_bool is
begin
    charout <= bit_to_binchar(datain);
end architecture Behavioral;


--
-- asciibin_4
--

library IEEE;
use IEEE.std_logic_1164.all;
use work.asciibin.all;

entity asciibin_4 is
    Port (
        datain    : in    std_logic_vector(3 downto 0);
        charout   : out   std_logic_vector(7 downto 0)
        );
end entity asciibin_4;

architecture Behavioral of asciibin_4 is
begin
    charout <= nibble_to_hexchar(datain);
end architecture Behavioral;


--
-- asciibin_8
--

library IEEE;
use IEEE.std_logic_1164.all;
use work.asciibin.all;

entity asciibin_8 is
    Port (
        datain    : in    std_logic_vector(7 downto 0);
        charoutH  : out   std_logic_vector(7 downto 0);
        charoutL  : out   std_logic_vector(7 downto 0)
        );
end entity asciibin_8;

architecture Behavioral of asciibin_8 is
begin
    charoutH <= nibble_to_hexchar(datain(7 downto 4));
    charoutL <= nibble_to_hexchar(datain(3 downto 0));
end architecture Behavioral;


--
-- asciibin_16
--

library IEEE;
use IEEE.std_logic_1164.all;
use work.asciibin.all;

entity asciibin_16 is
    Port (
        datain    : in    std_logic_vector(15 downto 0);
        charoutHH : out   std_logic_vector(7 downto 0);
        charoutHL : out   std_logic_vector(7 downto 0);
        charoutLH : out   std_logic_vector(7 downto 0);
        charoutLL : out   std_logic_vector(7 downto 0)
        );
end entity asciibin_16;

architecture Behavioral of asciibin_16 is
begin
    charoutHH <= nibble_to_hexchar(datain(15 downto 12));
    charoutHL <= nibble_to_hexchar(datain(11 downto 8));
    charoutLH <= nibble_to_hexchar(datain(7 downto 4));
    charoutLL <= nibble_to_hexchar(datain(3 downto 0));
end architecture Behavioral;


--
-- asciibin_32
--

library IEEE;
use IEEE.std_logic_1164.all;
use work.asciibin.all;

entity asciibin_32 is
    Port (
        datain    : in    std_logic_vector(31 downto 0);
        charoutHHH : out   std_logic_vector(7 downto 0);
        charoutHHL : out   std_logic_vector(7 downto 0);
        charoutHLH : out   std_logic_vector(7 downto 0);
        charoutHLL : out   std_logic_vector(7 downto 0);
        charoutLHH : out   std_logic_vector(7 downto 0);
        charoutLHL : out   std_logic_vector(7 downto 0);
        charoutLLH : out   std_logic_vector(7 downto 0);
        charoutLLL : out   std_logic_vector(7 downto 0)
        );
end entity asciibin_32;

architecture Behavioral of asciibin_32 is
begin
    charoutHHH <= nibble_to_hexchar(datain(31 downto 28));
    charoutHHL <= nibble_to_hexchar(datain(27 downto 24));
    charoutHLH <= nibble_to_hexchar(datain(23 downto 20));
    charoutHLL <= nibble_to_hexchar(datain(19 downto 16));
    charoutLHH <= nibble_to_hexchar(datain(15 downto 12));
    charoutLHL <= nibble_to_hexchar(datain(11 downto 8));
    charoutLLH <= nibble_to_hexchar(datain(7 downto 4));
    charoutLLL <= nibble_to_hexchar(datain(3 downto 0));
end architecture Behavioral;


--
-- asciibin_char
--

library IEEE;
use IEEE.std_logic_1164.all;
use work.asciibin.all;

entity asciibin_char is
    Port (
        datain    : in    std_logic_vector(7 downto 0);
        charout   : out   std_logic_vector(7 downto 0)
        );
end entity asciibin_char;

architecture Behavioral of asciibin_char is
begin
    charout <= byte_to_char(datain);
end architecture Behavioral;
