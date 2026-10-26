"""Génère les sons d'armes (rechargement), d'eau et d'ambiance du jeu (synthèse, 44,1 kHz mono).
Usage : python3 generer_sons.py <dossier_sortie>"""
import os
import sys
import wave
import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "sons"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def bruit(n):
    return rng.standard_normal(n)


def passe_bas(x, f):
    a = np.exp(-2 * np.pi * f / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def passe_haut(x, f):
    return x - passe_bas(x, f)


def env(n, att, dec):
    tt = np.arange(n) / SR
    return np.minimum(1.0, tt / max(att, 1e-4)) * np.exp(-tt / dec)


def clic(freqs=(2400, 3700, 5200), dec=0.012, dur=0.06, gain=1.0):
    """Clic métallique : bruit très court + résonances."""
    n = int(SR * dur)
    tt = np.arange(n) / SR
    x = bruit(n) * env(n, 0.0004, dec * 0.4) * 0.6
    for f in freqs:
        x += np.sin(2 * np.pi * f * tt * (1 + rng.uniform(-0.02, 0.02))) * env(n, 0.0003, dec) * 0.5
    return x * gain


def placer(total, *morceaux):
    y = np.zeros(int(SR * total))
    for (d, x) in morceaux:
        i = int(SR * d)
        j = min(len(y), i + len(x))
        y[i:j] += x[: j - i]
    return y


def glisse(dur, f0=900, f1=1600, gain=0.25):
    """Frottement métal contre métal."""
    n = int(SR * dur)
    x = passe_haut(bruit(n), 800) * np.hanning(n) * gain
    tt = np.arange(n) / SR
    x += np.sin(2 * np.pi * np.linspace(f0, f1, n) * tt) * np.hanning(n) * gain * 0.2
    return x


def sauver(nom, x, gain=0.9):
    x = x / max(1e-6, np.max(np.abs(x))) * gain
    with wave.open(os.path.join(OUT, nom + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def boucle(x, fondu=0.5):
    """Raccorde la fin et le début pour une boucle sans saut."""
    n = int(SR * fondu)
    debut = x[:n].copy()
    x = x[n:]
    x[-n:] = x[-n:] * np.linspace(1, 0, n) + debut * np.linspace(0, 1, n)
    return x


# ---------------------------------------------------------------- armes
sauver("chargeur_sort", placer(0.35, (0.0, clic((1800, 2900, 4100), 0.015)), (0.04, glisse(0.22, 700, 1100, 0.3))), 0.8)
sauver("chargeur_in", placer(0.3, (0.0, glisse(0.08, 900, 1300, 0.2)), (0.07, clic((1500, 2600, 3900, 5600), 0.03, 0.12, 1.4)), (0.1, clic((2100, 3300), 0.01, 0.05, 0.6))), 0.95)
sauver("culasse", placer(0.45, (0.0, clic((1300, 2500, 4300), 0.02, 0.08, 1.2)), (0.03, glisse(0.1, 1200, 800, 0.25)), (0.17, clic((1600, 2800, 4700, 6100), 0.03, 0.12, 1.5))), 0.95)
sauver("cartouche", placer(0.2, (0.0, glisse(0.05, 600, 900, 0.2)), (0.045, clic((1900, 3100), 0.012, 0.06, 0.9))), 0.7)
sauver("pompe", placer(0.55, (0.0, glisse(0.12, 500, 900, 0.35)), (0.11, clic((900, 1800, 3200), 0.03, 0.1, 1.3)), (0.24, glisse(0.1, 900, 500, 0.35)), (0.33, clic((1100, 2200, 3600), 0.04, 0.12, 1.5))), 0.95)
sol = placer(0.6, (0.0, clic((1200, 2300, 3800), 0.03, 0.1, 1.0)), (0.12, clic((1400, 2600), 0.02, 0.08, 0.5)), (0.22, clic((1300, 2500), 0.015, 0.06, 0.25)))
sauver("chargeur_sol", sol, 0.7)

# ---------------------------------------------------------------- eau (pas dans l'eau)
n = int(SR * 0.45)
x = passe_bas(bruit(n), 2500) * env(n, 0.03, 0.12)
tt = np.arange(n) / SR
for k in range(6):
    f = rng.uniform(500, 1400)
    d = rng.uniform(0.02, 0.2)
    x += np.sin(2 * np.pi * f * (1 + 2.5 * tt) * tt) * np.exp(-np.maximum(0, tt - d) / 0.025) * (tt > d) * 0.25
sauver("eau", x, 0.7)

# ---------------------------------------------------------------- ambiances (boucles)
# campagne : vent léger (les « oiseaux » synthétiques ressemblaient à des bips répétés : retirés)
dur = 24.0
n = int(SR * dur)
fond = passe_bas(bruit(n), 300) * 0.25
for k in range(0):
    d0 = rng.uniform(0.5, dur - 2)
    f0 = rng.uniform(2600, 4800)
    nb = rng.integers(2, 6)
    for j in range(nb):
        d = d0 + j * rng.uniform(0.09, 0.16)
        m = int(SR * rng.uniform(0.05, 0.11))
        tt = np.arange(m) / SR
        mod = 1 + 0.25 * np.sin(2 * np.pi * rng.uniform(20, 45) * tt)
        ch = np.sin(2 * np.pi * f0 * mod * (1 + rng.uniform(-0.3, 0.3) * tt / tt[-1]) * tt) * np.hanning(m) * rng.uniform(0.2, 0.45)
        i = int(SR * d)
        fond[i:i + m] += ch[: len(fond) - i]
sauver("amb_campagne", boucle(fond), 0.5)

# nuit : souffle grave seul (les grillons, tons purs à 4,4 kHz, faisaient des bips ;
# sons/amb_nuit.wav est désormais fait sans numpy, même principe)
n = int(SR * dur)
tt = np.arange(n) / SR
x = passe_bas(bruit(n), 200) * 0.2
for k in range(0):
    f = rng.uniform(4200, 5200)
    rythme = rng.uniform(2.5, 4.0)
    porte = (np.sin(2 * np.pi * rythme * tt + rng.uniform(0, 6)) > 0.3).astype(float)
    porte = passe_bas(porte, 60)
    x += np.sin(2 * np.pi * f * tt) * (0.5 + 0.5 * np.sin(2 * np.pi * 45 * tt)) * porte * rng.uniform(0.08, 0.15)
sauver("amb_nuit", boucle(x), 0.45)

# ville : vent dans les rues, tôle qui grince, chien au loin
n = int(SR * dur)
tt = np.arange(n) / SR
x = passe_bas(bruit(n), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * tt)) * 0.5
for k in range(5):
    d = rng.uniform(1, dur - 3)
    m = int(SR * rng.uniform(0.6, 1.4))
    t2 = np.arange(m) / SR
    gr = np.sin(2 * np.pi * (rng.uniform(300, 600) + 80 * np.sin(2 * np.pi * 3 * t2)) * t2) * np.hanning(m) * 0.12
    i = int(SR * d)
    x[i:i + m] += gr[: n - i]
for k in range(3):
    d = rng.uniform(1, dur - 2)
    for j in range(rng.integers(2, 4)):
        m = int(SR * 0.18)
        t2 = np.arange(m) / SR
        ab = passe_bas(np.sin(2 * np.pi * 420 * t2) * np.sign(np.sin(2 * np.pi * 140 * t2)) * env(m, 0.01, 0.06), 1200) * 0.1
        i = int(SR * (d + j * 0.35))
        x[i:i + m] += ab[: n - i]
sauver("amb_ville", boucle(x), 0.5)

# grotte : grondement sourd et gouttes avec écho
dur = 20.0
n = int(SR * dur)
tt = np.arange(n) / SR
x = passe_bas(bruit(n), 90) * 0.8
for k in range(30):
    d = rng.uniform(0.2, dur - 1)
    m = int(SR * 0.08)
    t2 = np.arange(m) / SR
    g = np.sin(2 * np.pi * rng.uniform(900, 1700) * (1 + 3 * t2) * t2) * np.exp(-t2 / 0.015) * rng.uniform(0.3, 0.6)
    for e, a in [(0.0, 1.0), (0.09, 0.35), (0.21, 0.15), (0.38, 0.06)]:
        i = int(SR * (d + e))
        if i + m < n:
            x[i:i + m] += g * a
sauver("amb_grotte", boucle(x), 0.55)

# musique du boss : tambours graves et nappe dissonante (boucle de 16 s, 90 bpm)
dur = 16.0
n = int(SR * dur)
tt = np.arange(n) / SR
x = np.zeros(n)
temps = 60 / 90
for b in range(int(dur / temps)):
    for frac, g in [(0.0, 1.0), (0.5, 0.45)] if b % 2 == 0 else [(0.0, 0.8), (0.75, 0.6)]:
        i = int(SR * (b + frac) * temps)
        m = int(SR * 0.5)
        t2 = np.arange(m) / SR
        tam = np.sin(2 * np.pi * (55 + 60 * np.exp(-t2 / 0.03)) * t2) * np.exp(-t2 / 0.18) * g
        tam += passe_bas(bruit(m), 400) * np.exp(-t2 / 0.04) * 0.3 * g
        x[i:i + m] += tam[: n - i]
for f, a in [(55, 0.25), (58.3, 0.18), (110, 0.12), (164.8, 0.08), (174.6, 0.06)]:
    x += np.sin(2 * np.pi * f * tt + 0.3 * np.sin(2 * np.pi * 0.2 * tt)) * a * (0.7 + 0.3 * np.sin(2 * np.pi * tt / dur))
cord = np.sin(2 * np.pi * 440 * tt + 3 * np.sin(2 * np.pi * 5 * tt)) * 0.03 * (np.sin(np.pi * tt / dur) ** 2)
x += cord
sauver("musique_boss", boucle(x, 0.3), 0.7)

# ---------------------------------------------------------------- pas selon le sol (3 variantes chacun)
def pas(sol, k):
    r = np.random.default_rng(100 + k * 7 + ["herbe", "terre", "beton", "bois", "metal"].index(sol) * 11)
    n = int(SR * 0.22)
    t2 = np.arange(n) / SR
    if sol == "herbe":
        x = passe_haut(r.standard_normal(n), 1500) * env(n, 0.008, 0.05) * 0.6
        x += passe_bas(r.standard_normal(n), 500) * env(n, 0.003, 0.03) * 0.5
    elif sol == "terre":
        x = passe_bas(r.standard_normal(n), 900) * env(n, 0.004, 0.04)
        for j in range(8):
            d = r.uniform(0.005, 0.06)
            x += (t2 > d) * np.exp(-np.maximum(0, t2 - d) / 0.002) * r.uniform(-0.4, 0.4)
    elif sol == "beton":
        x = passe_bas(r.standard_normal(n), 2600) * env(n, 0.001, 0.018)
        x += np.sin(2 * np.pi * r.uniform(140, 190) * t2) * env(n, 0.001, 0.025) * 0.6
        x += passe_haut(r.standard_normal(n), 3000) * env(n, 0.001, 0.01) * 0.3
    elif sol == "bois":
        x = np.zeros(n)
        for f0, a in [(r.uniform(180, 230), 1.0), (r.uniform(420, 520), 0.5), (r.uniform(900, 1100), 0.2)]:
            x += np.sin(2 * np.pi * f0 * t2) * env(n, 0.001, 0.045) * a
        x += passe_bas(r.standard_normal(n), 2000) * env(n, 0.001, 0.012) * 0.5
    else:  # métal
        x = np.zeros(n)
        for f0 in [r.uniform(700, 900), r.uniform(1500, 1900), r.uniform(2900, 3400)]:
            x += np.sin(2 * np.pi * f0 * t2) * env(n, 0.001, 0.07) * 0.4
        x += passe_bas(r.standard_normal(n), 3000) * env(n, 0.001, 0.01)
    return x

for sol in ["herbe", "terre", "beton", "bois", "metal"]:
    for k in range(3):
        sauver("pas_%s%d" % (sol, k + 1), pas(sol, k), 0.8)
n = int(SR * 0.35)
sauver("atterrissage", passe_bas(bruit(n), 700) * env(n, 0.002, 0.08) + np.sin(2 * np.pi * 70 * t(0.35)) * env(n, 0.002, 0.06), 0.85)

# ---------------------------------------------------------------- respiration (boucle : inspiration + expiration)
dur = 2.4
n = int(SR * dur)
tt = np.arange(n) / SR
souffle = np.zeros(n)
for debut, longueur, f_c, a in [(0.05, 0.55, 1400, 0.7), (0.75, 0.75, 900, 1.0), (1.25, 0.5, 1300, 0.6), (1.8, 0.55, 850, 0.85)]:
    i0 = int(SR * debut)
    m = int(SR * longueur)
    seg = passe_bas(passe_haut(bruit(m), 300), f_c) * np.hanning(m) * a
    souffle[i0:i0 + m] += seg[: n - i0]
sauver("souffle", boucle(souffle, 0.1), 0.6)

# ---------------------------------------------------------------- douilles et impacts
for k in range(3):
    r = np.random.default_rng(300 + k)
    y = np.zeros(int(SR * 0.5))
    tps = 0.0
    for rebond in range(3):
        m = int(SR * 0.12)
        t2 = np.arange(m) / SR
        c = np.zeros(m)
        for f0 in [r.uniform(3500, 4500), r.uniform(6000, 7500), r.uniform(8800, 9800)]:
            c += np.sin(2 * np.pi * f0 * t2) * np.exp(-t2 / 0.03) * 0.3
        i = int(SR * tps)
        y[i:i + m] += c[: len(y) - i] * (0.6 ** rebond)
        tps += r.uniform(0.07, 0.14) * (0.7 ** rebond)
    sauver("douille%d" % (k + 1), y, 0.5)
n = int(SR * 0.25)
sauver("impact_mur", passe_bas(bruit(n), 3500) * env(n, 0.0005, 0.02) + passe_bas(bruit(n), 400) * env(n, 0.001, 0.06) * 0.6, 0.8)
sauver("impact_metal", placer(0.4, (0.0, clic((1800, 3100, 4700, 6900), 0.08, 0.4, 1.0))), 0.8)

# ---------------------------------------------------------------- mêlée
for nom, dur, f0, f1, g in [("vent_leger", 0.25, 2500, 800, 0.5), ("vent_lourd", 0.45, 1200, 300, 0.8)]:
    n = int(SR * dur)
    x = passe_bas(bruit(n), 4000) * np.hanning(n)
    # balayage : filtre qui descend
    out = np.zeros(n)
    for i, f in enumerate(np.linspace(f0, f1, 8)):
        a = slice(i * n // 8, (i + 1) * n // 8)
        out[a] = passe_haut(x[a], f * 0.3)
    sauver(nom, out * g, 0.7)
sauver("parade", placer(0.5, (0.0, clic((600, 1300, 2600, 4100), 0.06, 0.3, 1.0)), (0.0, passe_bas(bruit(int(SR * 0.2)), 900) * env(int(SR * 0.2), 0.001, 0.05))), 0.9)

# ---------------------------------------------------------------- explosifs
n = int(SR * 2.6)
x = t(2.6)
grave = passe_bas(bruit(n), 180) * np.exp(-x / 0.55) * 3.0
coup = passe_bas(bruit(n), 2500) * np.exp(-x / 0.06) * 1.2
gronde = np.sin(2 * np.pi * 42 * x) * np.exp(-x / 0.35) * 0.8
debris = np.zeros(n)
r = np.random.default_rng(77)
for k in range(30):
    i = int(SR * r.uniform(0.25, 1.9))
    m = int(SR * 0.04)
    debris[i:i + m] += passe_haut(bruit(m), 1500)[: n - i] * np.exp(-np.arange(m) / (SR * 0.01)) * r.uniform(0.05, 0.2)
sauver("explosion", grave + coup + gronde + debris, 0.98)
sauver("goupille", placer(0.5, (0.0, clic((2600, 4100, 6200), 0.015, 0.06, 1.0)), (0.12, glisse(0.12, 1800, 3200, 0.15)), (0.3, clic((3400, 5200), 0.01, 0.05, 0.7))), 0.8)

# ---------------------------------------------------------------- leurres (grenade.gd, joués en boucle par Game.sfx_boucle)
r = np.random.default_rng(91)
# réveil mécanique : le marteau bat deux cloches (~22 coups/s) pendant 0,9 s, puis 0,4 s de silence
y = np.zeros(int(SR * 1.3))
m = int(SR * 0.08)
tt = np.arange(m) / SR
for k in range(20):
    cloche = 0
    for f0, a in [(2350, 1.0), (5650, 0.45), (8100, 0.25)] if k % 2 == 0 else [(2620, 1.0), (6100, 0.4), (8800, 0.2)]:
        cloche = cloche + np.sin(2 * np.pi * f0 * r.uniform(0.995, 1.005) * tt) * a
    frappe = cloche * np.exp(-tt / 0.025) + passe_haut(bruit(m), 3000) * np.exp(-tt / 0.003) * 0.4
    i = int(SR * k * 0.045)
    y[i:i + m] += frappe[: len(y) - i]
sauver("reveil", y, 0.75)
# radio : grésillement + voix lointaine (formants qui changent) + bout de musique étouffée, 3 s bouclées
d = 3.5
n = int(SR * d)
x = t(d)
gresil = passe_haut(bruit(n), 1500) * (0.35 + 0.25 * np.sin(2 * np.pi * 0.7 * x))
crepite = np.zeros(n)
for k in range(60):
    i = int(r.uniform(0, n - 200))
    crepite[i:i + 200] += bruit(200) * np.exp(-np.arange(200) / 30.0) * r.uniform(0.3, 1.0)
voix = np.zeros(n)
for k in range(12):
    s0, l0 = r.uniform(0, d - 0.3), r.uniform(0.08, 0.25)
    i, l = int(SR * s0), int(SR * l0)
    f0 = r.uniform(110, 170)
    tt2 = np.arange(l) / SR
    v = sum(np.sin(2 * np.pi * f0 * h * tt2) / h for h in range(1, 12))
    voix[i:i + l] += passe_bas(passe_haut(v, 300), 2800) * np.hanning(l)
notes = np.zeros(n)
for k, f0 in enumerate([392, 440, 494, 440, 392, 330, 349, 392]):
    i, l = int(SR * k * 0.42), int(SR * 0.38)
    tt2 = np.arange(l) / SR
    notes[i:i + l] += (np.sign(np.sin(2 * np.pi * f0 * tt2)) * 0.3 + np.sin(2 * np.pi * f0 * 2 * tt2) * 0.2) * env(l, 0.01, 0.2)
notes = passe_bas(passe_haut(notes, 400), 2200)
sauver("radio", boucle(gresil * 0.5 + crepite * 0.5 + voix * 0.8 + notes * 0.35, 0.4), 0.7)
# pétards : salve irrégulière de détonations sèches sur ~2,6 s
y = np.zeros(int(SR * 3.0))
tps = 0.0
while tps < 2.6:
    m = int(SR * 0.25)
    tt = np.arange(m) / SR
    pet = passe_bas(bruit(m), r.uniform(2500, 5000)) * np.exp(-tt / r.uniform(0.008, 0.02)) * r.uniform(0.6, 1.0)
    pet += passe_bas(bruit(m), 300) * np.exp(-tt / 0.05) * 0.4
    i = int(SR * tps)
    y[i:i + m] += pet[: len(y) - i]
    tps += r.uniform(0.04, 0.3)
sauver("petards", y, 0.95)

print("sons générés dans", OUT)
