# Piano attività e bugfix

Aggiornato il 27/11/2026. I numeri fra parentesi sono quelli della lista originale.
"Verificato" = visto nel codice o provato nel gioco. "Da accertare" = ipotesi.

## Ordine

| Fase | Contenuto | Perché in quest'ordine | Stato |
|---|---|---|---|
| A | Bug visibili (1, 2, 3) | bloccano il gioco e le missioni | **fatta** |
| B | Missioni scriptate: ordine, freccia, luoghi (4, 4.1, 4.2) e falò (8) | prima la sequenza deve funzionare, poi si può regolare il ritmo | prossima |
| C | Ritmo ed economia (9, 5, 6, 7) | si tarano insieme: anime, livelli, evocazioni, durata | |
| D | Boss (10) e oggetti dal futuro necessari (11) | dipendono dalla potenza del giocatore fissata in C | |
| E | Coda tecnica | non blocca il resto | |

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

## Fase B — missioni scriptate

Ordine di lavoro: B1 → B2 → B3 → B4.

### B1. Una sola sequenza, in ordine, con freccia sempre corretta (4)
- **Verificato:** il percorso guidato ha 5 tappe (anziano → pagina → fienile → livello 3 → campana), precedute dalle
  celle e dalla liberazione del villaggio. A queste si sovrappongono eventi gestiti a parte in `story.gd`
  (fuggiasco, ufo, apparecchio caduto, singolarità), ciascuno con proprie condizioni.
- **Da accertare:** quali combinazioni fanno partire gli eventi fuori ordine. I cancelli attraversabili (corretti)
  possono aver contribuito.
- **Lavoro:** un'unica tabella ordinata delle tappe (condizione di partenza, luogo, testo, freccia, ricompensa).
  Ogni tappa parte solo se la precedente è chiusa. La freccia punta sempre al luogo della tappa attiva, anche lontano,
  con la distanza.
- **Fatto quando:** un test automatico percorre la sequenza dall'inizio alla fine e per ogni tappa controlla ordine,
  luogo raggiungibile in 3D e freccia sul bersaglio.

### B2. Orda fuori dal villaggio (4.1)
- **Verificato:** il fienile viene scelto dal motore 3D; l'orda nasce attorno al giocatore e parte quando il contadino
  lo raggiunge, ovunque si trovi.
- **Lavoro:** fienile appena fuori dalla cinta; il contadino accompagna o indica il luogo; l'assalto parte solo lì.
- **Fatto quando:** l'assalto non può partire dentro la cinta e la freccia porta al fienile.

### B3. Combattimento con l'ufo in radura (4.2)
- **Verificato:** la Radura Temporale risulta avviabile solo dal menu di prova, non dalla storia.
- **Lavoro:** inserirla come tappa, in un punto fisso lontano dal villaggio, ampio e pianeggiante (raggio libero e
  dislivello controllati sul terreno 3D), con freccia.
- **Da decidere:** in che punto della sequenza va. Proposta: dopo il fienile.

### B4. Falò, letti e accampamenti solo dopo la liberazione (8)
- **Verificato:** oggi è bloccato soltanto il falò del villaggio. Gli altri falò e i letti funzionano da subito.
- **Lavoro:** prima della liberazione nessun riposo, salvataggio al falò, viaggio rapido o aumento di livello; messaggio chiaro.
- **Da decidere:** dove si rinasce se si muore prima della liberazione. Proposta: all'uscita delle celle.

---

## Fase C — ritmo ed economia

Obiettivo: **terza missione dopo circa 1 ora**, storia completa in **circa 10 ore**.

- **Da decidere:** quale conti come "terza missione". Proposta: il fienile (celle e liberazione escluse dal conteggio:
  anziano, pagina, fienile).

### C1. Misurare prima di cambiare
Registro di partita (tempo di gioco, anime guadagnate e spese per fonte, livello, evocazioni, morti, tappe) e una
tabella con l'andamento desiderato ora per ora. Senza queste misure la taratura è a sensazione.

### C2. Durata e ordine (9)
- **Verificato:** il contadino arriva dopo 150 secondi; diverse tappe si chiudono in pochi istanti
  (parlare, raccogliere una pagina).
- **Lavoro:** tappe con obiettivi veri fra una missione e l'altra (esplorare, raccogliere, luoghi più distanti).
  Preferire contenuti a semplici timer.
- **Nota:** 10 ore richiedono contenuti in più, non solo costi più alti. Da stimare dopo C1.

### C3. Livelli (5)
- **Da accertare:** quante anime arrivano per fonte e quanto costa ogni livello nella storia.
- **Lavoro:** ritoccare costi dei livelli e ricompense sui dati di C1.

### C4. Crafting degli oggetti cronotoni (6)
- **Verificato:** nell'elenco degli oggetti da forgiare (`JUNK`) non c'è un livello minimo, al contrario di armi e
  alleati evocabili.
- **Lavoro:** ricette a gradi, con materiali rari e sblocco legato alla storia.

### C5. Armi potenti dall'inizio (7)
- **Verificato:** le armi dal futuro hanno un livello minimo, con probabilità fissa del 12%. Durante la liberazione del
  villaggio la "singolarità" tiene il Cronotone sempre carico: evocazioni illimitate.
- **Da accertare:** se è questa la fonte principale dello squilibrio.
- **Lavoro:** limitare ciò che può uscire in base alla tappa di storia, non solo al livello; rivedere la singolarità.
- **Da decidere:** la singolarità deve restare un momento di "potere assoluto"? Proposta: sì, ma con soli oggetti a
  tempo, che spariscono quando si chiude e non danno materiali.

---

## Fase D — sfida e senso delle evocazioni

### D1. Boss più impegnativi (10)
- **Lavoro:** non solo più vita: più fasi, attacchi da leggere, finestre di punizione. Si parte da un boss pilota
  (il Carceriere o il Custode del cimitero), che provi prima di estendere agli altri.
- **Da decidere:** quanti tentativi medi ti aspetti per un boss. Proposta: 3–6.

### D2. Oggetti dal futuro necessari alla progressione (11)
- **Proposta:** pochi "lucchetti temporali" che si superano solo con un tipo di oggetto: un ostacolo da far esplodere,
  un meccanismo da alimentare, uno scudo del boss che cade solo con un'arma dal futuro.
- **Regola:** niente blocco per sfortuna. L'oggetto richiesto deve essere garantito (evocazione assicurata vicino
  all'ostacolo, o ricetta certa).
- **Da decidere:** approvare l'idea e scegliere i primi due lucchetti.

---

## Fase E — coda tecnica

1. **Un solo mondo:** la logica 2D piazza ingombri invisibili, il 3D crea case e arredo propri. Il villaggio 3D resta il
   riferimento estetico: la logica deve usarne posizioni e collisioni. Finché non è fatto, altri oggetti o nemici possono
   comparire in punti incoerenti.
2. **Ricollocare invece di togliere** gli oggetti 3D che coprono le strade fuori dal villaggio.
3. **Edifici della mappa non disegnati** nel mondo aperto (cattedrale, cappella, mausolei).
4. **Errori noti nei test**, presenti anche prima: `world_free` nei dungeon (`belltest`), `interact` (`d0test`).
5. **Tempi di caricamento** (rimandati).

---

## Decisioni che servono da te

| Quando serve | Domanda | Proposta |
|---|---|---|
| B3 | Dove va la radura nella sequenza? | dopo il fienile |
| B4 | Dove si rinasce prima della liberazione? | uscita delle celle |
| C | Qual è la "terza missione"? | il fienile |
| C5 | La singolarità resta? | sì, con oggetti solo temporanei |
| D1 | Tentativi medi per boss? | 3–6 |
| D2 | Va bene l'idea dei lucchetti temporali? | sì, partendo da due |

Se non rispondi, per B procedo con le proposte.
