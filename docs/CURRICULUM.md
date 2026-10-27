# Curricolo

Il curricolo è organizzato in **nove mondi da dieci missioni**. Ogni mondo
introduce un linguaggio di programmazione e un nucleo matematico, e riusa le
competenze del mondo precedente. Le età sono indicative: l'insegnante può
sbloccare tutti i mondi dall'area docente.

## Progressione

| Ordine | Codice | Mondo | Età | Linguaggio | Nucleo matematico |
| --- | --- | --- | --- | --- | --- |
| 1 | INF | Savana delle Impronte | 4-6 | Pittogrammi e direzioni | Corrispondenza, lateralità, ordine, simmetria intuitiva |
| 2 | P1 | Giardino delle Frecce | 6-7 | Sequenze iconiche | Cardinalità, addizione come lunghezza, angoli, pattern |
| 3 | P2 | Officina dei Fili | 7-8 | Stringhe analogiche e perle | Lunghezza, confronto, raddoppio, decine, simmetria |
| 4 | P3 | Borgo dei Comandi | 8-9 | Testo italiano, `RIPETI` | Operazioni, parentesi, multipli, equivalenza, perimetro |
| 5 | P4 | Isola Cartesiana | 9-10 | Coordinate e piano XY | Coppie ordinate, traslazioni, perimetro, scala, poligoni |
| 6 | P5 | Centro di Ricerca | 10-11 | Variabili, `SE`, `FINCHÉ` | Numeri relativi, intervalli, successioni, tabelle |
| 7 | S1 | Cittadella delle Funzioni | 11-12 | Funzioni e parametri | Parametri, logica proposizionale, potenze, area, distanza |
| 8 | S2 | Arcipelago degli Algoritmi | 12-13 | Liste, matrici, dati | Indici, media, proporzioni, minimo, percentuali, grafi |
| 9 | S3 | Metropoli dei Sistemi | 13-14 | Stati, eventi, grafi | Grafi, ricerca in ampiezza, complessità, modellizzazione |

## Che cosa impara il giocatore

### INF — Savana delle Impronte
Comandi come pittogrammi, un passo per volta. L'obiettivo è la
**corrispondenza uno-a-uno** tra simbolo e azione, il lessico spaziale
(vicino/lontano, destra/sinistra) e la memoria di una breve sequenza. Le
missioni usano al massimo due o tre comandi.

### P1 — Giardino delle Frecce
Si compongono sequenze di icone per raggiungere una meta. La matematica entra
come **conteggio e misura della distanza**: «quattro passi» è una cardinalità e
una lunghezza; una svolta è un quarto di giro. Si incontrano i primi pattern.

### P2 — Officina dei Fili
Le istruzioni diventano una **stringa** di perle: si legge da sinistra a
destra, si confronta con un'altra stringa, si raggruppa. La molletta numerata
introduce l'idea di ripetizione di un gruppo (raddoppio, primi multipli) senza
ancora usare la parola `RIPETI`.

### P3 — Borgo dei Comandi
Prima sintassi testuale: `AVANTI 3`, `DESTRA`, `RIPETI x3 { … }`. Il focus è la
**struttura di un linguaggio** (parole, numeri, parentesi, punto e virgola) e la
matematica delle operazioni: addizione ripetuta, moltiplicazione, parentesi,
multipli, perimetro del quadrato.

### P4 — Isola Cartesiana
La griglia diventa un **piano cartesiano**: ogni cella ha una coppia ordinata.
Si lavora su traslazioni, percorsi ortogonali, vertici e lati dei poligoni,
perimetro e scala. `VAI A x y` rende esplicita la differenza tra «prima X, poi
Y» e il percorso effettivo.

### P5 — Centro di Ricerca
Si introducono **variabili, condizioni e cicli**: `IMPOSTA`, `SE … ALLORA`,
`FINCHÉ`. I problemi usano numeri relativi, quadranti, intervalli, successioni e
tabelle. La diagnostica mostra i valori delle variabili dopo ogni passo.

### S1 — Cittadella delle Funzioni
Le sequenze si incapsulano in **procedure e funzioni con parametri**. Si
esplorano booleani, tabelle di verità, potenze, area del rettangolo, intervalli
e distanza come valore assoluto. L'obiettivo è la generalizzazione: una
soluzione che funziona per molti ingressi.

### S2 — Arcipelago degli Algoritmi
Liste, indici a base zero, medie, minimi, percentuali e **dati mancanti**. Si
costruiscono grafi su griglia e si ottimizzano percorsi con vincoli. La
correttezza non basta più: contano anche la qualità del dato e l'efficienza.

### S3 — Metropoli dei Sistemi
Il programma diventa un **sistema**: macchine a stati, eventi con priorità,
grafi pesati, ricerca in ampiezza, scheduling e composizione di moduli. Si
ragiona su complessità e casi limite. L'ultima missione integra tutto.

## Struttura di una missione

Ogni missione contiene:

- `narrative` e `coding_goal`: contesto e concetto di programmazione;
- `math_objective`: il nucleo matematico;
- `goal`: la condizione verificabile (cella, raccolte, attivazioni, foto,
  variabili, ordine di visita, traccia chiusa, conteggio eventi);
- `reference_program` e almeno due `tests`: uno che deve riuscire, uno che deve
  fallire;
- tre `hints` progressivi: direzione, passo-passo, scomposizione;
- `success_text` ed `extension`: chiusura e proposta di approfondimento;
- `accessibility_notes`: adattamenti previsti.

## Valutazione

L'area insegnante riporta per ogni missione: stato, numero di tentativi, miglior
numero di passi e aiuti usati. Non esiste un voto automatico. Le evidenze
servono a discutere:

- **correttezza**: la missione è completata?
- **efficienza**: quanti passi rispetto alla soluzione di riferimento?
- **autonomia**: quanti aiuti sono stati necessari?
- **trasferimento**: l'estensione facoltativa è stata provata?

Le stelle nella schermata di successo dipendono dagli aiuti usati (3 stelle
senza aiuti, 2 con uno, 1 con due o più). Sono un incentivo, non una
valutazione.

## Adattamenti

- Attivare **Mondi sempre accessibili** per lavorare fuori sequenza.
- Attivare **Suggerisci la soluzione** per la dimostrazione alla lavagna.
- Attivare **Modalità classe** per testi più grandi, sottotitoli e controlli
  semplificati.
- Disattivare la voce e lasciare i sottotitoli in aule rumorose.
- Usare **Riduci animazioni** per l'esecuzione istantanea durante la discussione.
- Esportare il JSON del profilo per conservare le evidenze a fine periodo.

## Riferimenti

- Architettura tecnica: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Uso in classe: [`TEACHER_GUIDE.md`](TEACHER_GUIDE.md)
- Test e verifica: [`TESTING.md`](TESTING.md)
