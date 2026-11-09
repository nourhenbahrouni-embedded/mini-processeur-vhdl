-- =====================================================================
--  TOP LEVEL n.1 : mini processeur + 4 afficheurs 7 segments + LEDs
-- ---------------------------------------------------------------------
--  sw_sel(1:0) : 00 = A (ACC)   01 = B (entree B de l'UAL)
--                10 = PC         11 = IR (instruction courante)
--  sw_mode     : 0 = automatique (1 cycle CPU toutes les PERIODE_CPU_MS)
--                1 = pas a pas   (1 cycle CPU par appui sur btn_pas)
--  led(2:0) = etat FSM, led(3) = STP atteint, led(7:4) = opcode (IR)
--  ATTENTION : 1 instruction = 3 cycles CPU (FETCH1, FETCH2, EXEC).
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_7seg is
    generic (
        CLK_FREQ        : integer := 50000000;  -- horloge de la carte (Hz)
        PERIODE_CPU_MS  : integer := 1000;      -- 1 cycle CPU par seconde
        RESET_ACTIF_BAS : boolean := false;     -- true si le bouton reset vaut 0 appuye
        BTN_ACTIF_BAS   : boolean := false;     -- idem pour le bouton pas a pas
        SEG_ACTIF_BAS   : boolean := true;      -- segments actifs a 0 (anode commune)
        AN_ACTIF_BAS    : boolean := true;      -- selection digit active a 0
        X_INIT          : integer := 17;
        Y_INIT          : integer := 5);
    port (
        clk       : in  std_logic;
        btn_reset : in  std_logic;
        btn_pas   : in  std_logic;
        sw_mode   : in  std_logic;
        sw_sel    : in  std_logic_vector(1 downto 0);
        seg       : out std_logic_vector(6 downto 0);
        dp        : out std_logic;
        an        : out std_logic_vector(3 downto 0);
        led       : out std_logic_vector(7 downto 0));
end top_7seg;

architecture struct of top_7seg is

    signal reset, pas_sync, pas_imp, tick, ce : std_logic;
    signal mode_sync                          : std_logic;
    signal sel_sync                           : std_logic_vector(1 downto 0);

    signal acc_sig, b_sig, ir_sig : std_logic_vector(15 downto 0);
    signal pc_sig                 : std_logic_vector(11 downto 0);
    signal etat_sig               : std_logic_vector(2 downto 0);
    signal valeur_affichee        : std_logic_vector(15 downto 0);

begin

    -- ---------------- entrees (synchronisation, anti-rebond) ----------
    u_rst : entity work.synchro_entree generic map (ACTIF_BAS => RESET_ACTIF_BAS)
        port map (clk => clk, entree => btn_reset, sortie => reset);

    u_pas : entity work.synchro_entree generic map (ACTIF_BAS => BTN_ACTIF_BAS)
        port map (clk => clk, entree => btn_pas, sortie => pas_sync);

    u_mode : entity work.synchro_entree generic map (ACTIF_BAS => false)
        port map (clk => clk, entree => sw_mode, sortie => mode_sync);

    u_sel0 : entity work.synchro_entree generic map (ACTIF_BAS => false)
        port map (clk => clk, entree => sw_sel(0), sortie => sel_sync(0));

    u_sel1 : entity work.synchro_entree generic map (ACTIF_BAS => false)
        port map (clk => clk, entree => sw_sel(1), sortie => sel_sync(1));

    u_ar : entity work.anti_rebond generic map (NB_CYCLES_STABLE => CLK_FREQ / 50)
        port map (clk => clk, entree => pas_sync, impulsion => pas_imp);

    -- ---------------- cadencement du processeur -----------------------
    u_tick : entity work.generateur_tick
        generic map (NB_CYCLES => (CLK_FREQ / 1000) * PERIODE_CPU_MS)
        port map (clk => clk, reset => reset, tick => tick);

    ce <= tick when mode_sync = '0' else pas_imp;

    -- ---------------- le processeur + memoire -------------------------
    u_gup : entity work.gup
        generic map (X_INIT => X_INIT, Y_INIT => Y_INIT)
        port map (g_reset => reset, g_clk => clk, g_ce => ce,
                  g_acc => acc_sig, g_b => b_sig, g_pc => pc_sig,
                  g_ir => ir_sig, g_etat => etat_sig);

    -- ---------------- affichage ---------------------------------------
    with sel_sync select
        valeur_affichee <= acc_sig          when "00",
                           b_sig            when "01",
                           "0000" & pc_sig  when "10",
                           ir_sig           when others;

    u_aff : entity work.afficheur_4digits
        generic map (REFRESH_DIVISOR => CLK_FREQ / 1000,   -- 1 ms par digit
                     SEG_ACTIF_BAS   => SEG_ACTIF_BAS,
                     AN_ACTIF_BAS    => AN_ACTIF_BAS)
        port map (clk => clk, reset => reset, valeur => valeur_affichee,
                  seg => seg, dp => dp, an => an);

    led(2 downto 0) <= etat_sig;
    led(3)          <= '1' when etat_sig = "111" else '0';
    led(7 downto 4) <= ir_sig(15 downto 12);

end struct;
