-- =====================================================================
--  TESTBENCH du processeur seul (SIMULATION UNIQUEMENT)
--  ce = '1' en permanence -> 1 cycle CPU par front d'horloge.
--  Deux processeurs en parallele pour tester les 2 branches de JNE :
--    DUT1 : X = 17, Y = 5  -> X+Y /= 0 -> ACC = 2X+Y = 39
--    DUT2 : X = 5,  Y = -5 -> X+Y  = 0 -> ACC = Y    = -5
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_gup is
end tb_gup;

architecture sim of tb_gup is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal ce    : std_logic := '1';

    signal acc1, b1, ir1, acc2, b2, ir2 : std_logic_vector(15 downto 0);
    signal pc1, pc2                     : std_logic_vector(11 downto 0);
    signal etat1, etat2                 : std_logic_vector(2 downto 0);

    constant CLK_PERIOD : time := 20 ns;
    signal sim_done : boolean := false;

    function nom_etat(e : std_logic_vector(2 downto 0)) return string is
    begin
        case e is
            when "000"  => return "LDA   ";
            when "001"  => return "STO   ";
            when "010"  => return "ADD   ";
            when "011"  => return "SUB   ";
            when "100"  => return "JMP   ";
            when "101"  => return "FETCH1";
            when "110"  => return "FETCH2";
            when "111"  => return "STP   ";
            when others => return "????  ";
        end case;
    end function;

begin

    DUT1 : entity work.gup generic map (X_INIT => 17, Y_INIT => 5)
        port map (g_reset => reset, g_clk => clk, g_ce => ce,
                  g_acc => acc1, g_b => b1, g_pc => pc1, g_ir => ir1, g_etat => etat1);

    DUT2 : entity work.gup generic map (X_INIT => 5, Y_INIT => -5)
        port map (g_reset => reset, g_clk => clk, g_ce => ce,
                  g_acc => acc2, g_b => b2, g_pc => pc2, g_ir => ir2, g_etat => etat2);

    clk_process : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim_process : process
    begin
        reset <= '1';
        wait for CLK_PERIOD * 3;
        wait until falling_edge(clk);
        reset <= '0';
        report "=== DUT1 : X=17 Y=5 ===";

        for i in 0 to 40 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            report "cycle " & integer'image(i) &
                   "  etat=" & nom_etat(etat1) &
                   "  PC="  & integer'image(to_integer(unsigned(pc1))) &
                   "  A="   & integer'image(to_integer(signed(acc1))) &
                   "  B="   & integer'image(to_integer(signed(b1)));
            exit when etat1 = "111" and etat2 = "111";
        end loop;

        assert to_integer(signed(acc1)) = 39
            report "ECHEC DUT1 : ACC = " & integer'image(to_integer(signed(acc1))) & " (attendu 39)"
            severity error;
        assert to_integer(signed(acc2)) = -5
            report "ECHEC DUT2 : ACC = " & integer'image(to_integer(signed(acc2))) & " (attendu -5)"
            severity error;
        assert etat1 = "111" and etat2 = "111"
            report "ECHEC : STP non atteint" severity error;

        report "=== FIN : DUT1 ACC=" & integer'image(to_integer(signed(acc1))) &
               " (attendu 39)   DUT2 ACC=" & integer'image(to_integer(signed(acc2))) &
               " (attendu -5) ===";
        sim_done <= true;
        wait;
    end process;

end sim;
