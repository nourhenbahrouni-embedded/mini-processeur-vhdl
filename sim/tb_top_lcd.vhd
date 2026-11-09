-- =====================================================================
--  TESTBENCH de top_lcd (SIMULATION UNIQUEMENT)
--  Contient un petit MODELE d'ecran HD44780 : il capte les ecritures
--  (front descendant de E) et reconstruit les 2 lignes de l'ecran,
--  qu'on affiche dans le transcript a chaque cycle CPU.
--  CLK_FREQ reduite a 1 MHz et 1 cycle CPU toutes les 20 ms.
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_top_lcd is
end tb_top_lcd;

architecture sim of tb_top_lcd is

    constant CLK_PERIOD : time := 1 us;
    signal clk       : std_logic := '0';
    signal btn_reset : std_logic := '1';
    signal btn_pas   : std_logic := '0';
    signal sw_mode   : std_logic := '0';
    signal lcd_rs, lcd_rw, lcd_e : std_logic;
    signal lcd_db    : std_logic_vector(7 downto 0);
    signal led       : std_logic_vector(7 downto 0);
    signal sim_done  : boolean := false;

    -- "memoire d'affichage" du modele LCD
    signal ecran_l1, ecran_l2 : string(1 to 16) := (others => '.');
    signal nb_init_38         : integer := 0;

begin

    DUT : entity work.top_lcd
        generic map (CLK_FREQ => 1000000, PERIODE_CPU_MS => 20)
        port map (clk => clk, btn_reset => btn_reset, btn_pas => btn_pas,
                  sw_mode => sw_mode, lcd_rs => lcd_rs, lcd_rw => lcd_rw,
                  lcd_e => lcd_e, lcd_db => lcd_db, led => led);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- ---------------- modele simplifie du HD44780 ----------------------
    modele_lcd : process
        variable adr : integer range 0 to 127 := 0;
        variable c   : character;
    begin
        wait until falling_edge(lcd_e);        -- le LCD echantillonne sur E descendant
        assert lcd_rw = '0' report "RW doit etre a 0" severity error;
        if lcd_rs = '0' then
            if lcd_db = x"38" then
                nb_init_38 <= nb_init_38 + 1;
            elsif lcd_db = x"01" then
                ecran_l1 <= (others => ' ');  ecran_l2 <= (others => ' ');  adr := 0;
            elsif lcd_db(7) = '1' then
                adr := to_integer(unsigned(lcd_db(6 downto 0)));
            end if;
        else
            c := character'val(to_integer(unsigned(lcd_db)));
            if adr <= 15 then
                ecran_l1(adr + 1) <= c;
            elsif adr >= 16#40# and adr <= 16#4F# then
                ecran_l2(adr - 16#40# + 1) <= c;
            end if;
            if adr < 127 then adr := adr + 1; end if;
        end if;
    end process;

    -- ---------------- stimuli et observation ---------------------------
    stim : process
    begin
        btn_reset <= '1';
        wait for 10 us;
        btn_reset <= '0';

        wait for 70 ms;      -- init du LCD (50 ms d'attente + commandes)
        assert nb_init_38 >= 4 report "ECHEC : sequence d'init LCD absente" severity error;

        for i in 0 to 15 loop
            report "LCD  |" & ecran_l1 & "|   |" & ecran_l2 & "|";
            wait for 20 ms;  -- un cycle CPU
        end loop;

        report "LCD final  |" & ecran_l1 & "|   |" & ecran_l2 & "|";
        assert ecran_l1 = "PC=007  STP     " report "ECHEC ligne 1" severity error;
        assert ecran_l2 = "A=0027  B=0007  " report "ECHEC ligne 2" severity error;

        report "=== FIN tb_top_lcd ===";
        sim_done <= true;
        wait;
    end process;

end sim;
