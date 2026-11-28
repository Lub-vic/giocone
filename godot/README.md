# Temporama - ...a proposito di un ufo e uno stregone (Godot 4.7) - soulslike
Avvio: apri `godot/` con Godot 4, F5.
Prima persona (all'aperto): V o L3, sempre; F7 resta valido. Zoom Orda/Tattica: H o croce giù. Parata: C o LT. Pad: Y evoca col Cronotone, SELECT cambia arma (tenuto: borsa), croce sx/dx cambia/usa oggetto, croce su magia 2. Tutorial: suggerimenti in gioco col tasto in un cerchio (`scripts/tutorial.gd`; prova: `-- --tutotest`). Con il pad la mira manuale è attiva di default.
Comandi: WASD muovi · SPAZIO/J/click colpo leggero (3 in combo) · L/tasto destro colpo pesante · SHIFT/K rotolata · Q fiala · E falo' · 1/2/3 sceglie potenziamento · T (al falo') viaggio rapido.
Menu sviluppo: dal menu pausa (ESC) scegli DEBUG / TEST MISSIONI per selezionare aree, missioni, modalità di gioco in prova (tra cui Radura Temporale) e tutte le funzioni assegnate ai tasti funzione (F2, F3, F5-F12, incluse MAIUSC+F6/F10); F2 apre lo stesso menu direttamente. Le azioni non richiedono i relativi tasti funzione. F1 e F4 non hanno azioni assegnate. I test missione non salvano i progressi.
Radura Temporale: arena ampia, inquadratura prospettica a 3/4 più bassa e ravvicinata, con un leggero effetto fisheye attivo solo in questa scena; la camera segue il punto medio tra eroe e UFO. Movimento libero sul terreno (WASD o levetta sinistra). L'UFO resta sospeso sopra il centro senza una bolla attorno. Gli oggetti compaiono dentro la stessa bolla spazio-temporale usata dall'evocazione dell'eroe, poi precipitano: il roster comprende 30 oggetti diversi. Solo tostapane, frullatore, batteria, aspirapolvere, phon, energy drink, drone e mine restano a terra per 0,9-1,3 secondi ed esplodono, con il cerchio d'impatto che pulsa sempre più rapidamente. Gli oggetti inerti, come racchetta e stivali, non esplodono: restano per 4 secondi e possono fare un piccolo danno all'impatto; le armi raccolte non esplodono. Raccogli un bazooka, un fucile a pompa o un'arma al plasma: ogni arma consente un solo proiettile, poi va raccolta un'altra arma. Il primo laser parte dopo 5 secondi: la carica arancione dura 0,75 secondi, poi il raggio ciano resta attivo per 2,5 secondi e il punto d'impatto insegue l'eroe a velocità limitata, permettendo di schivare. Il laser infligge 8 danni ogni 0,55 secondi, si ricarica per 7 secondi e si interrompe quando l'UFO fugge. Dopo 6 colpi l'UFO fugge oscillando e lasciando fumo, senza essere distrutto.
Asset: `py ../tools/gothic.py assets`. Autotest: `Godot_console --headless --quit-after 300 -- --selftest`; collegamenti del mondo: `Godot_console --headless -- --roadtest`; cattura della rete: `--roadshot` (salva `user://roadmap.png` e `user://roadmap_pixels.png`); Radura Temporale: `Godot_console --headless -- --temporalclearingtest`.
La rete stradale collega biomi, ingressi, arene e POI nominati con sentieri secondari deterministici, senza spostare i luoghi, creare nuovi ponti o aggirare i cancelli.

### Build Windows
Da PowerShell nella root del repository:
```powershell
$godot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path (Join-Path $PWD 'godot') --export-release 'Windows Desktop' (Join-Path $PWD 'build\Temporama.exe')
```

Salvataggio automatico (falo', livello, acquisti, boss). Dopo la vittoria: R = Nuovo Ciclo (mappa nuova, nemici piu' forti, tieni livello e potenziamenti).

Classi: Cavaliere, Cacciatore, Negromante, Chierico. Tasti: 1 / 2 magie · TAB cambia arma · E raccoglie bottino ed entra negli edifici · al falo': Z / X assegnano le magie apprese.

Bolla spazio-temporale: N (pad: SELECT, touch: CRO) apre una bolla a qualche passo da te (oro = passato, azzurro = futuro): l oggetto ne esce e ti raggiunge. Evoca un oggetto a caso dal passato/futuro (serve il Cronotone, si ricarica uccidendo). Gli oggetti inutili si trasformano in armi/armature/pozioni alla forgia, scheda ANACRON.

Mezzi (jackpot, da livello 10): carro da guerra, carrarmato (14), mini-ufo (20). Ci sali a bordo: il mezzo ha vita e tempo propri e si guida con i comandi normali; L ufo vola sopra ogni ostacolo, il carrarmato abbatte tutto quello che incontra, montagne comprese, senza bottino. ATTACCO spara l arma principale del mezzo, COLPO PESANTE l arma secondaria (carro: balista + catapulta, carrarmato: mitragliatrice + cannone, ufo: laser + onda elettrica).

Ere del mondo: ogni evocazione alza il livello tecnologico (futuro +1, passato +0.4). Ere: FANTASY, ALCHIMIA (10), STEAMPUNK (30), PROTO-INDUSTRIALE (60). Cambiano tinta del mondo, nemici (piu forti, esplosivi, corazzati) e battute dei paesani.
Sprite Cronotone: `py ../tools/chrono_sprites.py assets/sprites` (icone oggetti ch_*, mezzi veh_*, drone, golem; solo Python/PIL).
Armi dal futuro (solo dal Cronotone, si impugnano subito): pistola (lv 1), fucile a pompa (6), mitra (8), motosega (9), pistola laser (12), spada laser (15), lanciarazzi (18), fucile al plasma (22). Altri 14 oggetti inutili (mattarello, padella, ferro da stiro, phon, chitarra elettrica, asta per selfie, candeliere, casco da moto, giubbotto, stivali, skateboard, secchio, caffe', energy drink). Sprite: `py ../tools/future_weapons.py assets/sprites`.
