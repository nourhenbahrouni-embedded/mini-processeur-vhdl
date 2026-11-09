-- =====================================================================
--  AFFICHAGE 7 SEGMENTS
--  Ordre des bits de seg : (6)=g (5)=f (4)=e (3)=d (2)=c (1)=b (0)=a
--  Polarites SEPAREES pour les segments et pour les anodes (digits),
--  car selon les cartes elles ne sont pas forcement les memes.
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decodeur_7seg is
    generic (ACTIF_BAS : boolean := true);
    port (
        bin : in  std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0));
end decodeur_7seg;

architecture rtl of decodeur_7seg is
    signal seg_int : std_logic_vector(6 downto 0);   -- '1' = segment allume
begin
    process(bin)
    begin
        case bin is
            when "0000" => seg_int <= "0111111"; -- 0
            when "0001" => seg_int <= "0000110"; -- 1
            when "0010" => seg_int <= "1011011"; -- 2
            when "0011" => seg_int <= "1001111"; -- 3
            when "0100" => seg_int <= "1100110"; -- 4
            when "0101" => seg_int <= "1101101"; -- 5
            when "0110" => seg_int <= "1111101"; -- 6
            when "0111" => seg_int <= "0000111"; -- 7
            when "1000" => seg_int <= "1111111"; -- 8
            when "1001" => seg_int <= "1101111"; -- 9
            when "1010" => seg_int <= "1110111"; -- A
            when "1011" => seg_int <= "1111100"; -- b
            when "1100" => seg_int <= "0111001"; -- C
            when "1101" => seg_int <= "1011110"; -- d
            when "1110" => seg_int <= "1111001"; -- E
            when "1111" => seg_int <= "1110001"; -- F
            when others => seg_int <= "0000000";
        end case;
    end process;

    seg <= not seg_int when ACTIF_BAS else seg_int;
end rtl;

-- ---------------------------------------------------------------------
--  AFFICHEUR MULTIPLEXE 4 CHIFFRES HEXA (horloge RAPIDE de la carte)
--  an(0) = chiffre de poids faible ... an(3) = poids fort
-- ---------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity afficheur_4digits is
    generic (
        REFRESH_DIVISOR : integer := 50000;   -- 50 MHz / 50000 = 1 kHz par digit
        SEG_ACTIF_BAS   : boolean := true;
        AN_ACTIF_BAS    : boolean := true);
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        valeur : in  std_logic_vector(15 downto 0);
        seg    : out std_logic_vector(6 downto 0);
        dp     : out std_logic;
        an     : out std_logic_vector(3 downto 0));
end afficheur_4digits;

architecture rtl of afficheur_4digits is
    signal compteur_refresh : integer range 0 to REFRESH_DIVISOR-1 := 0;
    signal digit_sel        : unsigned(1 downto 0) := (others => '0');
    signal nibble           : std_logic_vector(3 downto 0);
    signal an_actif_haut    : std_logic_vector(3 downto 0);   -- '1' = digit allume
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                compteur_refresh <= 0;
                digit_sel        <= (others => '0');
            elsif compteur_refresh = REFRESH_DIVISOR-1 then
                compteur_refresh <= 0;
                digit_sel        <= digit_sel + 1;
            else
                compteur_refresh <= compteur_refresh + 1;
            end if;
        end if;
    end process;

    with digit_sel select
        nibble <= valeur(3 downto 0)   when "00",
                  valeur(7 downto 4)   when "01",
                  valeur(11 downto 8)  when "10",
                  valeur(15 downto 12) when others;

    with digit_sel select
        an_actif_haut <= "0001" when "00",
                         "0010" when "01",
                         "0100" when "10",
                         "1000" when others;

    an <= not an_actif_haut when AN_ACTIF_BAS else an_actif_haut;
    dp <= '1' when SEG_ACTIF_BAS else '0';          -- point decimal eteint

    u_dec : entity work.decodeur_7seg
        generic map (ACTIF_BAS => SEG_ACTIF_BAS)
        port map (bin => nibble, seg => seg);

end rtl;
