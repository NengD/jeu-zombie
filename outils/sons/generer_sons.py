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
# campagne : vent léger + oiseaux
dur = 24.0
n = int(SR * dur)
fond = passe_bas(bruit(n), 300) * 0.25
for k in range(26):
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

# nuit : grillons
n = int(SR * dur)
tt = np.arange(n) / SR
x = passe_bas(bruit(n), 200) * 0.2
for k in range(4):
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
print("sons générés dans", OUT)
