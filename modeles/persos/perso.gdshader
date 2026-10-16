shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Habillage procédural des personnages (mannequin Quaternius UAL, CC0).
// CUSTOM0.xyz = position du sommet au repos (squelette, face vers +Z), CUSTOM0.w = zone du corps :
// 0 tête/cou, 1 torse, 2 bras, 3 main, 4 bassin/jambes, 5 pieds.
// Les couleurs et le style sont des paramètres d'instance : chaque zombie peut être différent
// sans dupliquer le matériau.

instance uniform vec3 c_peau = vec3(0.80, 0.62, 0.50);
instance uniform vec3 c_haut = vec3(0.30, 0.34, 0.38);
instance uniform vec3 c_bas = vec3(0.16, 0.22, 0.34);
instance uniform vec3 c_chaussures = vec3(0.12, 0.11, 0.10);
instance uniform vec3 c_cheveux = vec3(0.16, 0.11, 0.07);
instance uniform float manches = 0.35;   // part du bras couverte par la manche (0..1)
instance uniform float jambes = 1.0;     // part de la jambe couverte par le pantalon (0..1)
instance uniform float style = 0.0;      // 0 t-shirt, 1 police, 2 militaire, 3 patient, 4 veste
instance uniform float zombie = 0.0;
instance uniform float sang = 0.0;
instance uniform float sale = 0.0;
instance uniform float graine = 0.0;
instance uniform float cheveux = 1.0;    // 0 rasé, 1 court, 2 long
instance uniform float femme = 0.0;

varying vec3 rp;
varying float zone;

void vertex() {
	rp = CUSTOM0.xyz;
	zone = CUSTOM0.w;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

vec3 camo(vec3 p) {
	float a = fbm(p * 7.0 + graine);
	float b = fbm(p * 9.0 + 17.0 + graine);
	vec3 c = vec3(0.33, 0.35, 0.24);                         // olive
	c = mix(c, vec3(0.20, 0.24, 0.15), step(0.52, a));       // vert foncé
	c = mix(c, vec3(0.42, 0.36, 0.26), step(0.58, b));       // brun clair
	c = mix(c, vec3(0.10, 0.10, 0.08), step(0.62, a * 0.6 + b * 0.5)); // noir
	return c;
}

void fragment() {
	int z = int(zone + 0.5);
	vec3 p = rp;
	float fine = noise(p * 220.0 + graine);
	float grain = fbm(p * 45.0 + graine);
	float large = fbm(p * 5.0 + graine * 3.7);
	float arm_f = clamp((abs(p.x) - 0.19) / 0.55, 0.0, 1.0);   // épaule -> poignet
	float leg_f = clamp((0.95 - p.y) / 0.85, 0.0, 1.0);        // hanche -> cheville

	// ---------------------------------------------------------------- peau
	vec3 peau = c_peau * (0.92 + 0.12 * grain);
	if (zombie > 0.5) {
		vec3 pale = mix(c_peau, vec3(0.55, 0.60, 0.50), 0.75) * (0.85 + 0.2 * grain);
		float veine = 1.0 - smoothstep(0.0, 0.035, abs(fbm(p * 18.0 + graine) - 0.5));
		pale = mix(pale, vec3(0.30, 0.22, 0.32), veine * 0.45);
		peau = mix(pale, vec3(0.35, 0.30, 0.22), smoothstep(0.55, 0.8, large) * 0.5);
	}
	float rough = 0.62;
	vec3 col = peau;
	bool est_peau = true;
	bool habit = false;

	// ---------------------------------------------------------------- vêtements par zone
	bool porte_haut = false;
	bool porte_bas = false;
	if (z == 1) {
		if (p.y < 1.0) { porte_bas = true; } else { porte_haut = true; }
	} else if (z == 2) {
		porte_haut = arm_f < manches + (grain - 0.5) * 0.02;
	} else if (z == 4) {
		if (p.y > 1.0) {
			porte_haut = true;
		} else if (style > 2.5 && style < 3.5) {
			porte_haut = leg_f < 0.42;                           // blouse d'hôpital
		} else {
			porte_bas = leg_f < jambes + (grain - 0.5) * 0.02;
		}
	} else if (z == 0) {
		// col montant (police, militaire, veste)
		if (p.y < 1.555 && style > 0.5 && style < 2.5) { porte_haut = true; }
		if (p.y < 1.54 && style > 3.5) { porte_haut = true; }
	}

	if (porte_haut) {
		est_peau = false;
		habit = true;
		rough = 0.92;
		vec3 c = c_haut;
		if (style > 1.5 && style < 2.5) {
			c = camo(p);
		}
		c *= 0.9 + 0.12 * grain + 0.05 * fine;
		// plis
		c *= 0.92 + 0.1 * fbm(p * vec3(12.0, 40.0, 12.0) + graine);
		bool devant = p.z > 0.06;
		if (style > 0.5 && style < 1.5) {
			// police : boutons, insigne, poches de poitrine, épaulettes
			if (z == 1 && devant && abs(p.x) < 0.006 && p.y > 1.0) { c = vec3(0.75, 0.68, 0.40); rough = 0.4; }
			if (z == 1 && devant && length(vec2(p.x - 0.085, p.y - 1.40)) < 0.022) { c = vec3(0.85, 0.72, 0.30); rough = 0.3; }
			if (z == 1 && devant && abs(abs(p.x) - 0.085) < 0.04 && abs(p.y - 1.32) < 0.035) { c *= 0.82; }
			if (z == 2 && arm_f < 0.18 && arm_f > 0.08 && p.z > 0.0) { c = mix(c, vec3(0.75, 0.70, 0.55), 0.6); }
		} else if (style > 1.5 && style < 2.5) {
			// militaire : gilet porte-plaques
			if (z == 1 && p.y > 1.07 && p.y < 1.47) {
				c = vec3(0.24, 0.24, 0.18) * (0.85 + 0.2 * grain);
				if (fract(p.y * 45.0) < 0.22) { c *= 0.75; }        // sangles MOLLE
				if (devant && p.y < 1.22 && abs(abs(p.x) - 0.08) < 0.05) { c = vec3(0.28, 0.27, 0.20) * (0.8 + 0.25 * grain); } // poches
				rough = 0.95;
			}
		} else if (style > 2.5 && style < 3.5) {
			// blouse : petits motifs
			c = mix(c, c * 0.8, step(0.92, noise(p * 120.0)));
		} else if (style > 3.5) {
			// veste : fermeture éclair, poches
			if (z == 1 && devant && abs(p.x) < 0.005) { c = vec3(0.6); rough = 0.35; }
			if (z == 1 && devant && abs(abs(p.x) - 0.09) < 0.045 && abs(p.y - 1.12) < 0.04) { c *= 0.8; }
			if (z == 2 && arm_f > manches - 0.04 && arm_f < manches) { c *= 0.75; } // poignets
		} else {
			// t-shirt : col et ourlets
			if (z == 0 || (z == 1 && p.y > 1.50)) { c *= 0.85; }
			if (z == 2 && arm_f > manches - 0.03) { c *= 0.85; }
		}
		col = c;
	}
	if (porte_bas) {
		est_peau = false;
		habit = true;
		rough = 0.9;
		vec3 c = c_bas;
		if (style > 1.5 && style < 2.5) {
			c = camo(p + 5.0);
		}
		if (style < 0.5 || style > 3.5) {
			// jean : sergé, délavé sur le devant des cuisses et aux genoux
			float serge = 0.5 + 0.5 * sin((p.x * 0.6 + p.y) * 900.0);
			c *= 0.88 + 0.1 * serge + 0.08 * grain;
			float use = smoothstep(0.03, 0.12, p.z) * (smoothstep(0.1, 0.3, leg_f) * 0.6 + smoothstep(0.45, 0.55, leg_f) * smoothstep(0.65, 0.55, leg_f));
			c = mix(c, c * 1.5 + 0.05, use * 0.35 * grain * 2.0);
		} else {
			c *= 0.9 + 0.12 * grain;
			// poches cargo (militaire)
			if (style > 1.5 && abs(abs(p.x) - 0.1) < 0.06 && abs(leg_f - 0.42) < 0.06 && abs(p.z) < 0.08) { c *= 0.85; }
		}
		// ceinture
		if (p.y > 0.955 && p.y < 0.995) {
			c = vec3(0.08, 0.07, 0.06) * (0.9 + 0.2 * grain);
			rough = 0.45;
			if (p.z > 0.08 && abs(p.x) < 0.02) { c = vec3(0.6, 0.55, 0.45); rough = 0.25; }
		}
		col = c;
	}

	// ---------------------------------------------------------------- mains et pieds
	if (z == 5) {
		if (style > 2.5 && style < 3.5) {
			col = peau;                                          // pieds nus (patient)
		} else {
			est_peau = false;
			habit = true;
			vec3 c = c_chaussures * (0.85 + 0.25 * grain);
			rough = 0.55;
			if (p.y < 0.028) { c = (style > 0.5 && style < 2.5) ? vec3(0.05) : vec3(0.75, 0.73, 0.70) * (0.8 + 0.2 * grain); rough = 0.8; }
			if (p.z > 0.06 && p.y > 0.06 && abs(p.x - sign(p.x) * 0.09) < 0.012 && fract(p.z * 70.0) < 0.4) { c = vec3(0.7); } // lacets
			col = c;
		}
	}
	if (z == 3 && style > 1.5 && style < 2.5 && zombie < 0.5) {
		col = vec3(0.12, 0.12, 0.10) * (0.8 + 0.3 * grain);    // gants tactiques
		est_peau = false;
		rough = 0.8;
	}

	// ---------------------------------------------------------------- tête : visage et cheveux
	if (z == 0 && !porte_haut) {
		float avant = smoothstep(0.02, 0.09, p.z);
		// ligne des cheveux (bas sur la nuque, haut sur le front)
		float lg_arriere = cheveux > 1.5 ? 1.50 : 1.64;
		float ligne = mix(lg_arriere, 1.775, avant);
		ligne = mix(ligne, 1.70, smoothstep(0.06, 0.09, abs(p.x)) * (1.0 - avant) * step(cheveux, 1.5));
		ligne += (fbm(p * 60.0 + graine) - 0.5) * 0.012;
		if (cheveux > 1.5) {
			// cheveux longs : encadrent le visage
			ligne = min(ligne, mix(1.60, 1.775, smoothstep(0.0, 0.07, p.z - abs(p.x) * 0.4)));
		}
		if (p.y > ligne && cheveux > 0.5) {
			float meche = fbm(p * vec3(140.0, 25.0, 140.0) + graine);
			col = c_cheveux * (0.7 + 0.6 * meche);
			rough = 0.7;
			est_peau = false;
		} else if (p.y > ligne - 0.01 && cheveux < 0.5) {
			col = mix(peau, c_cheveux, 0.35 * step(0.4, fine)); // crâne rasé
		}
		// visage
		if (p.z > 0.05 && p.y > 1.58 && p.y < 1.78) {
			float ey = 1.68;
			float dx = abs(p.x) - 0.033;
			float d = length(vec2(dx, (p.y - ey) * 1.7));
			if (zombie > 0.5) {
				col = mix(col, vec3(0.18, 0.08, 0.10), (1.0 - smoothstep(0.012, 0.03, d)) * 0.7); // orbites creuses
			}
			if (d < 0.012) {
				col = zombie > 0.5 ? vec3(0.78, 0.76, 0.62) : vec3(0.92, 0.90, 0.86);
				rough = 0.2;
				est_peau = false;
				if (length(vec2(dx, p.y - ey)) < 0.0055) {
					col = zombie > 0.5 ? vec3(0.65, 0.62, 0.5) : vec3(0.22, 0.15, 0.08);
					if (length(vec2(dx, p.y - ey)) < 0.0025) { col = vec3(0.03); }
				}
			}
			// lèvres
			float my = 1.632;
			if (abs(p.x) < 0.022 - abs(p.y - my) * 1.5 && abs(p.y - my) < 0.007) {
				col = zombie > 0.5 ? vec3(0.25, 0.08, 0.08) : peau * vec3(0.9, 0.72, 0.7);
				if (abs(p.y - my) < 0.0012) { col *= 0.4; }
			}
			// joues rosées
			if (zombie < 0.5) {
				col = mix(col, col * vec3(1.05, 0.88, 0.85), (1.0 - smoothstep(0.0, 0.025, length(vec2(abs(p.x) - 0.045, p.y - 1.67)))) * 0.5 * float(est_peau));
			}
		}
	}

	// ---------------------------------------------------------------- zombie : blessures, sang, saleté
	if (zombie > 0.5) {
		float trou = smoothstep(0.71, 0.74, fbm(p * 8.0 + graine * 1.3));
		if (habit && trou > 0.5 && z != 5) {
			col = peau * 0.8;                                    // vêtement déchiré
			habit = false;
		}
		float plaie = smoothstep(0.75, 0.78, fbm(p * 11.0 + graine * 2.1));
		col = mix(col, vec3(0.30, 0.04, 0.03) * (0.6 + 0.6 * grain), plaie * 0.9);
		// sang : autour de la bouche, sur la poitrine, coulures vers le bas
		float bouche = 1.0 - smoothstep(0.0, 0.07, length(vec2(p.x * 1.3, (p.y - 1.60) * 0.6))) * step(0.04, p.z);
		float poitrine = (1.0 - smoothstep(0.0, 0.25, length(vec2(p.x, p.y - 1.30)))) * step(0.03, p.z);
		float coul = fbm(p * vec3(25.0, 3.0, 25.0) + graine);
		float s = sang * (0.04 + bouche * 1.1 + poitrine * 0.45) * coul + plaie * 0.4;
		float m = smoothstep(0.45, 0.55, s);
		col = mix(col, vec3(0.22, 0.02, 0.02) * (0.7 + 0.5 * fine), m);
		rough = mix(rough, 0.35, m);
	}
	float salete = sale * smoothstep(0.35, 0.75, large + leg_f * 0.35 * float(z >= 4));
	col = mix(col, col * vec3(0.55, 0.47, 0.38), clamp(salete, 0.0, 0.85));

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = est_peau ? 0.45 : 0.3;
}
