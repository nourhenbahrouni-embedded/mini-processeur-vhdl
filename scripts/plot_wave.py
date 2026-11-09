import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from matplotlib import font_manager as fm

vcd_path, out_png = sys.argv[1], sys.argv[2]
COMPACT = len(sys.argv) > 3 and sys.argv[3] == "--compact"
K = 1.22 if COMPACT else 1.0

# ---------- tiny VCD parser ----------
ids, vals, t = {}, {}, 0
for line in open(vcd_path):
    p = line.split()
    if not p:
        continue
    if p[0] == "$var":
        ids[p[3]] = p[4].split("[")[0]
    elif p[0].startswith("#"):
        t = int(p[0][1:])
    elif p[0][0] in "01xzXZ" and len(p) == 1 and p[0][1:] in ids:
        vals.setdefault(ids[p[0][1:]], []).append((t, p[0][0]))
    elif p[0][0] == "b" and len(p) == 2 and p[1] in ids:
        vals.setdefault(ids[p[1]], []).append((t, p[0][1:]))

FS_PER_NS = 1_000_000  # GHDL VCD timescale = 1 fs
def at(sig, tt):
    v = None
    for (ti, vi) in vals[sig]:
        if ti <= tt:
            v = vi
        else:
            break
    return v

ETATS = {"000": "LDA", "001": "STO", "010": "ADD", "011": "SUB",
         "100": "JMP", "101": "FETCH1", "110": "FETCH2", "111": "STP"}

# reset release time
t_rel = [ti for ti, v in vals["reset"] if v == "0"][0]
t0 = t_rel - 10 * FS_PER_NS
t1 = t_rel + (15 if COMPACT else 19) * 20 * FS_PER_NS

def segments(sig, fmt):
    pts = [(ti, vi) for ti, vi in vals[sig]]
    segs, cur, cs = [], at(sig, t0), t0
    for ti, vi in pts:
        if t0 < ti < t1 and vi != cur:
            segs.append((cs, ti, cur)); cs, cur = ti, vi
    segs.append((cs, t1, cur))
    return [(a, b, fmt(v)) for a, b, v in segs]

def hexf(n):
    return lambda v: ("%0*X" % (n, int(v, 2))) if v and set(v) <= set("01") else "?"

BG, PANEL, GRID = "#0B1220", "#0F1A2E", "#1E2A44"
TXT, MUTED = "#E6EDF7", "#8A9BB5"
C = {"clk": "#8A9BB5", "reset": "#F87171", "etat": "#A78BFA",
     "pc": "#2DD4BF", "ir": "#60A5FA", "a": "#FBBF24", "b": "#F472B6"}

for f in ["/usr/share/fonts/opentype/inter/Inter-Regular.otf",
          "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"]:
    fm.fontManager.addfont(f)
plt.rcParams["font.family"] = "Inter"

rows = [("clk", "clk", None), ("reset", "reset", None),
        ("etat", "état FSM", segments("etat1", lambda v: ETATS.get(v, "?"))),
        ("pc", "PC", segments("pc1", hexf(3))),
        ("ir", "IR", segments("ir1", hexf(4))),
        ("a", "A (ACC)", segments("acc1", hexf(4))),
        ("b", "B (MUXB)", segments("b1", hexf(4)))]

fig, ax = plt.subplots(figsize=(11, 6.0) if COMPACT else (16, 6.2), dpi=150)
fig.patch.set_facecolor(BG); ax.set_facecolor(BG)
H, GAP = 0.62, 1.0
def X(tt): return (tt - t0) / FS_PER_NS

n = len(rows)
for i, (key, label, segs) in enumerate(rows):
    y = (n - 1 - i) * GAP
    ax.text(-0.8 if COMPACT else -6, y + H / 2, label, ha="right", va="center", color=TXT, fontsize=12.5 * K,
            fontweight="semibold")
    col = C[key]
    if segs is None:
        sig = key
        xs, ys = [X(t0)], []
        lv = at(sig, t0); ys.append(lv)
        xs2, ys2 = [X(t0)], [y + (H if lv == "1" else 0)]
        for ti, vi in vals[sig]:
            if t0 < ti < t1:
                xs2 += [X(ti), X(ti)]
                ys2 += [ys2[-1], y + (H if vi == "1" else 0)]
        xs2.append(X(t1)); ys2.append(ys2[-1])
        ax.plot(xs2, ys2, color=col, lw=1.6 if key == "clk" else 2.2, solid_joinstyle="miter")
    else:
        for a, b, txt in segs:
            xa, xb = X(a), X(b)
            k = min(1.2, (xb - xa) / 4)
            poly = Polygon([(xa, y + H / 2), (xa + k, y + H), (xb - k, y + H), (xb, y + H / 2),
                            (xb - k, y), (xa + k, y)], closed=True,
                           facecolor=col + "22", edgecolor=col, lw=1.4)
            ax.add_patch(poly)
            if xb - xa > (12 if COMPACT else 9):
                ax.text((xa + xb) / 2, y + H / 2, txt, ha="center", va="center",
                        color=TXT if key != "etat" else "#EDE9FE",
                        fontsize=(9.0 if key == "etat" else 10.5 * K),
                        family="DejaVu Sans Mono" if key != "etat" else "Inter",
                        fontweight="semibold" if key == "etat" else "normal")

# cycle grid on rising edges
for ti, vi in vals["clk"]:
    if t_rel <= ti < t1 and vi == "1":
        ax.axvline(X(ti), color=GRID, lw=0.8, zorder=0)

ax.set_xlim(-1, X(t1) + 1)
ax.set_ylim(-0.5, n * GAP + 0.2)
ax.axis("off")
if not COMPACT: fig.suptitle("Chronogramme de simulation (GHDL) : programme de l'énoncé, X = 17, Y = 5",
             color=TXT, fontsize=15, fontweight="semibold", x=0.015, ha="left", y=0.97)
if not COMPACT: fig.text(0.015, 0.895, "1 instruction = 3 cycles (FETCH1, FETCH2, EXEC). Valeurs en hexadécimal. "
         "Résultat : A = 0027h = 39 = 2X + Y", color=MUTED, fontsize=11.5, ha="left")
plt.subplots_adjust(left=0.13 if COMPACT else 0.085, right=0.995, top=0.98 if COMPACT else 0.86, bottom=0.02)
fig.savefig(out_png, facecolor=BG)
print("ok", out_png)
