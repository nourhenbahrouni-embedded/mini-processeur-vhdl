-- =====================================================================
--  CONTROLEUR LCD caracteres 16x2 (HD44780 / LCD1602), mode 8 bits
--  * RW force a '0' (ecriture seulement), on ne lit pas le busy flag :
--    on attend simplement assez longtemps apres chaque commande.
--  * Le contenu des 32 caracteres est reecrit en boucle (~2 ms par
--    rafraichissement complet) : l'ecran suit les registres en direct.
--  texte(255 downto 248) = 1er caractere de la ligne 1 (a gauche)
--  texte(127 downto 120) = 1er caractere de la ligne 2
-- =====================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity lcd_hd44780 is
    generic (CLK_FREQ : integer := 50000000);     -- frequence de clk en Hz
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        texte  : in  std_logic_vector(255 downto 0);
        lcd_rs : out std_logic;
        lcd_rw : out std_logic;
        lcd_e  : out std_logic;
        lcd_db : out std_logic_vector(7 downto 0));
end lcd_hd44780;

architecture rtl of lcd_hd44780 is

    function max1(x : integer) return integer is
    begin
        if x < 1 then return 1; else return x; end if;
    end function;

    constant US : integer := max1(CLK_FREQ / 1000000);   -- cycles par microseconde

    -- sequence d'initialisation (8 bits, 2 lignes, 5x8)
    constant NINIT : integer := 8;
    type t_cmd is array (0 to NINIT-1) of std_logic_vector(7 downto 0);
    type t_del is array (0 to NINIT-1) of integer;
    constant INIT_CMD    : t_cmd := (x"38", x"38", x"38", x"38",   -- function set
                                     x"08",                        -- display off
                                     x"01",                        -- clear
                                     x"06",                        -- entry mode : increment
                                     x"0C");                       -- display on, curseur off
    constant INIT_DEL_US : t_del := (5000, 200, 200, 100, 100, 2000, 100, 100);

    -- boucle : 0x80, 16 car., 0xC0, 16 car.  = 34 ecritures
    constant NBOUCLE : integer := 34;
    constant T_ALIM  : integer := 50000 * US;   -- 50 ms apres mise sous tension
    constant T_CAR   : integer := 100 * US;     -- 100 us apres chaque ecriture

    type t_chars is array (0 to 31) of std_logic_vector(7 downto 0);
    signal chars : t_chars;

    type t_phase is (ALIM, SETUP, IMPULSION, ATTENTE);
    signal phase : t_phase := ALIM;
    signal cpt   : integer range 0 to T_ALIM := 0;
    signal etape : integer range 0 to NINIT + NBOUCLE - 1 := 0;

    signal st_rs  : std_logic;
    signal st_db  : std_logic_vector(7 downto 0);
    signal st_del : integer range 0 to T_ALIM;

    signal rs_reg : std_logic := '0';
    signal db_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal e_reg  : std_logic := '0';

begin

    gen_chars : for i in 0 to 31 generate
        chars(i) <= texte(255 - 8*i downto 248 - 8*i);
    end generate;

    -- contenu (RS, DB, delai) de l'etape courante
    process(etape, chars)
        variable k : integer range 0 to NBOUCLE - 1;
    begin
        if etape < NINIT then
            st_rs  <= '0';
            st_db  <= INIT_CMD(etape);
            st_del <= INIT_DEL_US(etape) * US;
        else
            k      := etape - NINIT;
            st_del <= T_CAR;
            if k = 0 then
                st_rs <= '0';  st_db <= x"80";            -- adresse ligne 1
            elsif k <= 16 then
                st_rs <= '1';  st_db <= chars(k - 1);
            elsif k = 17 then
                st_rs <= '0';  st_db <= x"C0";            -- adresse ligne 2
            else
                st_rs <= '1';  st_db <= chars(k - 2);
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- RS et DB registres (sans glitch), E reste a 0 pendant les changements
            rs_reg <= st_rs;
            db_reg <= st_db;

            if reset = '1' then
                phase <= ALIM;
                cpt   <= 0;
                etape <= 0;
                e_reg <= '0';
            else
                case phase is
                    when ALIM =>
                        if cpt = T_ALIM - 1 then
                            cpt <= 0;  phase <= SETUP;
                        else
                            cpt <= cpt + 1;
                        end if;

                    when SETUP =>                 -- donnees stables avant E
                        if cpt = 2*US - 1 then
                            cpt <= 0;  e_reg <= '1';  phase <= IMPULSION;
                        else
                            cpt <= cpt + 1;
                        end if;

                    when IMPULSION =>             -- E a '1' pendant >= 1 us
                        if cpt = 2*US - 1 then
                            cpt <= 0;  e_reg <= '0';  phase <= ATTENTE;
                        else
                            cpt <= cpt + 1;
                        end if;

                    when ATTENTE =>               -- temps d'execution du LCD
                        if cpt >= st_del - 1 then
                            cpt <= 0;
                            phase <= SETUP;
                            if etape = NINIT + NBOUCLE - 1 then
                                etape <= NINIT;
                            else
                                etape <= etape + 1;
                            end if;
                        else
                            cpt <= cpt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    lcd_rs <= rs_reg;
    lcd_db <= db_reg;
    lcd_e  <= e_reg;
    lcd_rw <= '0';

end rtl;
