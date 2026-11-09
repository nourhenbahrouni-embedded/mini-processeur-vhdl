-- =====================================================================
--  MINI PROCESSEUR 16 bits (bus d'adresses 12 bits)  -  VERSION FPGA
-- ---------------------------------------------------------------------
--  Difference avec la version "simulation" :
--   * UNE SEULE horloge (celle de la carte, 50 ou 100 MHz) pour tous
--     les registres. Le processeur n'avance que lorsque ce = '1'
--     (clock enable). ce est une impulsion d'un seul cycle generee
--     1 fois par seconde (ou par appui sur un bouton en mode pas a pas).
--     -> plus d'horloge "fabriquee" par un compteur (mauvaise pratique
--        FPGA : skew, violations de hold, horloge hors reseau global).
--   * La FSM, le chemin de donnees et les equations sont INCHANGES.
--   * Sorties d'observation : ACC (=A), B (entree B de l'UAL), PC, IR, etat.
--   * Memoire reduite a 2**TAILLE_ADR mots (512 par defaut) pour ne pas
--     consommer ~1000 LUT en RAM distribuee (4096 x 16 bits).
-- =====================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MuxA is
port (ina0, ina1 : in  std_logic_vector(11 downto 0);
      sel_a      : in  std_logic;
      out_a      : out std_logic_vector(11 downto 0));
end MuxA;

architecture mux_a of MuxA is
begin
    out_a <= ina0 when sel_a = '0' else ina1;
end mux_a;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MuxB is
port (inb0, inb1 : in  std_logic_vector(15 downto 0);
      sel_b      : in  std_logic;
      out_b      : out std_logic_vector(15 downto 0));
end MuxB;

architecture mux_b of MuxB is
begin
    out_b <= inb0 when sel_b = '0' else inb1;
end mux_b;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity instr_reg is
port (clk     : in  STD_LOGIC;
      ce      : in  STD_LOGIC;
      ir_ld   : in  STD_LOGIC;
      ir_in   : in  STD_LOGIC_VECTOR (15 downto 0);
      opcode  : out STD_LOGIC_VECTOR (3 downto 0);
      operand : out STD_LOGIC_VECTOR (11 downto 0);
      ir_out  : out STD_LOGIC_VECTOR (15 downto 0));
end instr_reg;

architecture ir of instr_reg is
    signal reg_ir : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' and ir_ld = '1' then
                reg_ir <= ir_in;
            end if;
        end if;
    end process;

    opcode  <= reg_ir(15 downto 12);
    operand <= reg_ir(11 downto 0);
    ir_out  <= reg_ir;
end ir;

-- ---------------------------------------------------------------------
--  Machine d'etat (equations identiques a la version d'origine)
--  codage : 000 LDA | 001 STO | 010 ADD | 011 SUB | 100 JMP
--           101 FETCH1 | 110 FETCH2 | 111 STP
-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity machine_etat is
port (
    me_opcode : in  std_logic_vector(3 downto 0);
    me_accz   : in  std_logic;
    me_acc15  : in  std_logic;
    reset     : in  std_logic;
    clk       : in  std_logic;
    ce        : in  std_logic;

    me_rnw    : out std_logic;
    me_sela   : out std_logic;
    me_selb   : out std_logic;
    pc_ld     : out std_logic;
    ir_ld     : out std_logic;
    acc_ld    : out std_logic;
    acc_oe    : out std_logic;
    alufs     : out std_logic_vector(3 downto 0);
    me_etat   : out std_logic_vector(2 downto 0));
end machine_etat;

architecture dataflow of machine_etat is

    signal q2 : std_logic := '1';
    signal q1 : std_logic := '0';
    signal q0 : std_logic := '1';

    signal op3, op2, op1, op0 : std_logic;
    signal n2, n1, n0 : std_logic;
    signal d2, d1, d0 : std_logic;

begin

    me_etat <= q2 & q1 & q0;

    op3 <= me_opcode(3);
    op2 <= me_opcode(2);
    op1 <= me_opcode(1);
    op0 <= me_opcode(0);

    n2 <= op3 or op2;
    n1 <= op3 or (not op2 and op1) or (op1 and op0);
    n0 <= op3
          or (op0 and (not op2 or op1 or me_acc15))
          or (op2 and op1 and not op0 and me_accz);

    d2 <= (not q2) or (not q1) or q0 or n2;
    d1 <= (q2 and q0) or (q2 and q1 and n1);
    d0 <= (not q2) or (not q1 and not q0) or (q1 and q0) or (q1 and n0);

    -- le reset agit tout de suite (sans attendre ce), sinon on avance
    -- d'un etat seulement quand ce = '1'
    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' or reset = '1' then
                q2 <= d2 or reset;
                q1 <= d1 and (not reset);
                q0 <= d0 or reset;
            end if;
        end if;
    end process;

    me_rnw  <= q2 or q1 or (not q0);
    me_sela <= (not q2) or (not q1 and not q0);
    me_selb <= not q2;

    alufs(3) <= '0';
    alufs(2) <= '0';
    alufs(1) <= q1 and (not q0);
    alufs(0) <= (q1 and q0) or (q2 and q1);

    ir_ld   <= q2 and (not q1) and q0;
    pc_ld   <= q2 and (not q0);
    acc_ld  <= ((not q2) and (not q0)) or ((not q2) and q1);
    acc_oe  <= (not q2) and (not q1) and q0;

end dataflow;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity prog_counter is
port (
    pc_in  : in  STD_LOGIC_VECTOR(15 downto 0);
    pc_ld  : in  STD_LOGIC;
    reset  : in  STD_LOGIC;
    clk    : in  STD_LOGIC;
    ce     : in  STD_LOGIC;
    pc_out : out STD_LOGIC_VECTOR(11 downto 0));
end prog_counter;

architecture pc of prog_counter is
    signal pc_reg : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                pc_reg <= (others => '0');
            elsif ce = '1' and pc_ld = '1' then
                pc_reg <= pc_in(11 downto 0);
            end if;
        end if;
    end process;

    pc_out <= pc_reg;
end pc;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity accumulateur is
port (clk     : in  STD_LOGIC;
      ce      : in  STD_LOGIC;
      reset   : in  STD_LOGIC;
      acc_ld  : in  STD_LOGIC;
      acc_in  : in  STD_LOGIC_VECTOR (15 downto 0);
      accz    : out STD_LOGIC;
      acc15   : out STD_LOGIC;
      acc_out : out STD_LOGIC_VECTOR (15 downto 0));
end accumulateur;

architecture acc of accumulateur is
    signal reg_acc : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                reg_acc <= (others => '0');
            elsif ce = '1' and acc_ld = '1' then
                reg_acc <= acc_in;
            end if;
        end if;
    end process;

    acc_out <= reg_acc;
    acc15   <= reg_acc(15);
    accz    <= '1' when reg_acc = X"0000" else '0';
end acc;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UAL is
port (
    A     : in  STD_LOGIC_VECTOR(15 downto 0);
    B     : in  STD_LOGIC_VECTOR(15 downto 0);
    alufs : in  STD_LOGIC_VECTOR(3 downto 0);
    S     : out STD_LOGIC_VECTOR(15 downto 0));
end UAL;

architecture behavioral of UAL is
begin
    process(A, B, alufs)
    begin
        case alufs is
            when "0000" => S <= B;
            when "0001" => S <= STD_LOGIC_VECTOR(SIGNED(A) - SIGNED(B));
            when "0010" => S <= STD_LOGIC_VECTOR(SIGNED(A) + SIGNED(B));
            when "0011" => S <= STD_LOGIC_VECTOR(UNSIGNED(B) + 1);
            when others => S <= (others => '0');
        end case;
    end process;
end behavioral;

-- ---------------------------------------------------------------------
--  MEMOIRE : lecture asynchrone (combinatoire), ecriture synchrone
--  validee par ce. Programme de l'enonce :
--     0: LDA @100h   1: ADD @101h   2: JNE 005h   3: SUB @100h
--     4: SUB @100h   5: ADD @100h   6: STP
--  X = mem(100h) = X_INIT , Y = mem(101h) = Y_INIT
--  Resultat : si X+Y /= 0 -> ACC = 2X+Y  sinon ACC = Y (= -X)
-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity memoire is
generic (
    TAILLE_ADR : integer := 9;     -- 9 -> 512 mots (doit etre >= 9 pour @100h)
    X_INIT     : integer := 17;    -- contenu de l'adresse 100h
    Y_INIT     : integer := 5);    -- contenu de l'adresse 101h
port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    rnw         : in  std_logic;
    bus_adr     : in  std_logic_vector(11 downto 0);
    bus_don_in  : in  std_logic_vector(15 downto 0);
    bus_don_out : out std_logic_vector(15 downto 0));
end entity;

architecture mem of memoire is
    type mem_type is array (0 to 2**TAILLE_ADR - 1) of std_logic_vector(15 downto 0);

    function init_mem return mem_type is
        variable m : mem_type := (others => x"0000");
    begin
        m(0)   := x"0100";   -- LDA @100h
        m(1)   := x"2101";   -- ADD @101h
        m(2)   := x"6005";   -- JNE 005h
        m(3)   := x"3100";   -- SUB @100h
        m(4)   := x"3100";   -- SUB @100h
        m(5)   := x"2100";   -- ADD @100h
        m(6)   := x"7000";   -- STP
        m(256) := std_logic_vector(to_signed(X_INIT, 16));   -- X @100h
        m(257) := std_logic_vector(to_signed(Y_INIT, 16));   -- Y @101h
        return m;
    end function;

    signal memory : mem_type := init_mem;

    attribute ram_style : string;
    attribute ram_style of memory : signal is "distributed";

    signal adr : integer range 0 to 2**TAILLE_ADR - 1;
begin
    adr <= to_integer(unsigned(bus_adr(TAILLE_ADR-1 downto 0)));

    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' and rnw = '0' then
                memory(adr) <= bus_don_in;
            end if;
        end if;
    end process;

    bus_don_out <= memory(adr);
end architecture;

-- ---------------------------------------------------------------------
--  "Porte 3 etats" : dans un FPGA il n'y a pas de 3 etats interne,
--  on met donc 0 quand acc_oe = '0' (equivalent fonctionnel).
-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity buffer_tri_state is
port (
    buf_in  : in  std_logic_vector(15 downto 0);
    buf_out : out std_logic_vector(15 downto 0);
    acc_oe  : in  std_logic);
end buffer_tri_state;

architecture buff of buffer_tri_state is
begin
    buf_out <= buf_in when acc_oe = '1' else (others => '0');
end buff;

-- ---------------------------------------------------------------------
--  MICROPROCESSEUR (chemin de donnees + machine d'etat)
-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uProcesseur is
port (
    pro_reset       : in  std_logic;
    pro_clk         : in  std_logic;
    pro_ce          : in  std_logic;
    pro_rnw         : out std_logic;
    pro_bus_adr_out : out std_logic_vector(11 downto 0);
    pro_bus_don_out : out std_logic_vector(15 downto 0);
    pro_bus_don_in  : in  std_logic_vector(15 downto 0);
    pro_acc         : out std_logic_vector(15 downto 0);   -- A (ACC)
    pro_b           : out std_logic_vector(15 downto 0);   -- B (sortie MUXB)
    pro_pc          : out std_logic_vector(11 downto 0);   -- PC
    pro_ir          : out std_logic_vector(15 downto 0);   -- IR
    pro_etat        : out std_logic_vector(2 downto 0));   -- etat FSM
end uProcesseur;

architecture up of uProcesseur is

    signal A_sig       : STD_LOGIC_VECTOR(15 downto 0);
    signal S_sig       : STD_LOGIC_VECTOR(15 downto 0);
    signal B_sig       : STD_LOGIC_VECTOR(15 downto 0);
    signal pc_out_sig  : STD_LOGIC_VECTOR(11 downto 0);
    signal muxb_in     : STD_LOGIC_VECTOR(15 downto 0);
    signal ir_out_sig  : STD_LOGIC_VECTOR(11 downto 0);
    signal ir_full_sig : STD_LOGIC_VECTOR(15 downto 0);
    signal ir_opcode   : STD_LOGIC_VECTOR(3 downto 0);
    signal bus_adr     : STD_LOGIC_VECTOR(11 downto 0);
    signal buf_out_sig : STD_LOGIC_VECTOR(15 downto 0);

    signal accz_sig, acc15_sig : STD_LOGIC;
    signal sela_sig, selb_sig  : STD_LOGIC;
    signal alufs_sig           : STD_LOGIC_VECTOR(3 downto 0);
    signal ir_ld_sig, pc_ld_sig, acc_ld_sig, acc_oe_sig, rnw_sig : STD_LOGIC;
    signal etat_sig            : STD_LOGIC_VECTOR(2 downto 0);

begin

    muxb_in         <= "0000" & bus_adr;
    pro_bus_adr_out <= bus_adr;
    pro_rnw         <= rnw_sig;
    pro_bus_don_out <= buf_out_sig;
    pro_acc         <= A_sig;
    pro_b           <= B_sig;
    pro_pc          <= pc_out_sig;
    pro_ir          <= ir_full_sig;
    pro_etat        <= etat_sig;

    up_me : entity work.machine_etat port map (
        me_opcode => ir_opcode, me_accz => accz_sig, me_acc15 => acc15_sig,
        reset => pro_reset, clk => pro_clk, ce => pro_ce, me_rnw => rnw_sig,
        me_sela => sela_sig, me_selb => selb_sig, pc_ld => pc_ld_sig,
        ir_ld => ir_ld_sig, acc_ld => acc_ld_sig, acc_oe => acc_oe_sig,
        alufs => alufs_sig, me_etat => etat_sig);

    up_muxa : entity work.MuxA port map (
        ina0 => pc_out_sig, ina1 => ir_out_sig, sel_a => sela_sig, out_a => bus_adr);

    up_muxb : entity work.MuxB port map (
        inb0 => muxb_in, inb1 => pro_bus_don_in, sel_b => selb_sig, out_b => B_sig);

    up_ual : entity work.UAL port map (
        A => A_sig, B => B_sig, alufs => alufs_sig, S => S_sig);

    up_acc : entity work.accumulateur port map (
        clk => pro_clk, ce => pro_ce, reset => pro_reset, acc_ld => acc_ld_sig,
        acc_in => S_sig, accz => accz_sig, acc15 => acc15_sig, acc_out => A_sig);

    up_pc : entity work.prog_counter port map (
        pc_in => S_sig, pc_ld => pc_ld_sig, reset => pro_reset,
        clk => pro_clk, ce => pro_ce, pc_out => pc_out_sig);

    up_buf : entity work.buffer_tri_state port map (
        buf_in => A_sig, buf_out => buf_out_sig, acc_oe => acc_oe_sig);

    up_ir : entity work.instr_reg port map (
        clk => pro_clk, ce => pro_ce, ir_ld => ir_ld_sig, ir_in => pro_bus_don_in,
        opcode => ir_opcode, operand => ir_out_sig, ir_out => ir_full_sig);

end up;

-- ---------------------------------------------------------------------
--  GUP = microprocesseur + memoire
-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity gup is
generic (
    X_INIT : integer := 17;
    Y_INIT : integer := 5);
port (
    g_reset : in  std_logic;
    g_clk   : in  std_logic;
    g_ce    : in  std_logic;                        -- avance d'un cycle CPU
    g_acc   : out std_logic_vector(15 downto 0);    -- A
    g_b     : out std_logic_vector(15 downto 0);    -- B
    g_pc    : out std_logic_vector(11 downto 0);
    g_ir    : out std_logic_vector(15 downto 0);
    g_etat  : out std_logic_vector(2 downto 0));
end gup;

architecture microp of gup is
    signal g_rnw         : std_logic;
    signal g_bus_adr     : std_logic_vector(11 downto 0);
    signal g_bus_don_out : std_logic_vector(15 downto 0);
    signal g_bus_don_in  : std_logic_vector(15 downto 0);
begin

    g_processeur : entity work.uProcesseur port map (
        pro_reset       => g_reset,
        pro_clk         => g_clk,
        pro_ce          => g_ce,
        pro_rnw         => g_rnw,
        pro_bus_adr_out => g_bus_adr,
        pro_bus_don_out => g_bus_don_out,
        pro_bus_don_in  => g_bus_don_in,
        pro_acc         => g_acc,
        pro_b           => g_b,
        pro_pc          => g_pc,
        pro_ir          => g_ir,
        pro_etat        => g_etat);

    g_memoire : entity work.memoire
        generic map (TAILLE_ADR => 9, X_INIT => X_INIT, Y_INIT => Y_INIT)
        port map (
        clk         => g_clk,
        ce          => g_ce,
        rnw         => g_rnw,
        bus_adr     => g_bus_adr,
        bus_don_in  => g_bus_don_out,
        bus_don_out => g_bus_don_in);

end microp;
