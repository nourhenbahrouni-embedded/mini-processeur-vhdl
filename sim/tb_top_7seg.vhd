-- =====================================================================
--  TESTBENCH de top_7seg (SIMULATION UNIQUEMENT)
--  Horloge "reduite" (CLK_FREQ = 1 MHz, 1 cycle CPU par ms) pour que
--  la simulation soit rapide. Le testbench RELIT les afficheurs
--  (an + seg) et reconstitue la valeur affichee a 4 chiffres.
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_top_7seg is
end tb_top_7seg;

architecture sim of tb_top_7seg is

    constant CLK_PERIOD : time := 1 us;          -- 1 MHz
    signal clk       : std_logic := '0';
    signal btn_reset : std_logic := '1';
    signal btn_pas   : std_logic := '0';
    signal sw_mode   : std_logic := '0';
    signal sw_sel    : std_logic_vector(1 downto 0) := "00";
    signal seg       : std_logic_vector(6 downto 0);
    signal dp        : std_logic;
    signal an        : std_logic_vector(3 downto 0);
    signal led       : std_logic_vector(7 downto 0);
    signal sim_done  : boolean := false;

    -- segments actifs bas -> chiffre hexa (16 = motif inconnu)
    function seg_vers_hex(s : std_logic_vector(6 downto 0)) return integer is
        variable v : std_logic_vector(6 downto 0);
    begin
        v := not s;
        case v is
            when "0111111" => return 0;   when "0000110" => return 1;
            when "1011011" => return 2;   when "1001111" => return 3;
            when "1100110" => return 4;   when "1101101" => return 5;
            when "1111101" => return 6;   when "0000111" => return 7;
            when "1111111" => return 8;   when "1101111" => return 9;
            when "1110111" => return 10;  when "1111100" => return 11;
            when "0111001" => return 12;  when "1011110" => return 13;
            when "1111001" => return 14;  when "1110001" => return 15;
            when others    => return 16;
        end case;
    end function;

    function hex_str(v : integer) return string is
        constant H : string(1 to 16) := "0123456789ABCDEF";
        variable r : string(1 to 4);
        variable x : integer := v;
    begin
        for i in 4 downto 1 loop
            r(i) := H((x mod 16) + 1);
            x := x / 16;
        end loop;
        return r;
    end function;

begin

    DUT : entity work.top_7seg
        generic map (CLK_FREQ => 1000000, PERIODE_CPU_MS => 1)
        port map (clk => clk, btn_reset => btn_reset, btn_pas => btn_pas,
                  sw_mode => sw_mode, sw_sel => sw_sel,
                  seg => seg, dp => dp, an => an, led => led);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim : process
        variable digits : integer;
        variable valeur : integer;
        variable vu     : std_logic_vector(3 downto 0);
        type t_attendu is array (0 to 3) of integer;
        constant ATTENDU : t_attendu := (16#0027#, 16#0007#, 16#0007#, 16#7000#);
        constant NOMS    : string := "A  B  PC IR ";

        -- lit les 4 digits multiplexes et renvoie la valeur affichee
        procedure lire_afficheur(variable res : out integer) is
            variable d   : integer;
            variable acc : integer;
        begin
            acc := 0;  vu := "0000";
            while vu /= "1111" loop
                wait until rising_edge(clk);
                for k in 0 to 3 loop
                    if an(k) = '0' then          -- digit k allume (actif bas)
                        d := seg_vers_hex(seg);
                        assert d < 16 report "motif 7seg invalide" severity error;
                        if vu(k) = '0' then
                            acc := acc + d * (16 ** k);
                            vu(k) := '1';
                        end if;
                    end if;
                end loop;
            end loop;
            res := acc;
        end procedure;

    begin
        btn_reset <= '1';
        wait for 10 us;
        btn_reset <= '0';

        -- ===== mode automatique : on attend la fin du programme =====
        wait for 30 ms;                       -- 30 cycles CPU (~15 suffisent)
        assert led(2 downto 0) = "111" report "ECHEC : STP non atteint" severity error;

        for s in 0 to 3 loop
            sw_sel <= std_logic_vector(to_unsigned(s, 2));
            wait for 10 ms;                   -- laisse le balayage se stabiliser
            lire_afficheur(valeur);
            report "sel=" & integer'image(s) & " (" & NOMS(3*s+1 to 3*s+3) &
                   ")  affiche = " & hex_str(valeur) &
                   "   attendu = " & hex_str(ATTENDU(s));
            assert valeur = ATTENDU(s) report "ECHEC affichage" severity error;
        end loop;

        -- ===== mode pas a pas : 3 appuis -> FETCH1, FETCH2, LDA -> FETCH1 =====
        sw_mode   <= '1';
        sw_sel    <= "00";
        btn_reset <= '1';  wait for 10 us;  btn_reset <= '0';
        wait for 5 ms;
        assert led(2 downto 0) = "101" report "ECHEC : apres reset on doit etre en FETCH1" severity error;

        for p in 1 to 3 loop
            -- appui avec rebonds
            for r in 1 to 5 loop
                btn_pas <= '1'; wait for 200 us; btn_pas <= '0'; wait for 150 us;
            end loop;
            btn_pas <= '1'; wait for 40 ms;
            btn_pas <= '0'; wait for 40 ms;
            report "pas a pas : appui " & integer'image(p) &
                   "  etat(led) = " & integer'image(to_integer(unsigned(led(2 downto 0))));
        end loop;
        wait for 5 ms;
        lire_afficheur(valeur);
        report "pas a pas : apres 3 appuis A = " & hex_str(valeur) & " (attendu 0011 = 17)";
        assert valeur = 16#0011# report "ECHEC pas a pas (valeur)" severity error;
        assert led(2 downto 0) = "101" report "ECHEC pas a pas (etat)" severity error;

        report "=== FIN tb_top_7seg ===";
        sim_done <= true;
        wait;
    end process;

end sim;
