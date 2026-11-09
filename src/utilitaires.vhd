-- =====================================================================
--  UTILITAIRES pour la carte
--   * generateur_tick : impulsion d'UN cycle de clk tous les NB_CYCLES
--                       (remplace le "diviseur d'horloge")
--   * synchro_entree  : synchronisation 2 bascules + choix de polarite
--                       (boutons actifs bas sur beaucoup de cartes !)
--   * anti_rebond     : filtre les rebonds d'un bouton et sort UNE
--                       impulsion d'un cycle par appui (mode pas a pas)
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity generateur_tick is
    generic (NB_CYCLES : integer := 50000000);   -- 50 MHz -> 1 tick/s
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        tick  : out std_logic);
end generateur_tick;

architecture rtl of generateur_tick is
    signal compteur : integer range 0 to NB_CYCLES-1 := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            tick <= '0';
            if reset = '1' then
                compteur <= 0;
            elsif compteur = NB_CYCLES-1 then
                compteur <= 0;
                tick     <= '1';
            else
                compteur <= compteur + 1;
            end if;
        end if;
    end process;
end rtl;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity synchro_entree is
    generic (ACTIF_BAS : boolean := false);
    port (
        clk     : in  std_logic;
        entree  : in  std_logic;     -- broche physique
        sortie  : out std_logic);    -- '1' = actif, synchronise sur clk
end synchro_entree;

architecture rtl of synchro_entree is
    signal s1, s2 : std_logic := '0';
    signal e      : std_logic;
begin
    e <= not entree when ACTIF_BAS else entree;

    process(clk)
    begin
        if rising_edge(clk) then
            s1 <= e;
            s2 <= s1;
        end if;
    end process;

    sortie <= s2;
end rtl;

-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity anti_rebond is
    generic (NB_CYCLES_STABLE : integer := 1000000);   -- 20 ms a 50 MHz
    port (
        clk      : in  std_logic;
        entree   : in  std_logic;    -- deja synchronisee, '1' = appuye
        impulsion: out std_logic);   -- 1 cycle a '1' a chaque appui
end anti_rebond;

architecture rtl of anti_rebond is
    signal compteur : integer range 0 to NB_CYCLES_STABLE := 0;
    signal stable   : std_logic := '0';
    signal stable_d : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if entree = stable then
                compteur <= 0;
            elsif compteur = NB_CYCLES_STABLE then
                stable   <= entree;
                compteur <= 0;
            else
                compteur <= compteur + 1;
            end if;
            stable_d <= stable;
        end if;
    end process;

    impulsion <= stable and not stable_d;   -- front montant
end rtl;
