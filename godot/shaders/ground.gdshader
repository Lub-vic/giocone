shader_type canvas_item;
// Terreno del mondo esterno disegnato per pixel: macchie di rumore, bordi organici fra regioni,
// strade, acqua e magma animati, scogliere con facciata e ombre.

uniform sampler2D data : filter_nearest, repeat_disable;   // R = bioma, G = flag (bit0 blocco, bit1 strada)
uniform vec2 map_size = vec2(300.0, 220.0);
uniform vec3 boost = vec3(1.0);
uniform bool photo_on = false;
uniform bool ai_on = false;                 // texture di terreno generate dall'AI (pixel art): niente desaturazione ne' retinatura
uniform float ai_gain = 0.62;                // luminosita' delle texture AI rispetto alla luce ambiente del gioco
uniform sampler2D photo_ga : source_color, filter_nearest, repeat_enable;    // atlante 7x1 (256 px per bioma): terreno A
uniform sampler2D photo_ma : source_color, filter_nearest, repeat_enable;    // atlante 7x1: terreno B (a chiazze)
uniform sampler2D photo_path : source_color, filter_nearest, repeat_enable;
uniform sampler2D photo_cob : source_color, filter_nearest, repeat_enable;
const vec3 PTONE[7] = vec3[7](vec3(0.80, 0.76, 0.74), vec3(0.66, 0.74, 0.86), vec3(0.62, 0.70, 0.60), vec3(0.60, 0.70, 0.66),
	vec3(0.72, 0.68, 0.80), vec3(0.80, 0.86, 0.98), vec3(0.85, 0.66, 0.60));
uniform int force_biome = -1;                                // >=0: dungeon (stesso materiale ovunque)                             // compensa la luce ambiente sui materiali emissivi

// il terreno fotografico/AI vale solo nel mondo aperto: negli interni (force_biome >= 0) restano i pavimenti originali con ai_on
bool pon() {
	return photo_on && !(ai_on && force_biome >= 0);
}

varying vec2 wp;

const vec3 DARK[7] = vec3[7](vec3(0.145, 0.145, 0.16), vec3(0.13, 0.20, 0.18), vec3(0.15, 0.145, 0.085), vec3(0.14, 0.20, 0.13),
	vec3(0.15, 0.13, 0.18), vec3(0.54, 0.61, 0.72), vec3(0.10, 0.07, 0.08));
const vec3 MIDC[7] = vec3[7](vec3(0.205, 0.205, 0.225), vec3(0.17, 0.24, 0.22), vec3(0.20, 0.19, 0.11), vec3(0.18, 0.25, 0.15),
	vec3(0.18, 0.16, 0.22), vec3(0.66, 0.73, 0.82), vec3(0.14, 0.10, 0.11));
const vec3 LITC[7] = vec3[7](vec3(0.27, 0.265, 0.285), vec3(0.22, 0.31, 0.29), vec3(0.26, 0.25, 0.14), vec3(0.23, 0.31, 0.18),
	vec3(0.23, 0.21, 0.28), vec3(0.79, 0.85, 0.92), vec3(0.19, 0.14, 0.14));
const vec3 ZONE[7] = vec3[7](vec3(1.02, 0.97, 0.95), vec3(0.82, 1.0, 1.15), vec3(1.25, 0.85, 0.7), vec3(0.8, 1.2, 1.0),
	vec3(1.15, 0.9, 1.2), vec3(0.9, 1.0, 1.15), vec3(1.3, 0.8, 0.7));
const vec3 SPECK[7] = vec3[7](vec3(0.46, 0.38, 0.34), vec3(0.52, 0.58, 0.66), vec3(0.50, 0.32, 0.15), vec3(0.28, 0.46, 0.20),
	vec3(0.44, 0.40, 0.52), vec3(0.95, 0.98, 1.0), vec3(0.2, 0.1, 0.08));
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

float bayer(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	return BAYER[i.y * 4 + i.x] / 16.0;
}

int cflags(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(map_size) - ivec2(1));
	return int(texelFetch(data, c, 0).g * 255.0 + 0.5);
}

int ctheme(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(map_size) - ivec2(1));
	return int(texelFetch(data, c, 0).b * 255.0 + 0.5);
}

int cbiome(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(map_size) - ivec2(1));
	return int(texelFetch(data, c, 0).r * 255.0 + 0.5);
}

float bitf(ivec2 c, int bit) {
	return float((cflags(c) >> bit) & 1);
}

// campo bilineare 0..1 di un flag (bordi morbidi, poi soglia con rumore = forme organiche)
float field(vec2 p, int bit) {
	vec2 q = p / 16.0 - 0.5;
	ivec2 i = ivec2(floor(q));
	vec2 f = fract(q);
	float a = bitf(i, bit);
	float b = bitf(i + ivec2(1, 0), bit);
	float c = bitf(i + ivec2(0, 1), bit);
	float d = bitf(i + ivec2(1, 1), bit);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float thr_at(vec2 p) {
	return 0.5 + (fbm(p * 0.11) - 0.47) * 0.5;
}

bool is_blocked(vec2 p) {
	if (force_biome >= 0) {
		return bitf(ivec2(floor(p / 16.0)), 0) > 0.5;
	}
	return field(p, 0) > thr_at(p);
}

// foto ridotta: 18 livelli per canale con retinatura ordinata (look anni '90)
vec3 retro(vec3 t, vec2 p) {
	if (ai_on) return t;
	return floor(t * 18.0 + bayer(p)) / 18.0;
}

// due foto per bioma alla scala del mondo, mescolate a chiazze irregolari (niente immagine unica ripetuta)
vec3 atlas(sampler2D a, int b, vec2 p, float rep) {
	vec2 q = clamp(fract(p / rep), vec2(1.0 / 256.0), vec2(1.0 - 1.0 / 256.0));   // niente pixel del bioma accanto nell'atlante
	return texture(a, vec2((float(b) + q.x) / 7.0, q.y)).rgb;
}

vec3 photo_ground_b(int b, vec2 p) {
	vec3 g = atlas(photo_ga, b, p, 256.0);
	vec3 m = atlas(photo_ma, b, p + vec2(97.0, 41.0), 384.0);
	float f = fbm(p * 0.011 + float(b) * 3.7) + (fbm(p * 0.05) - 0.5) * 0.25 + (bayer(p) - 0.5) * 0.06;
	vec3 t = mix(g, m, smoothstep(0.46, 0.56, f));
	if (ai_on) {
		return t * ai_gain * (0.88 + 0.24 * fbm(p * 0.004 + 11.0));
	}
	float l = dot(t, vec3(0.3, 0.59, 0.11));
	t = mix(vec3(l), t, 0.66) * PTONE[b];
	t *= 0.85 + 0.3 * fbm(p * 0.004 + 11.0);                  // grandi zone piu' chiare e piu' scure
	return retro(t, p);
}

vec3 photo_ground(vec2 p) {
	return photo_ground_b(1, p);
}

vec3 photo_road(vec2 p, float edge) {
	if (ai_on) {
		vec3 ta = texture(photo_path, p / 256.0).rgb;
		vec3 ma = atlas(photo_ma, 0, p + vec2(13.0, 211.0), 384.0);
		ta = mix(ta, ma, 0.7 * smoothstep(0.42, 0.62, fbm(p * 0.02 + 5.0)));   // pozze e fango sul sentiero
		float tl = dot(ta, vec3(0.3, 0.59, 0.11));
		ta = mix(vec3(tl), ta, 0.3) * vec3(0.92, 0.94, 1.02);                // piu' grigio, meno giallo
		return ta * ai_gain * 0.62;
	}
	vec3 t = texture(photo_path, p / 256.0).rgb;
	vec3 m = atlas(photo_ma, 3, p + vec2(13.0, 211.0), 384.0);
	t = mix(t, m, smoothstep(0.4, 0.62, fbm(p * 0.02 + 5.0) + (bayer(p) - 0.5) * 0.08));   // pozze e fango sul sentiero
	float l = dot(t, vec3(0.3, 0.59, 0.11));
	t = mix(vec3(l), t, 0.55) * vec3(0.78, 0.8, 0.9) * (0.8 + 0.4 * fbm(p * 0.03));
	return retro(t, p);
}

vec3 ground(int b, vec2 p, int th) {
	float n = fbm(p * 0.05);
	float v = n + (bayer(p) - 0.5) * 0.16;
	vec3 c = v < 0.40 ? DARK[b] : (v < 0.56 ? MIDC[b] : LITC[b]);
	vec2 cp = floor(p / 6.0);
	float h = hash21(cp);
	vec2 lc = p - cp * 6.0;
	if (b == 0) {
		if (h < 0.10 && lc.y >= 3.0 && lc.y <= 4.0 && lc.x >= 2.0 && lc.x <= 3.0) {
			c = vec3(0.36, 0.30, 0.31);
		}
	} else if (b == 1 || b == 2) {
		bool tuft = (lc.x == 2.0 && lc.y >= 3.0) || (lc.x == 3.0 && lc.y >= 2.0) || (lc.x == 4.0 && lc.y >= 3.0);
		if (h < 0.20 && tuft) {
			c = b == 1 ? vec3(0.28, 0.38, 0.32) : vec3(0.20, 0.30, 0.17);
		}
		if (b == 1 && h > 0.985 && lc.y == 3.0 && lc.x >= 2.0 && lc.x <= 4.0) {
			c = vec3(0.62, 0.62, 0.72);
		}
		if (b == 2 && vnoise(p * 0.3) > 0.8) {
			c = vec3(0.17, 0.12, 0.09);
		}
	} else if (b == 3) {
		if (vnoise(p * 0.22) > 0.74) {
			c = vec3(0.24, 0.38, 0.18);
		}
		if (h > 0.97 && fract(TIME * 0.6 + h * 9.0) < 0.15 && lc.y == 3.0 && lc.x == 3.0) {
			c = vec3(0.30, 0.65, 0.58);
		}
	} else if (b == 4) {
		vec2 cell = floor(p / 16.0);
		vec2 l16 = p - cell * 16.0;
		float ht = hash21(cell);
		c *= 0.85 + 0.35 * ht;
		if (mod(cell.x + cell.y, 2.0) < 1.0) {
			c *= 0.84;
		}
		if (l16.x < 1.0 || l16.y < 1.0) {
			c = vec3(0.07, 0.06, 0.09);
		} else if (l16.x < 2.0 || l16.y < 2.0) {
			c *= 1.25;
		}
		if (abs(fbm(p * 0.13) - 0.47) < 0.012) {
			c = vec3(0.07, 0.06, 0.09);
		}
		if (th == 0) {
			float tv = hash21(cell + 17.0);
			if (tv < 0.06) {
				c = mix(vec3(0.07, 0.055, 0.05), vec3(0.13, 0.10, 0.08), vnoise(p * 0.6));      // lastra mancante: terra e sassi
				if (l16.x < 1.0 || l16.y < 1.0) c = vec3(0.05, 0.04, 0.06);
				if (h > 0.8) c = vec3(0.26, 0.23, 0.21);
			} else if (tv < 0.15) {
				float dl = abs((l16.x - l16.y) - (tv * 40.0 - 5.0));                            // lastra crepata
				if (dl < 0.8) c = vec3(0.05, 0.04, 0.07);
				if (abs((l16.x + l16.y) - 15.0 - (tv * 12.0 - 2.0)) < 0.6 && l16.x > 6.0) c = vec3(0.05, 0.04, 0.07);
			} else if (tv < 0.22) {
				c = mix(c, vec3(0.16, 0.28, 0.16), 0.55);                                       // lastra coperta di muschio
			} else if (tv > 0.965) {
				if ((abs(l16.x - 8.0) < 1.0 && l16.y > 3.0 && l16.y < 13.0) || (abs(l16.y - 6.0) < 1.0 && l16.x > 4.0 && l16.x < 12.0)) c *= 1.8;   // croce incisa
			}
			if (fbm(p * 0.026 + 60.0) > 0.68) {
				c = mix(c, vec3(0.07, 0.10, 0.19), 0.85);                                       // pozza d'acqua stagnante
				if (vnoise(p * 0.5 + TIME * 0.15) > 0.84) c = vec3(0.32, 0.42, 0.62);
			}
		}
		if (th == 1) {
			float bl = vnoise(p * 0.07 + 4.0);
			if (bl > 0.6) c = mix(c, vec3(0.26, 0.04, 0.07), 0.75);
			if (bl > 0.72 && h > 0.5) c = vec3(0.38, 0.06, 0.09);
		} else if (th == 2) {
			vec2 rc = p - (floor(p / 64.0) + 0.5) * 64.0;
			float rd = length(rc);
			float ang = atan(rc.y, rc.x);
			if (abs(rd - 19.0) < 1.0 || abs(rd - 9.0) < 0.8) c = vec3(0.42, 0.18, 0.66);
			if (abs(rd - 14.0) < 5.0 && mod(ang * 6.0 / 3.14159, 1.0) < 0.07) c = vec3(0.5, 0.24, 0.78);
		} else if (th == 3) {
			c = mod(floor(p.x / 16.0) + floor(p.y / 16.0), 2.0) < 1.0 ? vec3(0.18, 0.16, 0.22) : vec3(0.06, 0.05, 0.08);
			if (l16.x < 1.0 || l16.y < 1.0) c = vec3(0.05, 0.04, 0.07);
		} else if (th == 6) {
			float pr = floor(p.y / 6.0);
			float off = hash21(vec2(pr, 2.0)) * 40.0;
			float pk = floor((p.x + off) / 40.0);
			float hh = hash21(vec2(pk, pr));
			c = mix(vec3(0.17, 0.115, 0.08), vec3(0.24, 0.17, 0.115), hh);
			c *= 0.9 + 0.2 * vnoise(vec2(p.x * 0.15 + hh * 9.0, p.y * 1.7));
			if (mod(p.y, 6.0) < 1.0 || mod(p.x + off, 40.0) < 1.0) c = vec3(0.075, 0.05, 0.04);
		}
		if (th != 6 && vnoise(p * 0.18 + 3.0) > 0.8) {
			c = mix(c, vec3(0.16, 0.26, 0.15), 0.7);
		}
	} else if (b == 5) {
		if (h > 0.93 && lc.x == 3.0 && lc.y == 3.0) {
			c = vec3(0.95, 0.98, 1.0);
		}
		if (abs(vnoise(vec2(p.x * 0.05 + p.y * 0.02, p.y * 0.5)) - 0.5) < 0.03) {
			c = LITC[5] * 1.06;
		}
	} else {
		// lastricato industriale annerito dalla fuliggine, con aloni di ruggine
		vec2 q6 = p / 8.0;
		vec2 f6 = fract(q6);
		float h6 = hash21(floor(q6) + 11.0);
		c = mix(vec3(0.12, 0.115, 0.13), vec3(0.21, 0.195, 0.21), h6);
		if (f6.x < 0.12 || f6.y < 0.12) {
			c = vec3(0.045, 0.04, 0.05);
		} else if (f6.x > 0.85 || f6.y > 0.85) {
			c *= 0.82;
		}
		if (vnoise(p * 0.07 + 5.0) > 0.7) {
			c = mix(c, vec3(0.30, 0.15, 0.09), 0.3);
		}
		vec2 pc = floor(p / 32.0);
		float pv = hash21(pc + 23.0);
		vec2 l32 = p - pc * 32.0;
		if (pv < 0.12) {
			c = vec3(0.07, 0.065, 0.075);                                                       // grata di ferro
			if (mod(l32.x, 4.0) < 2.0) c = vec3(0.18, 0.17, 0.18);
			if (l32.x < 2.0 || l32.y < 2.0) c = vec3(0.04, 0.04, 0.05);
			else if (mod(l32.x, 4.0) >= 2.0 && vnoise(p * 0.3 + TIME * 0.3) > 0.88) c = vec3(0.65, 0.26, 0.07) * boost;   // bagliore sotto
		} else if (pv < 0.22) {
			c = mix(c, vec3(0.36, 0.18, 0.09), 0.6);                                            // piastra arrugginita
			if (hash21(floor(p / 2.0) + 5.0) > 0.9) c = vec3(0.48, 0.26, 0.12);
		} else if (pv < 0.30) {
			c *= 0.55;                                                                          // piastra annerita
		}
		if (abs(fbm(p * 0.045 + 14.0) - 0.47) < 0.0035 && pv > 0.30) c = vec3(0.80, 0.30, 0.07) * boost;      // rare crepe di brace
		if (fbm(p * 0.02 + 80.0) > 0.70) {
			c = mix(c, vec3(0.04, 0.03, 0.06), 0.85);                                           // pozza d'olio
			if (vnoise(p * 0.4 + TIME * 0.1) > 0.85) c = vec3(0.28, 0.16, 0.36);
		}
	}
	// macro-varieta': macchie di materiali diversi a bassa frequenza + accenti di colore rari
	float mp = fbm(p * 0.017 + float(b) * 7.3);
	float mq = fbm(p * 0.031 + 40.0 + float(b) * 3.1);
	if (force_biome < 0) {
		if (b == 0) {
			if (mp > 0.60) {
				c = mix(c, vec3(0.31, 0.26, 0.24), 0.85);                      // terra secca screpolata
				if (abs(fbm(p * 0.11 + 3.0) - 0.47) < 0.018) c *= 0.5;
			} else if (mp < 0.28) {
				c = mix(c, vec3(0.10, 0.08, 0.09), 0.5);                       // terra bruciata
			}
			if (mq > 0.66 && h > 0.55 && ((lc.x == 3.0) || (lc.x == 4.0 && lc.y > 1.0))) c = vec3(0.34, 0.30, 0.17); // erba secca
		} else if (b == 1) {
			if (mp > 0.60) {
				c = mix(c, vec3(0.13, 0.24, 0.20), 0.85);                      // muschio
				if (h < 0.12 && lc.y == 3.0) c = vec3(0.22, 0.36, 0.28);
			} else if (mp < 0.30) {
				c = mix(c, vec3(0.05, 0.08, 0.12), 0.9);                       // fango bagnato
				if (vnoise(p * 0.45 + TIME * 0.05) > 0.8) c = vec3(0.16, 0.22, 0.30);
			}
			if (h > 0.985 && lc.x >= 2.0 && lc.x <= 4.0 && lc.y >= 2.0 && lc.y <= 4.0 && (lc.x == 3.0 || lc.y == 3.0)) c = vec3(0.78, 0.82, 0.92); // gigli pallidi
		} else if (b == 2) {
			if (mp > 0.58) {
				c = mix(c, vec3(0.25, 0.15, 0.07), 0.8);                       // lettiera di foglie
				if (h > 0.55 && h < 0.7) c = vec3(0.34, 0.20, 0.08);
			} else if (mp < 0.32) {
				c = mix(c, vec3(0.10, 0.20, 0.11), 0.8);                       // muschio scuro
			}
			if (h > 0.99 && lc.x == 3.0 && lc.y == 3.0) c = vec3(0.65, 0.12, 0.10);   // bacche
		} else if (b == 3) {
			if (mp > 0.62) {
				c = mix(c, vec3(0.07, 0.17, 0.18), 0.85);                      // pozze stagnanti
				if (vnoise(p * 0.5 + TIME * 0.1) > 0.82) c = vec3(0.18, 0.40, 0.40);
			} else if (mp < 0.30) {
				c = mix(c, vec3(0.26, 0.30, 0.13), 0.8);                       // erba palustre chiara
			}
		} else if (b == 4) {
			if (mp > 0.62) {
				c = mix(c, vec3(0.05, 0.04, 0.06), 0.7);                       // fuliggine
			} else if (mp < 0.28) {
				c = mix(c, vec3(0.20, 0.30, 0.20), 0.45);                      // muschio sulle lastre
			}
			if (abs(fbm(p * 0.09 + 9.0) - 0.47) < 0.012) c = vec3(0.05, 0.04, 0.07);  // crepe
		} else if (b == 5) {
			if (mp > 0.60) {
				c = mix(c, vec3(0.52, 0.68, 0.82), 0.9);                       // ghiaccio vivo
				if (abs(fbm(p * 0.12 + 1.0) - 0.47) < 0.014) c = vec3(0.86, 0.94, 1.0);
			} else if (mp < 0.30) {
				c = mix(c, vec3(0.93, 0.96, 1.0), 0.9);                        // neve fresca
			}
		}
	}
	float zn = fbm(p * 0.013 + 31.0);
	c *= mix(vec3(1.0), ZONE[b], smoothstep(0.42, 0.62, zn));
	float h2 = hash21(floor(p / 3.0) + 77.0);
	if (h2 > 0.985 && b != 6 && (force_biome < 0)) {
		c = mix(c, SPECK[b], 0.6);
	}
	if (pon()) {
		if (force_biome >= 0) return photo_ground_b(4, p) * vec3(0.78, 0.74, 0.82);   // pavimenti dei dungeon: pietra
		return photo_ground_b(b, p);
	}
	return c * (0.82 + 0.36 * fbm(p * 0.006 + 5.0));
}

vec3 cobble_col(vec2 p) {
	vec2 q = p / 5.0;
	float row = floor(q.y);
	q.x += hash21(vec2(row, 1.0)) * 5.0 + mod(row, 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float h = hash21(cell + 3.0);
	vec3 c = mix(vec3(0.19, 0.17, 0.21), vec3(0.33, 0.30, 0.35), h);
	if (f.x < 0.2 || f.y < 0.22) {
		c = vec3(0.07, 0.06, 0.08);
	} else if (f.y > 0.78 || f.x > 0.8) {
		c *= 0.78;
	} else if (f.x < 0.35 && f.y < 0.4) {
		c *= 1.18;
	}
	if (vnoise(p * 0.2) > 0.8 && h > 0.45) {
		c = mix(c, vec3(0.16, 0.26, 0.15), 0.6);
	}
	return c;
}

vec3 bridge_col(vec2 p, float edge) {
	ivec2 cell = ivec2(floor(p / 16.0));
	float wl = bitf(cell + ivec2(-2, 0), 3) + bitf(cell + ivec2(2, 0), 3) + bitf(cell + ivec2(-3, 0), 3) + bitf(cell + ivec2(3, 0), 3);
	float s = wl > 0.5 ? p.x : p.y;
	float k = floor(s / 4.0);
	float h = hash21(vec2(k, floor((wl > 0.5 ? p.y : p.x) / 24.0)));
	vec3 c = mix(vec3(0.20, 0.14, 0.10), vec3(0.31, 0.22, 0.16), h);
	if (mod(s, 4.0) < 1.0) {
		c = vec3(0.08, 0.05, 0.05);
	}
	if (edge < 0.14) {
		c = vec3(0.13, 0.09, 0.07);
	}
	return c;
}

vec3 carpet_col(vec2 p, float edge) {
	vec3 c = vec3(0.30, 0.05, 0.10);
	if (mod(floor(p.x / 2.0) + floor(p.y / 2.0), 2.0) < 1.0) c *= 0.9;
	if (edge < 0.10) {
		c = vec3(0.62, 0.46, 0.14);
	} else if (edge < 0.18) {
		c = vec3(0.16, 0.03, 0.06);
	}
	if (vnoise(p * 0.3) > 0.85) c *= 0.7;
	return c;
}

vec3 road_col(vec2 p, float edge) {
	float n = fbm(p * 0.09);
	vec3 c = n < 0.45 ? vec3(0.32, 0.25, 0.17) : vec3(0.38, 0.30, 0.21);
	float h = hash21(floor(p / 2.0));
	if (h > 0.88) {
		c = vec3(0.48, 0.39, 0.29);
	}
	if (h < 0.06) {
		c = vec3(0.25, 0.19, 0.14);
	}
	if (edge < 0.10) {
		c = vec3(0.17, 0.12, 0.09);
	} else if (edge < 0.17) {
		c *= 0.78;
	}
	return c;
}

vec3 water(vec2 p, float depth) {
	float t = TIME;
	float w = vnoise(vec2(p.x * 0.10 + t * 0.12, p.y * 0.30 - t * 0.08));
	vec3 c = mix(vec3(0.03, 0.07, 0.09), vec3(0.05, 0.12, 0.15), w);
	float rip = sin(p.y * 0.9 + vnoise(p * 0.08) * 7.0 + t * 1.3);
	if (rip > 0.93) {
		c = vec3(0.10, 0.24, 0.28);
	}
	float h = hash21(floor(p / 2.0));
	if (h > 0.985 && fract(t * 0.7 + h * 7.0) < 0.22) {
		c = vec3(0.50, 0.78, 0.78);
	}
	if (depth < 0.09) {
		c = mix(c, vec3(0.13, 0.19, 0.12), 0.65);
	}
	if (depth < 0.04) {
		c = vec3(0.21, 0.29, 0.17);
	}
	return c;
}

vec3 brickwall(vec2 p, float depth) {
	float row = floor(p.y / 4.0);
	float bx = p.x + mod(row, 2.0) * 4.0 + hash21(vec2(row, 3.0)) * 8.0;
	vec2 cell = vec2(floor(bx / 8.0), row);
	float h = hash21(cell);
	vec3 c = mix(vec3(0.17, 0.09, 0.08), vec3(0.28, 0.14, 0.11), h);
	if (mod(p.y, 4.0) < 1.0 || mod(bx, 8.0) < 1.0) {
		c = vec3(0.06, 0.045, 0.05);
	}
	if (vnoise(p * 0.12 + 2.0) > 0.78) {
		c = mix(c, vec3(0.05, 0.05, 0.06), 0.6);
	}
	if (depth < 0.06) {
		c *= 1.25;
	}
	return c * 0.8;
}

vec3 magma(vec2 p, float depth) {
	float f = fbm(p * 0.07 + vec2(TIME * 0.04, TIME * 0.02));
	float g = fbm(p * 0.15 - vec2(TIME * 0.03, 0.0));
	float v = f * 0.7 + g * 0.3;
	vec3 c = vec3(0.30, 0.04, 0.02);
	if (v > 0.42) c = vec3(0.70, 0.13, 0.03);
	if (v > 0.50) c = vec3(1.0, 0.42, 0.07);
	if (v > 0.64) c = vec3(1.0, 0.72, 0.22);
	c *= boost;
	if (vnoise(p * 0.2 + TIME * 0.01) > 0.72 && depth > 0.1) {
		c = vec3(0.10, 0.04, 0.04);
	}
	if (depth < 0.10) {
		c = mix(c, vec3(0.10, 0.04, 0.04), 0.7);
	}
	return c;
}

vec3 cliff(int b, vec2 p, float depth) {
	// facciata se subito sotto c'e' terreno libero
	float o3 = is_blocked(p + vec2(0.0, 3.0)) ? 0.0 : 1.0;
	float o6 = is_blocked(p + vec2(0.0, 6.0)) ? 0.0 : 1.0;
	float o9 = is_blocked(p + vec2(0.0, 9.0)) ? 0.0 : 1.0;
	float lvl = o3 + o6 + o9;
	float h = hash21(floor(p / 3.0));
	if (lvl > 0.5) {
		float sh = 1.0 - 0.18 * lvl;
		vec3 c;
		if (b == 5) {
			c = mix(vec3(0.42, 0.55, 0.72), vec3(0.28, 0.40, 0.58), step(0.5, fract(p.x * 0.17 + hash21(floor(p / 5.0)) )));
			if (h > 0.9) c = vec3(0.7, 0.85, 0.95);
		} else if (b == 4) {
			float row = floor(p.y / 4.0);
			float off = mod(row, 2.0) * 4.0;
			vec2 bc = vec2(floor((p.x + off) / 8.0), row);
			c = vec3(0.17, 0.15, 0.21) * (0.8 + 0.5 * hash21(bc));
			if (mod(p.y, 4.0) < 1.0 || mod(p.x + off, 8.0) < 1.0) c = vec3(0.06, 0.05, 0.08);
			if (hash21(bc + 9.0) > 0.88 && lvl > 2.0) c = vec3(0.12, 0.2, 0.12);
		} else {
			c = vec3(0.16, 0.14, 0.17) * (0.7 + 0.6 * h);
		}
		return c * sh;
	}
	// sommita'
	float n = fbm(p * 0.12);
	vec3 c;
	if (b == 5) {
		c = n < 0.5 ? vec3(0.78, 0.86, 0.94) : vec3(0.90, 0.95, 1.0);
	} else if (b == 4) {
		c = n < 0.5 ? vec3(0.10, 0.09, 0.13) : vec3(0.14, 0.12, 0.18);
		if (force_biome >= 0) {
			c = vec3(0.12, 0.10, 0.15) + vec3(0.02) * hash21(floor(p / 2.0));
			if (!is_blocked(p - vec2(0.0, 3.0)) || !is_blocked(p + vec2(3.0, 0.0)) || !is_blocked(p - vec2(3.0, 0.0))) {
				c = vec3(0.27, 0.24, 0.33);
			}
		}
		if (depth < 0.06) c = vec3(0.26, 0.23, 0.32);
	} else {
		c = n < 0.5 ? vec3(0.18, 0.15, 0.18) : vec3(0.25, 0.21, 0.23);
	}
	return c;
}

void fragment() {
	vec2 p = floor(wp);
	ivec2 cell = ivec2(floor(p / 16.0));
	int bio = cbiome(cell);
	if (force_biome >= 0) {
		bio = force_biome;
	}
	vec2 wv = vec2(vnoise(p * 0.05), vnoise(p * 0.05 + 37.0)) - 0.5;
	ivec2 wcell = ivec2(floor((p + wv * 34.0) / 16.0));
	int gb = cbiome(wcell);
	int th = ctheme(wcell);
	if (force_biome >= 0) {
		gb = force_biome;
	}
	float thr = thr_at(p);
	float bf = field(p, 0);
	if (force_biome >= 0) {
		bf = bitf(cell, 0);
		thr = 0.5;
	}
	vec3 col;
	bool voidcell = false;
	if (force_biome >= 0 && bf > thr) {
		voidcell = true;
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				if (bitf(cell + ivec2(dx, dy), 0) < 0.5) {
					voidcell = false;
				}
			}
		}
	}
	if (voidcell) {
		col = vec3(0.015, 0.01, 0.025);
	} else if (bf > thr) {
		float depth = bf - thr;
		if (force_biome < 0 && field(p, 6) > 0.5) {
			// abisso oltre i confini del mondo: vuoto viola con nebbia e un bordo di roccia
			float mist = fbm(p * 0.03 + vec2(TIME * 0.012, -TIME * 0.008));
			col = mix(vec3(0.015, 0.012, 0.03), vec3(0.075, 0.06, 0.12), mist);
			if (depth < 0.07) {
				col = mix(vec3(0.18, 0.15, 0.2), col, depth / 0.07) * 0.9;
			}
		} else if (field(p, 3) > 0.45) {
			col = water(p, depth) * vec3(0.95, 1.1, 1.25);
		} else if (bio == 1 || bio == 2) {
			col = ground(gb, p, th) * 0.42;
			if (pon()) col = photo_ground_b(gb, p) * 0.45;
			if (vnoise(p * 0.35) > 0.78) col += vec3(0.04, 0.02, 0.03);
		} else if (bio == 3) {
			col = water(p, depth);
		} else if (bio == 6) {
			col = brickwall(p, depth);
		} else {
			col = cliff(bio, p, depth);
			if (pon()) {   // pareti di roccia: foto di detriti, piu' scure verso l'interno
				col = retro(atlas(photo_ma, 4, p, 384.0) * vec3(0.55, 0.52, 0.6) * (1.0 - clamp(depth * 3.0, 0.0, 0.6)), p);
			}
		}
	} else {
		col = ground(gb, p, th);
		float rf = field(p, 1);
		float rthr = 0.5 + (fbm(p * 0.2 + 9.0) - 0.47) * 0.55;
		if (rf > rthr) {
			col = road_col(p, rf - rthr);
			if (pon() && force_biome < 0) col = photo_road(p, rf - rthr);
				if (gb == 0 && force_biome < 0 && !ai_on) col = col * 1.28 + vec3(0.03, 0.02, 0.0);
		}
		float cf = field(p, 2);
		float cthr = 0.5 + (fbm(p * 0.2 + 21.0) - 0.47) * 0.4;
		if (cf > cthr) {
			col = cobble_col(p);
			if (pon()) col = ai_on ? texture(photo_cob, p / 128.0).rgb * ai_gain * 0.8 : retro(texture(photo_cob, p / 192.0).rgb * vec3(0.72, 0.72, 0.8), p);
			if (cf < cthr + 0.07) {
				col *= 0.7;
			}
		}
		if (force_biome >= 0) {
			float kf = field(p, 5);
			float kthr = 0.5 + (fbm(p * 0.2 + 5.0) - 0.47) * 0.15;
			if (kf > kthr) {
				col = carpet_col(p, kf - kthr);
			}
		}
		float bfl = field(p, 4);
		if (bfl > 0.5) {
			col = bridge_col(p, bfl - 0.5);
		}
		if (ai_on && force_biome < 0) {
			// radicamento degli oggetti: vicino a case, alberi e recinti il suolo si fa piu' scuro e battuto,
			// con un anello di fango a retinatura ordinata, cosi' gli sprite non sembrano incollati sullo sfondo
			float halo = smoothstep(0.06, 0.55, field(p, 0));
			vec3 mudc = atlas(photo_ma, 0, p + vec2(5.0, 9.0), 384.0) * ai_gain * 0.75;
			if (cf <= cthr) {
				col = mix(col, mudc, step(0.30 + bayer(p) * 0.35, halo) * 0.75);
			}
			col *= 1.0 - 0.34 * halo;
		}
		// ombra proiettata dagli ostacoli (luce da alto-sinistra)
		vec2 sp = p - vec2(4.0, 5.0);
		int sb = cbiome(ivec2(floor(sp / 16.0)));
		if (sb != 3 && sb != 6 && is_blocked(sp)) {
			col *= 0.62;
		}
		// bagliore/umidita' sulla riva
		if (bio == 3 || gb == 3) {
			// nulla: il fango resta scuro
		}
	}
	COLOR = vec4(col, 1.0);
}
