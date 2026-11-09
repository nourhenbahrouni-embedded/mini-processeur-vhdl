-- =====================================================================
--  TOP LEVEL n.2 : mini processeur + LCD 16x2 (HD44780 / LCD1602)
-- ---------------------------------------------------------------------
--  Ecran (valeurs en hexadecimal) :
--      ligne 1 :  PC=005  FETCH1
--      ligne 2 :  A=0027  B=0011
--  sw_mode : 0 = automatique (1 cycle CPU par PERIODE_CPU_MS)
--            1 = pas a pas   (1 cycle CPU par appui sur btn_pas)
--  led(2:0) = etat FSM, led(3) = STP atteint, led(7:4) = opcode (IR)
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_lcd is
    generic (
        CLK_FREQ        : integer := 50000000;
        PERIODE_CPU_MS  : integer := 1000;
        RESET_ACTIF_BAS : boolean := false;
        BTN_ACTIF_BAS   : boolean := false;
        X_INIT          : integer := 17;
        Y_INIT          : integer := 5);
    port (
        clk       : in  std_logic;
        btn_reset : in  std_logic;
        btn_pas   : in  std_logic;
        sw_mode   : in  std_logic;
        lcd_rs    : out std_logic;
        lcd_rw    : out std_logic;
        lcd_e     : out std_logic;
        lcd_db    : out std_logic_vector(7 downto 0);
        led       : out std_logic_vector(7 downto 0));
end top_lcd;

architecture struct of top_lcd is

    -- ------- conversions texte -> codes ASCII ---------------------------
    function car(c : character) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(character'pos(c), 8));
    end function;

    function chaine(s : string) return std_logic_vector is
        variable r : std_logic_vector(8*s'length - 1 downto 0);
    begin
        for i in 0 to s'length - 1 loop
            r(8*(s'length - i) - 1 downto 8*(s'length - i - 1)) := car(s(s'low + i));
        end loop;
        return r;
    end function;

    function hexa(n : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        if unsigned(n) < 10 then
            return std_logic_vector(unsigned'(x"30") + unsigned(n));   -- '0'..'9'
        else
            return std_logic_vector(unsigned'(x"37") + unsigned(n));   -- 'A'..'F'
        end if;
    end function;

    function hexa16(v : std_logic_vector(15 downto 0)) return std_logic_vector is
    begin
        return hexa(v(15 downto 12)) & hexa(v(11 downto 8)) &
               hexa(v(7 downto 4))   & hexa(v(3 downto 0));
    end function;

    type t_noms is array (0 to 7) of std_logic_vector(47 downto 0);
    constant NOMS : t_noms := (chaine("LDA   "), chaine("STO   "), chaine("ADD   "),
                               chaine("SUB   "), chaine("JMP   "), chaine("FETCH1"),
                               chaine("FETCH2"), chaine("STP   "));

    signal reset, pas_sync, pas_imp, tick, ce, mode_sync : std_logic;

    signal acc_sig, b_sig, ir_sig : std_logic_vector(15 downto 0);
    signal pc_sig                 : std_logic_vector(11 downto 0);
    signal etat_sig               : std_logic_vector(2 downto 0);

    signal ligne1, ligne2 : std_logic_vector(127 downto 0);
    signal texte          : std_logic_vector(255 downto 0);

begin

    -- ---------------- entrees ------------------------------------------
    u_rst : entity work.synchro_entree generic map (ACTIF_BAS => RESET_ACTIF_BAS)
        port map (clk => clk, entree => btn_reset, sortie => reset);

    u_pas : entity work.synchro_entree generic map (ACTIF_BAS => BTN_ACTIF_BAS)
        port map (clk => clk, entree => btn_pas, sortie => pas_sync);

    u_mode : entity work.synchro_entree generic map (ACTIF_BAS => false)
        port map (clk => clk, entree => sw_mode, sortie => mode_sync);

    u_ar : entity work.anti_rebond generic map (NB_CYCLES_STABLE => CLK_FREQ / 50)
        port map (clk => clk, entree => pas_sync, impulsion => pas_imp);

    -- ---------------- cadencement ----------------------------------------
    u_tick : entity work.generateur_tick
        generic map (NB_CYCLES => (CLK_FREQ / 1000) * PERIODE_CPU_MS)
        port map (clk => clk, reset => reset, tick => tick);

    ce <= tick when mode_sync = '0' else pas_imp;

    -- ---------------- processeur -----------------------------------------
    u_gup : entity work.gup
        generic map (X_INIT => X_INIT, Y_INIT => Y_INIT)
        port map (g_reset => reset, g_clk => clk, g_ce => ce,
                  g_acc => acc_sig, g_b => b_sig, g_pc => pc_sig,
                  g_ir => ir_sig, g_etat => etat_sig);

    -- ---------------- texte affiche ---------------------------------------
    ligne1 <= chaine("PC=") & hexa(pc_sig(11 downto 8)) & hexa(pc_sig(7 downto 4)) &
              hexa(pc_sig(3 downto 0)) & chaine("  ") &
              NOMS(to_integer(unsigned(etat_sig))) & chaine("  ");

    ligne2 <= chaine("A=") & hexa16(acc_sig) & chaine("  B=") & hexa16(b_sig) & chaine("  ");

    texte <= ligne1 & ligne2;

    u_lcd : entity work.lcd_hd44780
        generic map (CLK_FREQ => CLK_FREQ)
        port map (clk => clk, reset => reset, texte => texte,
                  lcd_rs => lcd_rs, lcd_rw => lcd_rw, lcd_e => lcd_e, lcd_db => lcd_db);

    led(2 downto 0) <= etat_sig;
    led(3)          <= '1' when etat_sig = "111" else '0';
    led(7 downto 4) <= ir_sig(15 downto 12);

end struct;
