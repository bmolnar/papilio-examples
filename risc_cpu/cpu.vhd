library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package cpu_defs is
    --
    -- NOOP - No Operation
    -- (advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | 0 0 0 0 0   0 0 0 0 0   0 0 0 0 0   0 0 0 0 0 | 0 0 0 0 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- SLL - Shift Left Logical
    -- ($D = $B << H; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | - - - - - | B B B B B | D D D D D | H H H H H | 0 0 0 0 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- SRL - Shift Right Logical
    -- ($D = $B >> H; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | - - - - - | B B B B B | D D D D D | H H H H H | 0 0 0 0 1 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- SRA - Shift Right Arithmetic
    -- ($D = $B >> H; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | - - - - - | B B B B B | D D D D D | H H H H H | 0 0 0 0 1 1 |
    -- +---------------------------------------------------------------------------+
    --
    -- MFHI - Move From HI
    -- ($D = $HI; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0   0 0 0 0 0   0 0 0 0 0 | D D D D D | 0 0 0 0 0 | 0 1 0 0 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- MFLO - Move From LO
    -- ($D = $LO; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0   0 0 0 0 0   0 0 0 0 0 | D D D D D | 0 0 0 0 0 | 0 1 0 0 1 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- MULT - Multiply
    -- ($LO = $A * $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | 0 0 0 0 0   0 0 0 0 0 | 0 1 1 0 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- DIV - Divide
    -- ($LO = $A / $B; $HI = $A % $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | 0 0 0 0 0   0 0 0 0 0 | 0 1 1 0 1 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- DIVU - Divide Unsigned
    -- ($LO = $A / $B; $HI = $A % $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | 0 0 0 0 0   0 0 0 0 0 | 0 1 1 0 1 1 |
    -- +---------------------------------------------------------------------------+
    --
    -- ADD - Add (With Overflow)
    -- ($D = $A + $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | D D D D D | 0 0 0 0 0 | 1 0 0 0 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- ADDU - Add Unsigned (No Overflow)
    -- ($D = $A + $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | D D D D D | 0 0 0 0 0 | 1 0 0 0 0 1 |
    -- +---------------------------------------------------------------------------+
    --
    -- SUB - Subtract
    -- ($D = $A - $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | D D D D D | 0 0 0 0 0 | 1 0 0 0 1 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- SUBU - Subtract Unsigned
    -- ($D = $A - $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | D D D D D | 0 0 0 0 0 | 1 0 0 0 1 1 |
    -- +---------------------------------------------------------------------------+
    --
    -- AND - Bitwise AND
    -- ($D = $A & $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | D D D D D | 0 0 0 0 0 | 1 0 0 1 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- XOR - Bitwise Exclusive OR
    -- ($D = $A ^ $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | A A A A A | B B B B B | D D D D D | - - - - - | 1 0 0 1 1 0 |
    -- +---------------------------------------------------------------------------+
    --
    --
    --
    --
    -- ADDI - Add Immediate (With Overflow)
    -- ($B = $A + imm; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 1 0 0 0 | A A A A A | B B B B B | I I I I I   I I I I I   I I I I I I | 
    -- +---------------------------------------------------------------------------+
    --
    -- ADDIU - Add Immediate Unsigned (No Overflow)
    -- ($B = $A + imm; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 1 0 0 1 | A A A A A | B B B B B | I I I I I   I I I I I   I I I I I I | 
    -- +---------------------------------------------------------------------------+
    --
    -- ANDI - Bitwise AND Immediate
    -- ($B = $A & imm; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 1 1 0 0 | A A A A A | B B B B B | I I I I I   I I I I I   I I I I I I | 
    -- +---------------------------------------------------------------------------+
    --
    -- SYSCALL - System Call
    -- (advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 0 0 | - - - - -   - - - - -   - - - - -   - - - - - | 0 0 1 1 0 0 |
    -- +---------------------------------------------------------------------------+
    --
    -- BEQ - Branch on Equal
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 1 0 0 | A A A A A | B B B B B | I I I I I   I I I I I   I I I I I I |
    -- +---------------------------------------------------------------------------+
    --
    -- J - Jump
    -- +---------------------------------------------------------------------------+
    -- | 0 0 0 0 1 0 | I I I I I   I I I I I   I I I I I   I I I I I   I I I I I I |
    -- +---------------------------------------------------------------------------+
    --
    -- LW - Load Word
    -- ($B = MEM[$A + offset]; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 1 0 0 0 1 1 | A A A A A | B B B B B | I I I I I   I I I I I   I I I I I I |
    -- +---------------------------------------------------------------------------+
    --
    -- SW - Store Word
    -- (MEM[$A + offset] = $B; advance_pc (4);)
    -- +---------------------------------------------------------------------------+
    -- | 1 0 1 0 1 1 | A A A A A | B B B B B | I I I I I   I I I I I   I I I I I I |
    -- +---------------------------------------------------------------------------+

    constant ALU_FUNC_SLL     : std_logic_vector(5 downto 0) := "000000";
    constant ALU_FUNC_SRL     : std_logic_vector(5 downto 0) := "000010";
    constant ALU_FUNC_SRA     : std_logic_vector(5 downto 0) := "000011";
    constant ALU_FUNC_SLLV    : std_logic_vector(5 downto 0) := "000100";
    constant ALU_FUNC_SRLV    : std_logic_vector(5 downto 0) := "000110";
    constant ALU_FUNC_SYSCALL : std_logic_vector(5 downto 0) := "001100";
    constant ALU_FUNC_MFHI    : std_logic_vector(5 downto 0) := "010000";
    constant ALU_FUNC_MFLO    : std_logic_vector(5 downto 0) := "010010";
    constant ALU_FUNC_MULT    : std_logic_vector(5 downto 0) := "011000";
    constant ALU_FUNC_MULTU   : std_logic_vector(5 downto 0) := "011001";
    constant ALU_FUNC_DIV     : std_logic_vector(5 downto 0) := "011010";
    constant ALU_FUNC_DIVU    : std_logic_vector(5 downto 0) := "011011";
    constant ALU_FUNC_ADD     : std_logic_vector(5 downto 0) := "100000";
    constant ALU_FUNC_ADDU    : std_logic_vector(5 downto 0) := "100001";
    constant ALU_FUNC_SUB     : std_logic_vector(5 downto 0) := "100010";
    constant ALU_FUNC_SUBU    : std_logic_vector(5 downto 0) := "100011";
    constant ALU_FUNC_AND     : std_logic_vector(5 downto 0) := "100100";
    constant ALU_FUNC_OR      : std_logic_vector(5 downto 0) := "100101";
    constant ALU_FUNC_XOR     : std_logic_vector(5 downto 0) := "100110";
    constant ALU_FUNC_SLT     : std_logic_vector(5 downto 0) := "101010";
    constant ALU_FUNC_SLTU    : std_logic_vector(5 downto 0) := "101011";
    
    constant CPU_OP_RTYPE     : std_logic_vector(5 downto 0) := "000000";
    constant CPU_OP_BLTZ      : std_logic_vector(5 downto 0) := "000001";
    constant CPU_OP_BLTZAL    : std_logic_vector(5 downto 0) := "000001";
    constant CPU_OP_BGEZ      : std_logic_vector(5 downto 0) := "000001";
    constant CPU_OP_BGEZAL    : std_logic_vector(5 downto 0) := "000001";
    constant CPU_OP_J         : std_logic_vector(5 downto 0) := "000010";
    constant CPU_OP_JAL       : std_logic_vector(5 downto 0) := "000011";
    constant CPU_OP_BEQ       : std_logic_vector(5 downto 0) := "000100";
    constant CPU_OP_BNE       : std_logic_vector(5 downto 0) := "000101";
    constant CPU_OP_BLEZ      : std_logic_vector(5 downto 0) := "000110";
    constant CPU_OP_BGTZ      : std_logic_vector(5 downto 0) := "000111";
    constant CPU_OP_ADDI      : std_logic_vector(5 downto 0) := "001000";
    constant CPU_OP_ADDIU     : std_logic_vector(5 downto 0) := "001001";
    constant CPU_OP_SLTI      : std_logic_vector(5 downto 0) := "001010";
    constant CPU_OP_SLTIU     : std_logic_vector(5 downto 0) := "001011";
    constant CPU_OP_ANDI      : std_logic_vector(5 downto 0) := "001100";
    constant CPU_OP_ORI       : std_logic_vector(5 downto 0) := "001101";
    constant CPU_OP_XORI      : std_logic_vector(5 downto 0) := "001110";
    constant CPU_OP_LUI       : std_logic_vector(5 downto 0) := "001111";
    constant CPU_OP_LB        : std_logic_vector(5 downto 0) := "100000";
    constant CPU_OP_LW        : std_logic_vector(5 downto 0) := "100011";
    constant CPU_OP_SB        : std_logic_vector(5 downto 0) := "101000";
    constant CPU_OP_SW        : std_logic_vector(5 downto 0) := "101011";
end cpu_defs;

package body cpu_defs is
end cpu_defs;

--
-- MUX_2
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MUX_2 is
    port (
        sel        : in   std_logic_vector(0 downto 0);
        in0        : in   std_logic_vector;
        in1        : in   std_logic_vector;
        output     : out  std_logic_vector
        );
end MUX_2;

architecture Behavioral of MUX_2 is
begin
    output <= in0 when (sel = "0") else
              in1;
end Behavioral;


--
-- MUX_4
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity MUX_4 is
    port (
        sel        : in   std_logic_vector(1 downto 0);
        in00       : in   std_logic_vector;
        in01       : in   std_logic_vector;
        in10       : in   std_logic_vector;
        in11       : in   std_logic_vector;
        output     : out  std_logic_vector
        );
end MUX_4;

architecture Behavioral of MUX_4 is
begin
    output <= in00 when (sel = "00") else
              in01 when (sel = "01") else
              in10 when (sel = "10") else
              in11;
end Behavioral;



--
-- SignExtend_16to32
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SignExtend_16to32 is
    port (
        input        : in   std_logic_vector(15 downto 0);
        output       : out  std_logic_vector(31 downto 0)
        );
end SignExtend_16to32;

architecture Behavioral of SignExtend_16to32 is
begin
    output <= X"FFFF" & input when (input(15) = '1') else X"0000" & input;
end Behavioral;


--
-- SignExtend
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SignExtend is
    port (
        input        : in   std_logic_vector;
        output       : out  std_logic_vector
        );
end SignExtend;

architecture Behavioral of SignExtend is
begin
    output((output'length-1) downto input'length) <= (others => '1') when (input(input'length-1) = '1') else (others => '0');
    output((input'length-1) downto 0) <= input;
end Behavioral;



--
-- Combine
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Combine is
    port (
        in31to28     : in   std_logic_vector(3 downto 0);
        in27to0      : in   std_logic_vector(27 downto 0);
        output       : out  std_logic_vector(31 downto 0)
        );
end Combine;

architecture Behavioral of Combine is
begin
    output <= in31to28 & in27to0;
end Behavioral;


--
-- SLL_N
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SLL_N is
    port (
        n            : in   integer range -32 to 31;
        input        : in   std_logic_vector(31 downto 0);
        output       : out  std_logic_vector(31 downto 0)
        );
end SLL_N;

architecture Behavioral of SLL_N is
begin
    output <= input when (n = 0) else
              input(29 downto 0) & "00" when (n = 2) else
              input;
end Behavioral;



--
-- LatchRegister
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity LatchRegister is
    port (
        clk        : in   std_logic;
        en         : in   std_logic;
        d          : in   std_logic_vector;
        q          : out  std_logic_vector
        );
end LatchRegister;

architecture Behavioral of LatchRegister is
begin
    process(clk)
    begin
        if (rising_edge(clk) and en = '1') then
            q <= d;
        end if;
    end process;
end Behavioral;










--
-- RegisterFile
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RegisterFile is
    port (
        clk        : in  std_logic;
        selRA      : in  std_logic_vector(4 downto 0);
        selRB      : in  std_logic_vector(4 downto 0);
        selW       : in  std_logic_vector(4 downto 0);
        dataRA     : out std_logic_vector(31 downto 0);
        dataRB     : out std_logic_vector(31 downto 0);
        dataW      : in  std_logic_vector(31 downto 0);
        enW        : in std_logic
        );
end RegisterFile;

architecture Behavioral of RegisterFile is
    type regs_t is array (0 to 31) of std_logic_vector(31 downto 0);
    signal regs : regs_t := (others => (others => '0'));

begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            dataRA <= regs(to_integer(unsigned(selRA)));
            dataRB <= regs(to_integer(unsigned(selRB)));
            if (enW = '1') then
                regs(to_integer(unsigned(selW))) <= dataW;
            end if;
        end if;
    end process;
end Behavioral;


--
-- ALU
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.cpu_defs.all;

entity ALU is
    port (
        funct       : in    std_logic_vector(5 downto 0);
        inA         : in    std_logic_vector(31 downto 0);
        inB         : in    std_logic_vector(31 downto 0);
        result      : out   std_logic_vector(31 downto 0);
        zero        : out   std_logic
        );
end ALU;

architecture Behavioral of ALU is
    signal res : std_logic_vector(31 downto 0);

begin
    result <= std_logic_vector(unsigned(inA) + unsigned(inB)) when (funct = ALU_FUNC_ADDU) else
              X"00000000";
    
    zero <= '1' when (funct = ALU_FUNC_SUB and inA = inB) else
            '1' when (funct = ALU_FUNC_SUBU and inA = inB) else
            '0';
end Behavioral;


--
-- ALUControl
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.cpu_defs.all;

entity ALUControl is
    port (
        instr       : in    std_logic_vector(5 downto 0);
        oper        : in    std_logic_vector(1 downto 0);
        funct       : out   std_logic_vector(5 downto 0)
        );
end ALUControl;

architecture Behavioral of ALUControl is
begin
    funct <= ALU_FUNC_ADD when (oper = "00") else
             ALU_FUNC_SUB when (oper = "01") else
             instr;
end Behavioral;


--
-- CPUControl
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.cpu_defs.all;

entity CPUControl is
    port (
        clk      : in  std_logic;
        instr    : in  std_logic_vector(5 downto 0);
        alusrcb  : out std_logic_vector(1 downto 0);
        alusrca  : out std_logic_vector(0 downto 0);
        regwrite : out std_logic;
        regdst   : out std_logic_vector(0 downto 0);
        aluop    : out std_logic_vector(1 downto 0);
        pcsrc    : out std_logic_vector(1 downto 0);
        pcwcond  : out std_logic;
        pcwrite  : out std_logic;
        iord     : out std_logic_vector(0 downto 0);
        memread  : out std_logic;
        memwrite : out std_logic;
        memtoreg : out std_logic;
        irwrite  : out std_logic
        );
end CPUControl;

architecture Behavioral of CPUControl is
    signal state : integer range 0 to 9 := 0;
begin
    process(clk)
    begin
        if (rising_edge(clk)) then
            case state is
                when 0 =>
                    --
                    -- Initial State
                    --
                    alusrca <= "0";     -- REG_PC
                    alusrcb <= "01";    -- 0x00000004
                    pcsrc <= "00";      -- ALU
                    iord <= "0";        -- PC
                    aluop <= "00";      -- ADD
                    memread <= '1';
                    irwrite <= '1';
                    pcwrite <= '1';
                    state <= 1;
                when 1 =>
                    --
                    -- Instruction Decode
                    --
                    alusrca <= "0";     -- PC
                    alusrcb <= "11";    -- sign_extend(REG_IR(15 downto 0)) << 2
                    aluop <= "00";      -- ADD
                    case instr is
                        when CPU_OP_SW =>
                            state <= 2;
                        when CPU_OP_LW =>
                            state <= 2;
                        when CPU_OP_RTYPE =>
                            state <= 6;
                        when CPU_OP_BEQ =>
                            state <= 8;
                        when CPU_OP_J =>
                            state <= 9;
                        when others =>
                            state <= 0;
                    end case;
                when 2 =>
                    --
                    -- Memory Address Computation
                    --
                    alusrca <= "1";     -- REG_A
                    alusrcb <= "10";    -- sign_extend(REG_IR(15 downto 0))
                    aluop <= "00";      -- ADD
                    case instr is
                        when CPU_OP_LW =>
                            state <= 3;
                        when CPU_OP_SW =>
                            state <= 5;
                        when others =>
                            state <= 0;
                    end case;
                when 3 =>
                    --
                    -- Memory Access (READ)
                    --
                    iord <= "1";        -- REG_ALU
                    memread <= '1';
                    state <= 4;
                when 4 =>
                    --
                    -- Memory Read Completion
                    --
                    regdst <= "1";      -- REG[REG_IR(15 downto 11)] 
                    memtoreg <= '0';    -- REG_ALU
                    regwrite <= '1';
                    state <= 0;
                when 5 =>
                    --
                    -- Memory Access (WRITE)
                    --
                    iord <= "1";        -- REG_ALU
                    memwrite <= '1';
                    state <= 0;
                when 6 =>
                    --
                    -- Execution
                    --
                    alusrca <= "1";     -- REG_PC
                    alusrcb <= "00";    -- REG_B
                    aluop <= "10";      -- REG_IR(5 downto 0)
                    state <= 7;
                when 7 =>
                    --
                    -- Execution Completion
                    --
                    regdst <= "1";      -- REG[REG_IR(15 downto 11)] 
                    memtoreg <= '0';    -- REG_ALU
                    regwrite <= '1';
                    state <= 0;
                when 8 =>
                    --
                    -- Branch Completion
                    --
                    alusrca <= "1";     -- REG_PC
                    alusrcb <= "00";    -- REG_B
                    aluop <= "01";
                    pcwcond <= '1';
                    pcsrc <= "01";      -- ALUOUT
                    state <= 0;
                when 9 =>
                    --
                    -- Jump Completion
                    --
                    pcwrite <= '1';
                    pcsrc <= "10";       -- PC(31 downto 28) & instr(25 downto 0) & "00";
                when others => null;
            end case;
        end if;
    end process;
end Behavioral;


--
-- CPUCore
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.cpu_defs.all;

entity CPUCore is
    port (
        clk         : in    std_logic;

        mem_addr    : out   std_logic_vector(31 downto 0);
        mem_dataw   : out   std_logic_vector(31 downto 0);
        mem_datar   : in    std_logic_vector(31 downto 0);
        mem_we      : out   std_logic;
        mem_re      : out   std_logic;

        reg_sel     : in    std_logic_vector(2 downto 0);
        reg_data    : out   std_logic_vector(31 downto 0)
        );
end CPUCore;

architecture Structural of CPUCore is
    component SignExtend_16to32
        port (
            input      : in   std_logic_vector(15 downto 0);
            output     : out  std_logic_vector(31 downto 0)
        );
    end component;

    component SLL_N
        port (
            n          : in   integer range -32 to 31;
            input      : in   std_logic_vector(31 downto 0);
            output     : out  std_logic_vector(31 downto 0)
            );
    end component;

    component MUX_2
        port (
            sel        : in   std_logic_vector(0 downto 0);
            in0        : in   std_logic_vector;
            in1        : in   std_logic_vector;
            output     : out  std_logic_vector
            );
    end component;

    component MUX_4
        port (
            sel        : in   std_logic_vector(1 downto 0);
            in00       : in   std_logic_vector;
            in01       : in   std_logic_vector;
            in10       : in   std_logic_vector;
            in11       : in   std_logic_vector;
            output     : out  std_logic_vector
            );
    end component;
    
    component Combine
        port (
            in31to28     : in   std_logic_vector(3 downto 0);
            in27to0      : in   std_logic_vector(27 downto 0);
            output       : out  std_logic_vector(31 downto 0)
            );
    end component;

    component ALU
        port (
            funct       : in    std_logic_vector(5 downto 0);
            inA         : in    std_logic_vector(31 downto 0);
            inB         : in    std_logic_vector(31 downto 0);
            result      : out   std_logic_vector(31 downto 0);
            zero        : out   std_logic
            );
    end component;

    component ALUControl
        port (
            instr       : in    std_logic_vector(5 downto 0);
            oper        : in    std_logic_vector(1 downto 0);
            funct       : out   std_logic_vector(5 downto 0)
            );
    end component;

    component LatchRegister
        port (
            clk        : in   std_logic;
            en         : in   std_logic;
            d          : in   std_logic_vector;
            q          : out  std_logic_vector
            );
    end component;

    component RegisterFile
        port (
            clk        : in  std_logic;
            selRA      : in  std_logic_vector(4 downto 0);
            selRB      : in  std_logic_vector(4 downto 0);
            selW       : in  std_logic_vector(4 downto 0);
            dataRA     : out std_logic_vector(31 downto 0);
            dataRB     : out std_logic_vector(31 downto 0);
            dataW      : in  std_logic_vector(31 downto 0);
            enW        : in std_logic
            );
    end component;

    component CPUControl
        port (
            clk      : in  std_logic;
            instr    : in  std_logic_vector(5 downto 0);
            alusrcb  : out std_logic_vector(1 downto 0);
            alusrca  : out std_logic_vector(0 downto 0);
            regwrite : out std_logic;
            regdst   : out std_logic_vector(0 downto 0);
            aluop    : out std_logic_vector(1 downto 0);
            pcsrc    : out std_logic_vector(1 downto 0);
            pcwcond  : out std_logic;
            pcwrite  : out std_logic;
            iord     : out std_logic_vector(0 downto 0);
            memread  : out std_logic;
            memwrite : out std_logic;
            memtoreg : out std_logic;
            irwrite  : out std_logic
            );
    end component;

    signal regfile_selra  : std_logic_vector(4 downto 0) := (others => '0');
    signal regfile_selrb  : std_logic_vector(4 downto 0) := (others => '0');
    signal regfile_selw   : std_logic_vector(4 downto 0) := (others => '0');
    signal regfile_datara : std_logic_vector(31 downto 0) := (others => '0');
    signal regfile_datarb : std_logic_vector(31 downto 0) := (others => '0');
    signal regfile_dataw  : std_logic_vector(31 downto 0) := (others => '0');
    signal regfile_enw    : std_logic := '0';

    signal reg_pc_en   : std_logic := '0';
    signal reg_pc_out  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_ir_out  : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_mdr_out : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_alu_out : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_a_out   : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_b_out   : std_logic_vector(31 downto 0) := (others => '0');

    signal alu_funct  : std_logic_vector(5 downto 0) := (others => '0');
    signal alu_inA    : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_inB    : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_result : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_zero   : std_logic := '0';

    signal ctrl_alusrcb  : std_logic_vector(1 downto 0) := (others => '0');
    signal ctrl_alusrca  : std_logic_vector(0 downto 0) := (others => '0');
    signal ctrl_regwrite : std_logic := '0';
    signal ctrl_regdst   : std_logic_vector(0 downto 0) := (others => '0');
    signal ctrl_aluop    : std_logic_vector(1 downto 0) := (others => '0');
    signal ctrl_pcsrc    : std_logic_vector(1 downto 0) := (others => '0');
    signal ctrl_pcwcond  : std_logic := '0';
    signal ctrl_pcwrite  : std_logic := '0';
    signal ctrl_iord     : std_logic_vector(0 downto 0) := (others => '0');
    signal ctrl_memread  : std_logic := '0';
    signal ctrl_memwrite : std_logic := '0';
    signal ctrl_memtoreg : std_logic := '0';
    signal ctrl_irwrite  : std_logic := '0';

    signal combine_out   : std_logic_vector(31 downto 0) := (others => '0');
    
    signal signext0_out  : std_logic_vector(31 downto 0) := (others => '0');
    signal sll0_out      : std_logic_vector(31 downto 0) := (others => '0');
    signal sll1_out      : std_logic_vector(31 downto 0) := (others => '0');
    signal mux_pc_out    : std_logic_vector(31 downto 0) := (others => '0');

    constant UNCONN      : std_logic := '0';
    constant UNCONN32    : std_logic_vector(31 downto 0) := (others => '0');
    constant UNCONN31to26 : std_logic_vector(31 downto 26) := (others => '0');
begin
    reg_data <= reg_pc_out when (reg_sel = "000") else
                reg_ir_out when (reg_sel = "001") else
                reg_mdr_out when (reg_sel = "010") else
                reg_alu_out when (reg_sel = "011") else
                reg_a_out when (reg_sel = "100") else
                reg_b_out when (reg_sel = "101") else
                (others => '0');
    
    --
    -- CPU State Machine
    --
    CPUCTRL0: CPUControl port map (
        clk => clk, instr => reg_ir_out(31 downto 26), alusrcb => ctrl_alusrcb, alusrca => ctrl_alusrca,
        regwrite => ctrl_regwrite, regdst => ctrl_regdst, aluop => ctrl_aluop, pcsrc => ctrl_pcsrc,
        pcwcond => ctrl_pcwcond, pcwrite => ctrl_pcwrite, iord => ctrl_iord, memread => ctrl_memread,
        memwrite => ctrl_memwrite, memtoreg => ctrl_memtoreg, irwrite => ctrl_irwrite);

    --
    -- Register File
    --
    REGFILE0: RegisterFile port map (
        clk => clk,
        selRA => regfile_selra, selRB => regfile_selrb, selW => regfile_selw,
        dataRA => regfile_datara, dataRB => regfile_datarb, dataW => regfile_dataw,
        enW => regfile_enw);

    --
    -- Arithmetic and Logic Unit
    --
    ALU0: ALU port map (
        funct => alu_funct, inA => alu_inA, inB => alu_inB, result => alu_result, zero => alu_zero);
    ALUCTRL0: ALUControl port map (
        instr => reg_ir_out(5 downto 0), oper => ctrl_aluop, funct => alu_funct);

    reg_pc_en <= '1' when (ctrl_pcwrite = '1' or (alu_zero = '1' and ctrl_pcwcond = '1')) else '0';
    
    --
    -- Registers
    --
    REG_PC0 : LatchRegister port map (clk => clk, en => reg_pc_en,    d => mux_pc_out,     q => reg_pc_out);
    REG_IR0 : LatchRegister port map (clk => clk, en => ctrl_irwrite, d => mem_datar,      q => reg_ir_out);
    REG_MDR0: LatchRegister port map (clk => clk, en => '1',          d => mem_datar,      q => reg_mdr_out);
    REG_ALU0: LatchRegister port map (clk => clk, en => '1',          d => alu_result,     q => reg_alu_out);
    REG_A0  : LatchRegister port map (clk => clk, en => '1',          d => regfile_datara, q => reg_a_out);
    REG_B0  : LatchRegister port map (clk => clk, en => '1',          d => regfile_datarb, q => reg_b_out);

    --
    -- Multiplexers
    --
    MUX_ALU_A: MUX_2 port map (
        sel => ctrl_alusrca, in0 => reg_pc_out, in1 => reg_a_out, output => alu_inA);
    MUX_ALU_B: MUX_4 port map (
        sel => ctrl_alusrcb, in00 => reg_b_out, in01 => X"00000004", in10 => signext0_out, in11 => sll0_out, output => alu_inB);
    MUX_PC: MUX_4 port map (
        sel => ctrl_pcsrc, in00 => alu_result, in01 => reg_alu_out, in10 => combine_out, in11 => UNCONN32, output => mux_pc_out);
    MUX_ADDR: MUX_2 port map (
        sel => ctrl_iord, in0 => reg_pc_out, in1 => reg_alu_out, output => mem_addr);

    --
    -- Combine
    --
    COMBINE0: Combine port map (in31to28 => reg_pc_out(31 downto 28), in27to0 => sll1_out(27 downto 0), output => combine_out);
    
    --
    -- Shift Left Logical
    --
    SLL0: SLL_N port map (n => 2, input => signext0_out, output => sll0_out);
    SLL1: SLL_N port map (n => 2, input(31 downto 26) => UNCONN31to26, input(25 downto 0) => reg_ir_out(25 downto 0), output => sll1_out);
    SIGNEXT0: SignExtend_16to32 port map (input => reg_ir_out(15 downto 0), output => signext0_out);
end Structural;
