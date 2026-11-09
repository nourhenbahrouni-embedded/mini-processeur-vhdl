#!/usr/bin/env bash
# ---------------------------------------------------------------------
#  Lance toutes les simulations avec GHDL (VHDL-93).
#  Usage : ./scripts/run_sim.sh            (depuis la racine du depot)
#          ./scripts/run_sim.sh --wave     (genere aussi le chronogramme)
#  Code de retour non nul si une assertion "ECHEC" se declenche.
# ---------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD=build
mkdir -p "$BUILD"
OPTS="--std=93c --workdir=$BUILD"

echo "== Analyse des sources"
for f in src/cpu_mini_processeur.vhd src/utilitaires.vhd src/affichage_7seg.vhd \
         src/lcd_hd44780.vhd src/top_7seg.vhd src/top_lcd.vhd \
         sim/tb_gup.vhd sim/tb_top_7seg.vhd sim/tb_top_lcd.vhd; do
    ghdl -a $OPTS "$f"
done

for tb in tb_gup tb_top_7seg tb_top_lcd; do
    echo "== Simulation $tb"
    ghdl -e $OPTS "$tb"
    EXTRA=""
    if [[ "${1:-}" == "--wave" && "$tb" == "tb_gup" ]]; then
        EXTRA="--vcd=$BUILD/$tb.vcd"
    fi
    if ! ghdl -r $OPTS "$tb" --assert-level=error --ieee-asserts=disable $EXTRA \
            > "$BUILD/$tb.log" 2>&1; then
        sed 's/.*(report note)://' "$BUILD/$tb.log"
        echo "!! ECHEC de $tb"
        exit 1
    fi
    sed 's/.*(report note)://' "$BUILD/$tb.log" | grep -E "FIN|sel=|LCD final|pas a pas : apres" || true
done

if [[ "${1:-}" == "--wave" ]]; then
    python3 scripts/plot_wave.py "$BUILD/tb_gup.vcd" docs/images/chronogramme.png
fi

echo "== Toutes les simulations sont passees"
