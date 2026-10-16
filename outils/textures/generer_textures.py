"""Génère les textures procédurales du décor (raccordables, PBR) : albedo + normal map.
Toutes les textures se répètent sans couture (bruit construit par synthèse spectrale périodique).
Usage : python3 generer_textures.py <dossier_sortie>
"""
import sys, os
import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(1234)
OUT = sys.argv[1] if len(sys.argv) > 1 else "textures"
os.makedirs(OUT, exist_ok=True)

fx = np.fft.fftfreq(N)[:, None]
fy = np.fft.fftfreq(N)[None, :]
FR = np.sqrt(fx * fx + fy * fy)
FR[0, 0] = 1.0


def bruit(beta=2.0, fmin=0.0, fmax=0.5, aniso=(1.0, 1.0)):
    """Bruit périodique de spectre 1/f^beta, normalisé dans [0,1]."""
    f = np.sqrt((fx * aniso[0]) ** 2 + (fy * aniso[1]) ** 2)
    f[0, 0] = 1.0
    amp = 1.0 / f ** (beta / 2.0)
    amp[(FR < fmin) | (FR > fmax)] = 0.0
    amp[0, 0] = 0.0
    ph = np.exp(2j * np.pi * rng.random((N, N)))
    r = np.real(np.fft.ifft2(amp * ph))
    r -= r.min()
    r /= r.max() + 1e-9
    return r


def flou(a, s):
    """Flou gaussien périodique (rayon s en pixels)."""
    g = np.exp(-2 * (np.pi * s) ** 2 * (fx ** 2 + fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def normale(h, force):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * force
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * force
    n = np.dstack([-dx, dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n


def sauver(nom, albedo, hauteur, force=3.0, rough=None):
    a = np.clip(albedo, 0, 1)
    Image.fromarray((a * 255).astype(np.uint8)).save(os.path.join(OUT, nom + "_albedo.jpg"), quality=90)
    n = normale(hauteur, force)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(OUT, nom + "_normal.png"))
    if rough is not None:
        Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, nom + "_rough.jpg"), quality=90)
    print(nom)


def couleur(g, c0, c1):
    c0 = np.array(c0)
    c1 = np.array(c1)
    return c0[None, None, :] * (1 - g[..., None]) + c1[None, None, :] * g[..., None]


def points(densite, rayon):
    """Taches circulaires périodiques (gravillons)."""
    m = np.zeros((N, N))
    k = int(densite * N * N)
    xs = rng.integers(0, N, k)
    ys = rng.integers(0, N, k)
    m[ys, xs] = rng.random(k) * 2 - 1
    return flou(m, rayon) * rayon * rayon * 6


# ------------------------------------------------------------------ asphalte (tuile 4 m)
def asphalte():
    base = bruit(2.2) * 0.5 + bruit(1.0, 0.05) * 0.5
    grav = points(0.08, 0.7)
    taches = bruit(3.0, 0, 0.02)
    fiss = np.abs(bruit(2.6, 0.003, 0.1) - 0.5)
    fiss = np.clip(1 - fiss / 0.012, 0, 1) * (bruit(2.0, 0, 0.05) > 0.55)
    g = 0.2 + base * 0.12 + grav * 0.25 - taches * 0.08 - fiss * 0.15
    alb = couleur(np.clip(g, 0, 1), (0.0, 0.0, 0.0), (1.0, 1.0, 1.02))
    h = grav * 0.6 + base * 0.3 - fiss * 1.5
    sauver("asphalte", alb, h, 6.0, 0.8 + base * 0.15 - taches * 0.2)


# ------------------------------------------------------------------ béton (tuile 3 m)
def beton():
    a = bruit(2.4) * 0.6 + bruit(1.2, 0.08) * 0.4
    pores = np.clip(points(0.01, 0.5), -1, 0) * -1
    g = 0.55 + (a - 0.5) * 0.18 - pores * 0.08
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (1.0, 0.99, 0.96))
    sauver("beton", alb, a * 0.4 - pores * 0.3, 2.0, 0.85 + a * 0.1)


# ------------------------------------------------------------------ trottoir : dalles 1 m (tuile 2 m)
def trottoir():
    a = bruit(2.3) * 0.6 + bruit(1.0, 0.08) * 0.4
    y, x = np.mgrid[0:N, 0:N]
    cell = N // 2
    joint = (np.minimum(x % cell, cell - x % cell) < 3) | (np.minimum(y % cell, cell - y % cell) < 3)
    var = np.zeros((N, N))
    for i in range(2):
        for j in range(2):
            var[i * cell:(i + 1) * cell, j * cell:(j + 1) * cell] = rng.random() * 0.08
    g = 0.58 + (a - 0.5) * 0.15 + var
    g = np.where(joint, 0.32, g)
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (1.0, 0.98, 0.95))
    h = a * 0.3 - joint.astype(float)
    sauver("trottoir", alb, flou(h, 0.8), 5.0)


# ------------------------------------------------------------------ brique (tuile 1 m : 4 briques x 14 rangs)
def brique():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    rangs = 14
    rh = N / rangs
    row = np.floor(y / rh)
    bw = N / 4
    xo = (x + (row % 2) * bw / 2) % N
    col = np.floor(xo / bw)
    mortier = 4.0
    lx = xo - col * bw
    ly = y - row * rh
    dist = np.minimum.reduce([lx, bw - lx, ly, rh - ly])
    joint = dist < mortier / 2 + 0.6
    idb = (row * 7 + col * 13) % 97
    teinte = np.zeros((N, N, 3))
    tab = rng.random((200, 3))
    tirage = tab[(row * 4 + col).astype(int) % 200]
    base = np.array([0.55, 0.26, 0.17])
    teinte = base[None, None, :] * (0.75 + 0.45 * tirage[..., 0:1]) + (tirage[..., 1:2] - 0.5) * np.array([0.05, 0.04, 0.03])
    grain = bruit(1.4, 0.05)
    teinte *= (0.85 + 0.3 * grain)[..., None]
    sale = bruit(2.5, 0, 0.03)
    teinte *= (1 - 0.25 * sale)[..., None]
    mort = couleur(0.5 + 0.3 * grain, (0.42, 0.40, 0.37), (0.72, 0.70, 0.66))
    alb = np.where(joint[..., None], mort, teinte)
    bord = np.clip(dist / 3.0, 0, 1)
    h = np.where(joint, -0.6, bord * 0.6 + grain * 0.3)
    sauver("brique", alb, flou(h, 0.7), 6.0)


# ------------------------------------------------------------------ enduit / crépi (tuile 2 m), teinté par la couleur des sommets
def enduit():
    a = bruit(1.3, 0.1)
    b = bruit(2.4)
    coul = bruit(2.0, 0, 0.5, aniso=(4.0, 0.25))   # coulures verticales
    g = 0.86 + (b - 0.5) * 0.12 - np.clip(coul - 0.6, 0, 1) * 0.35 - (a - 0.5) * 0.05
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (1.0, 1.0, 1.0))
    sauver("enduit", alb, a * 0.5 + b * 0.5, 1.2, 0.9 + a * 0.08)


# ------------------------------------------------------------------ parquet (tuile 2 m)
def parquet():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    nb = 16
    lw = N / nb
    lame = np.floor(x / lw)
    decal = (lame * 0.37 % 1.0) * N
    yy = (y + decal) % N
    longueur = N / 2
    piece = np.floor(yy / longueur)
    idp = (lame * 3 + piece).astype(int)
    tab = rng.random(400)
    var = tab[idp % 400]
    fibre = bruit(1.8, 0.02, 0.5, aniso=(0.08, 3.0))
    noeuds = bruit(2.0, 0.01, 0.2)
    g = 0.5 + 0.25 * var + 0.25 * (fibre - 0.5) + 0.1 * (noeuds - 0.5)
    alb = couleur(np.clip(g, 0, 1), (0.22, 0.12, 0.06), (0.72, 0.50, 0.30))
    joint = (np.minimum(x % lw, lw - x % lw) < 1.2) | (np.minimum(yy % longueur, longueur - yy % longueur) < 1.2)
    alb = np.where(joint[..., None], alb * 0.45, alb)
    h = fibre * 0.3 - joint.astype(float) * 0.8
    sauver("parquet", alb, h, 3.0, 0.55 + 0.2 * fibre)


# ------------------------------------------------------------------ carrelage 30 cm (tuile 1,2 m)
def carrelage():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    c = N / 4
    joint = (np.minimum(x % c, c - x % c) < 2.2) | (np.minimum(y % c, c - y % c) < 2.2)
    a = bruit(2.0)
    tab = rng.random(16)
    var = tab[(np.floor(x / c) * 4 + np.floor(y / c)).astype(int) % 16]
    g = 0.82 + (a - 0.5) * 0.08 + var * 0.05
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (0.96, 0.95, 0.92))
    alb = np.where(joint[..., None], np.array([0.45, 0.43, 0.40]), alb)
    sauver("carrelage", alb, flou(-joint.astype(float) + a * 0.1, 0.6), 4.0, np.where(joint, 0.9, 0.25 + a * 0.1))


# ------------------------------------------------------------------ herbe (tuile 3 m)
def herbe():
    a = bruit(2.0, 0, 0.5)
    b = bruit(1.0, 0.1)
    brins = bruit(0.6, 0.15, 0.5, aniso=(0.3, 1.7))
    sec = bruit(3.0, 0, 0.03)
    touffes = bruit(1.6, 0.02, 0.2)
    g = 0.2 + 0.55 * brins ** 1.5 + 0.25 * b + 0.25 * (touffes - 0.5)
    vert = couleur(g, (0.06, 0.10, 0.03), (0.38, 0.52, 0.18))
    jaune = couleur(g, (0.16, 0.14, 0.06), (0.62, 0.56, 0.30))
    alb = vert * (1 - sec[..., None] * 0.6) + jaune * (sec[..., None] * 0.6)
    terre = np.clip((a - 0.78) * 6, 0, 1)
    alb = alb * (1 - terre[..., None]) + couleur(b, (0.15, 0.11, 0.07), (0.35, 0.27, 0.18)) * terre[..., None]
    sauver("herbe", alb, brins * 0.7 + a * 0.3, 4.0)


# ------------------------------------------------------------------ terre battue (tuile 3 m)
def terre():
    a = bruit(2.2)
    b = bruit(1.2, 0.05)
    cail = points(0.03, 1.2)
    g = 0.45 + (a - 0.5) * 0.3 + (b - 0.5) * 0.15
    alb = couleur(np.clip(g, 0, 1), (0.14, 0.10, 0.06), (0.55, 0.45, 0.32))
    alb += np.clip(cail, 0, 1)[..., None] * 0.15
    sauver("terre", alb, a * 0.5 + np.clip(cail, 0, 1) * 1.0, 5.0)


# ------------------------------------------------------------------ toit plat gravillonné (tuile 2 m)
def toit():
    grav = points(0.25, 0.9)
    a = bruit(2.0)
    g = 0.42 + grav * 0.3 + (a - 0.5) * 0.15
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (0.95, 0.93, 0.9))
    sauver("toit", alb, grav + a * 0.2, 6.0)


# ------------------------------------------------------------------ planches de bois peintes (tuile 2 m)
def planches():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    lw = N / 10
    lame = np.floor(x / lw)
    fibre = bruit(1.6, 0.02, 0.5, aniso=(0.06, 3.0))
    peinture = bruit(2.2) > 0.62
    tab = rng.random(10)
    g = 0.8 + 0.12 * tab[lame.astype(int) % 10] + (fibre - 0.5) * 0.25
    bois = couleur(fibre, (0.25, 0.17, 0.10), (0.48, 0.36, 0.24))
    alb = np.where(peinture[..., None], bois, couleur(np.clip(g, 0, 1), (0, 0, 0), (1, 1, 1)))
    joint = np.minimum(x % lw, lw - x % lw) < 2
    alb = np.where(joint[..., None], alb * 0.35, alb)
    sauver("planches", alb, fibre * 0.4 - joint.astype(float), 4.0)


# ------------------------------------------------------------------ tôle ondulée (tuile 1 m)
def tole():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    onde = np.sin(x / N * 2 * np.pi * 8)
    rouille = np.clip((bruit(2.4) - 0.55) * 4, 0, 1)
    a = bruit(1.5, 0.05)
    g = 0.7 + onde * 0.08 + (a - 0.5) * 0.1
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (1, 1, 1))
    alb = alb * (1 - rouille[..., None]) + couleur(a, (0.25, 0.12, 0.05), (0.55, 0.30, 0.12)) * rouille[..., None]
    sauver("tole", alb, onde * 0.35 + a * 0.05, 3.0, 0.5 + rouille * 0.4)


# ------------------------------------------------------------------ parpaings / bloc béton (tuile 2 m : 5 x 10)
def parpaing():
    y, x = np.mgrid[0:N, 0:N].astype(float)
    rh = N / 10
    row = np.floor(y / rh)
    bw = N / 5
    xo = (x + (row % 2) * bw / 2) % N
    lx = xo % bw
    ly = y % rh
    dist = np.minimum.reduce([lx, bw - lx, ly, rh - ly])
    joint = dist < 2.5
    a = bruit(2.3)
    pores = np.clip(points(0.02, 0.5), -1, 0) * -1 * 0.4
    tab = rng.random(60)
    var = tab[(row * 5 + np.floor(xo / bw)).astype(int) % 60]
    g = 0.6 + (a - 0.5) * 0.15 - pores * 0.2 + var * 0.06
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (0.98, 0.97, 0.94))
    alb = np.where(joint[..., None], alb * 0.7, alb)
    sauver("parpaing", alb, flou(np.where(joint, -0.8, 0.2) + a * 0.3 - pores, 0.7), 5.0)


# ------------------------------------------------------------------ vitre (reflets, saleté) (tuile 1 m)
def vitre():
    a = bruit(2.0)
    s = bruit(2.6, 0, 0.5, aniso=(3.0, 0.3))
    g = 0.15 + a * 0.1 + np.clip(s - 0.6, 0, 1) * 0.6
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (0.85, 0.92, 1.0))
    sauver("vitre", alb, a * 0.05, 1.0, 0.05 + np.clip(s - 0.5, 0, 1) * 0.8)


# ------------------------------------------------------------------ métal peint usé (tuile 1 m), teinté par le matériau
def metal_peint():
    a = bruit(2.0)
    rayures = np.clip(1 - np.abs(bruit(1.2, 0.02, 0.5, aniso=(0.15, 3.0)) - 0.5) / 0.01, 0, 1) * (bruit(2.0, 0, 0.05) > 0.5)
    rouille = np.clip((bruit(2.3) - 0.62) * 5, 0, 1)
    eclat = np.clip((bruit(2.6, 0, 0.5) - 0.7) * 6, 0, 1)
    g = 0.85 + (a - 0.5) * 0.1
    alb = couleur(np.clip(g, 0, 1), (0, 0, 0), (1, 1, 1))
    metal_nu = couleur(a, (0.35, 0.35, 0.36), (0.6, 0.6, 0.62))
    alb = alb * (1 - eclat[..., None]) + metal_nu * eclat[..., None]
    alb = alb * (1 - rayures[..., None] * 0.5) + rayures[..., None] * 0.35
    alb = alb * (1 - rouille[..., None]) + couleur(a, (0.22, 0.10, 0.04), (0.5, 0.26, 0.10)) * rouille[..., None]
    sauver("metal_peint", alb, a * 0.1 + rouille * 0.5 - eclat * 0.2, 2.0, 0.45 + rouille * 0.45 + a * 0.1)


# ------------------------------------------------------------------ écorce (tuile 1 m de haut, 1 tour de tronc)
def ecorce():
    sillons = bruit(1.8, 0.01, 0.5, aniso=(3.0, 0.12))
    a = bruit(2.0)
    lichen = np.clip((bruit(2.4) - 0.65) * 5, 0, 1)
    g = 0.25 + sillons * 0.5 + (a - 0.5) * 0.15
    alb = couleur(np.clip(g, 0, 1), (0.10, 0.08, 0.06), (0.52, 0.46, 0.40))
    alb = alb * (1 - lichen[..., None] * 0.6) + np.array([0.42, 0.48, 0.30]) * lichen[..., None] * 0.6
    sauver("ecorce", alb, sillons * 1.5 + a * 0.2, 6.0)


def _feuille(img, cx, cy, ang, lg, la, col):
    """Dessine une feuille (ellipse pointue) dans une image RGBA."""
    h, w = img.shape[:2]
    r = int(lg) + 2
    x0, x1 = int(max(cx - r, 0)), int(min(cx + r, w))
    y0, y1 = int(max(cy - r, 0)), int(min(cy + r, h))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(float)
    dx = xx - cx
    dy = yy - cy
    u = dx * np.cos(ang) + dy * np.sin(ang)
    v = -dx * np.sin(ang) + dy * np.cos(ang)
    t = np.clip(u / lg, -1, 1)
    larg = la * (1 - t * t) ** 0.8
    m = (np.abs(u) < lg) & (np.abs(v) < larg)
    nerv = np.abs(v) < 0.6
    c = np.array(col) * (0.85 + 0.3 * (v / (la + 1e-3)) * 0.5)[..., None] if False else np.array(col)
    reg = img[y0:y1, x0:x1]
    shade = (0.8 + 0.4 * np.clip(0.5 + u / lg * 0.5, 0, 1))[..., None]
    couleur_px = np.clip(c[None, None, :] * shade, 0, 1)
    couleur_px = np.where(nerv[..., None], couleur_px * 1.15, couleur_px)
    reg[m, :3] = couleur_px[m]
    reg[m, 3] = 1.0


def feuillage():
    img = np.zeros((N, N, 4))
    cx, cy = N / 2, N / 2
    # rameaux
    for k in range(7):
        ang = rng.random() * 2 * np.pi
        L = N * 0.42 * (0.7 + rng.random() * 0.3)
        for t in np.linspace(0, 1, 60):
            x = cx + np.cos(ang) * L * t
            y = cy + np.sin(ang) * L * t
            img[int(y) % N, int(x) % N] = [0.25, 0.18, 0.1, 1]
    for i in range(700):
        d = np.sqrt(rng.random()) * N * 0.45
        a = rng.random() * 2 * np.pi
        x = cx + np.cos(a) * d
        y = cy + np.sin(a) * d
        teinte = np.array([0.20, 0.36, 0.10]) * (0.6 + rng.random() * 0.7) + np.array([0.06, 0.03, 0.0]) * rng.random()
        _feuille(img, x, y, rng.random() * np.pi * 2, 13 + rng.random() * 9, 5 + rng.random() * 3, teinte)
    # ombre interne : plus sombre au centre
    yy, xx = np.mgrid[0:N, 0:N]
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (N * 0.5)
    img[..., :3] *= (0.65 + 0.35 * np.clip(dist, 0, 1))[..., None]
    rgba = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "feuillage_albedo.png"))
    print("feuillage")


def aiguilles():
    img = np.zeros((N, N, 4))
    # branche de conifère : axe central + aiguilles obliques
    for b in range(3):
        x0 = N * (0.2 + 0.3 * b)
        for t in np.linspace(0, 1, 200):
            y = N * 0.05 + t * N * 0.9
            x = x0 + np.sin(t * 3 + b) * 6
            img[int(y), int(x) - 1:int(x) + 2] = [0.22, 0.15, 0.08, 1]
            for s in (-1, 1):
                if rng.random() < 0.9:
                    L = 28 + rng.random() * 16 * (1 - abs(t - 0.5))
                    ang = s * (0.9 + rng.random() * 0.3)
                    for q in np.linspace(0, 1, int(L)):
                        xx = int(x + s * np.sin(abs(ang)) * L * q)
                        yy = int(y + np.cos(ang) * L * q * 0.6)
                        if 0 <= xx < N and 0 <= yy < N:
                            c = np.array([0.10, 0.22, 0.10]) * (0.7 + 0.5 * rng.random())
                            img[yy, xx] = [c[0], c[1], c[2], 1]
                            if xx + 1 < N:
                                img[yy, xx + 1] = [c[0] * 0.8, c[1] * 0.8, c[2] * 0.8, 1]
                            if yy + 1 < N:
                                img[yy + 1, xx] = [c[0], c[1], c[2], 1]
    rgba = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, "aiguilles_albedo.png"))
    print("aiguilles")


for f in [ecorce, feuillage, aiguilles, metal_peint, asphalte, beton, trottoir, brique, enduit, parquet, carrelage, herbe, terre, toit, planches, tole, parpaing, vitre]:
    f()
