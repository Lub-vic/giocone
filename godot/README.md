# Crypt of Embers (Godot 4.7) - soulslike
Avvio: apri `godot/` con Godot 4, F5.
Comandi: WASD muovi · SPAZIO/J/click colpo leggero (3 in combo) · L/tasto destro colpo pesante · SHIFT/K rotolata · Q fiala · E falo' · 1/2/3 sceglie potenziamento · T (al falo') viaggio rapido.
Asset: `py ../tools/gothic.py assets`. Autotest: `Godot_console --headless --quit-after 300 -- --selftest`.

### Build Windows
Da PowerShell nella root del repository:
```powershell
$godot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path (Join-Path $PWD 'godot') --export-release 'Windows Desktop' (Join-Path $PWD 'build\CryptOfEmbers.exe')
```

Salvataggio automatico (falo', livello, acquisti, boss). Dopo la vittoria: R = Nuovo Ciclo (mappa nuova, nemici piu' forti, tieni livello e potenziamenti).

Classi: Cavaliere, Cacciatore, Negromante, Chierico. Tasti: 1 / 2 magie · TAB cambia arma · E raccoglie bottino ed entra negli edifici · al falo': Z / X assegnano le magie apprese.

Bolla spazio-temporale: N (pad: SELECT, touch: CRO) apre una bolla a qualche passo da te (oro = passato, azzurro = futuro): l oggetto ne esce e ti raggiunge. Evoca un oggetto a caso dal passato/futuro (serve il Cronotone, si ricarica uccidendo). Gli oggetti inutili si trasformano in armi/armature/pozioni alla forgia, scheda ANACRON.

Mezzi (jackpot, da livello 10): carro da guerra, carrarmato (14), mini-ufo (20). Ci sali a bordo: il mezzo ha vita e tempo propri e si guida con i comandi normali; L ufo vola sopra ogni ostacolo, il carrarmato abbatte tutto quello che incontra, montagne comprese, senza bottino. ATTACCO spara l arma principale del mezzo, COLPO PESANTE l arma secondaria (carro: balista + catapulta, carrarmato: mitragliatrice + cannone, ufo: laser + onda elettrica).

Ere del mondo: ogni evocazione alza il livello tecnologico (futuro +1, passato +0.4). Ere: FANTASY, ALCHIMIA (10), STEAMPUNK (30), PROTO-INDUSTRIALE (60). Cambiano tinta del mondo, nemici (piu forti, esplosivi, corazzati) e battute dei paesani.
Sprite Cronotone: `py ../tools/chrono_sprites.py assets/sprites` (icone oggetti ch_*, mezzi veh_*, drone, golem; solo Python/PIL).
Armi dal futuro (solo dal Cronotone, si impugnano subito): pistola (lv 1), fucile a pompa (6), mitra (8), motosega (9), pistola laser (12), spada laser (15), lanciarazzi (18), fucile al plasma (22). Altri 14 oggetti inutili (mattarello, padella, ferro da stiro, phon, chitarra elettrica, asta per selfie, candeliere, casco da moto, giubbotto, stivali, skateboard, secchio, caffe', energy drink). Sprite: `py ../tools/future_weapons.py assets/sprites`.
