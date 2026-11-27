# Piano attività e bugfix

Aggiornato il 27/11/2026. I numeri fra parentesi sono quelli della lista originale.
"Verificato" = visto nel codice o provato nel gioco. "Da accertare" = ipotesi.

## Ordine e stato

| Fase | Contenuto | Stato |
|---|---|---|
| A | Bug visibili (1, 2, 3) | fatta |
| B | Missioni, freccia, luoghi (4, 4.1, 4.2) e falò (8) | fatta, prova automatica dell'intera sequenza |
| C | Ritmo ed economia (9, 5, 6, 7) | prima taratura fatta; **da regolare sulle partite vere** |
| D | Boss (10) e oggetti dal futuro necessari (11) | fatta una prima versione; **difficoltà da provare in partita** |
| E | Coda tecnica | in parte |

---

## Fase A — fatta

- **(1) Casa del villaggio che scompare** e **(2) porta invisibile**: stessa causa. La posizione del giocatore veniva
  tenuta "libera" dal 3D: uscendo da una casa, quando il blocco veniva rigenerato la casa non veniva ricostruita ma la
  porta restava. Prova: prima 6 scomparse su 6 visite, dopo 0 su 6.
- **(3) Pagine di diario invisibili**: erano create come arredo, che il 3D non disegna.
- Trovati e corretti con la stessa verifica:
  - anche il **bottino a terra** era invisibile;
  - i **cancelli sigillati** erano invisibili e si attraversavano;
  - il **fiume** si attraversava a nuoto, quindi i cancelli si potevano aggirare. Ora si passa solo sui ponti
    (i 4 attraversamenti delle vie principali risultano percorribili).

Da controllare in partita: un salvataggio esistente, soprattutto se ti trovavi oltre un cancello ancora chiuso.

---

## Fase B — fatta

Le tappe sono in un'unica tabella, `godot/scripts/missions.gd`:

1. anziano · 2. pagina nel villaggio · 3. scoprire 4 luoghi · 4. livello 3 · 5. 18 provviste · **6. fienile** ·
7. scoprire 6 luoghi · 8. 5 pagine · 9. livello 6 · **10. radura dell'ufo** · 11. campana.

Le tre missioni principali sono: liberare il villaggio, fienile, radura.

- Il fienile è fuori dalla cinta; l'assalto parte solo lì e il tempo si ferma se ti allontani.
- La radura è scelta lontano dal villaggio, nel punto più pianeggiante fra quelli adatti.
- Prima della liberazione niente falò, letti o accampamenti; se muori rinasci accanto al falò del villaggio
  (nelle celle, nelle celle).
- I salvataggi con la vecchia numerazione vengono convertiti.
- Prova: `Godot_console --headless --path godot -- --sequencetest`.

## Fase C — prima taratura

Obiettivo: **circa 1 ora** per le prime 3 missioni, **circa 10 ore** per la storia.
**Nessuna delle due durate è stata misurata**: serve una partita vera.

- Livelli più cari: livello 3 = 552 anime in totale (prima 323), livello 6 = 4.770 (prima 2.570).
- Tappe di esplorazione e raccolta fra fienile e radura.
- Grado di storia (0 prima del fienile, 1 dopo, 2 dopo la radura, 3 dopo il primo custode) che limita armi, alleati
  e ricette del futuro. Durante la singolarità escono solo cose a tempo.
- Registro di partita: `%APPDATA%\Godot\app_userdata\Crypt of Embers\registro_partita.csv`.
  Dopo una partita, con quel file si correggono costi e quantità.
- Ancora da fare: per arrivare a 10 ore servono quasi certamente **contenuti nuovi dopo la campana**, non solo
  numeri più alti.
- Prova: `--balancetest`.

## Fase D — prima versione

- Boss: più vita e danno, meno pause, onda d'urto annunciata e rinforzi a ogni cambio di fase.
- Lucchetto 1: sigillo sulla porta della cripta del cimitero, si spezza evocando lì accanto.
- Lucchetto 2: scudo del primo custode, cade per 18 secondi a ogni evocazione vicina.
- La carica necessaria è garantita. Vale qualunque oggetto evocato.
- Da provare in partita: difficoltà (obiettivo 3–6 tentativi per boss). Il Campanaro non è stato toccato.

## Fase E — coda tecnica

Fatto:
- corretti i due errori noti dei test;
- gli oggetti 3D sulle strade vengono spostati (163) invece che tolti (4 tolti);
- pagine, bottino, risorse, oggetti di missione, scavi e santuari finiti dentro un oggetto 3D vengono portati fuori.

Da fare:
1. **Un solo mondo:** la logica 2D piazza ancora ingombri invisibili. Va fatto a zone, con confronto prima e dopo,
   tenendo il villaggio 3D come riferimento.
2. **Edifici della mappa non disegnati** nel mondo aperto (cattedrale, cappella, mausolei).
3. **Tempi di caricamento** (rimandati su tua richiesta).
