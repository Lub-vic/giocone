# Crypt of Embers (Godot 4.7) - soulslike
Avvio: apri `godot/` con Godot 4, F5.
Comandi: WASD muovi · SPAZIO/J/click colpo leggero (3 in combo) · L/tasto destro colpo pesante · SHIFT/K rotolata · Q fiala · E falo' · 1/2/3 sceglie potenziamento · T (al falo') viaggio rapido.
Asset: `py ../tools/gothic.py assets`. Autotest: `Godot_console --headless --quit-after 300 -- --selftest`.

Salvataggio automatico (falo', livello, acquisti, boss). Dopo la vittoria: R = Nuovo Ciclo (mappa nuova, nemici piu' forti, tieni livello e potenziamenti).

Classi: Cavaliere, Cacciatore, Negromante, Chierico. Tasti: 1 / 2 magie · TAB cambia arma · E raccoglie bottino ed entra negli edifici · al falo': Z / X assegnano le magie apprese.

Bolla spazio-temporale: N (pad: SELECT, touch: CRO) evoca un oggetto a caso dal passato/futuro (serve il Cronotone, si ricarica uccidendo). Gli oggetti inutili si trasformano in armi/armature/pozioni alla forgia, scheda ANACRON.

Mezzi (jackpot, da livello 10): carro da guerra, carrarmato (14), mini-ufo (20). Ci sali a bordo: il mezzo ha vita e tempo propri e si guida con i comandi normali; ATTACCO spara l arma del mezzo.

Ere del mondo: ogni evocazione alza il livello tecnologico (futuro +1, passato +0.4). Ere: FANTASY, ALCHIMIA (10), STEAMPUNK (30), PROTO-INDUSTRIALE (60). Cambiano tinta del mondo, nemici (piu forti, esplosivi, corazzati) e battute dei paesani.
