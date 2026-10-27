#!/usr/bin/env python3
"""Generate the 90 ElephantCoding mission files from the didactic catalogue
plus compact, executable gameplay specifications.

The catalogue is the user's original production brief (data/missions/source_catalog.json).
This script adds: grids, spawn, routes, entities, executable reference programs,
three graded hints and two automatic tests per mission.

Run:  python3 tools/content/generate_missions.py
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data"
MISSIONS = DATA / "missions"
WORLDS = DATA / "worlds"

HEADINGS = {"N": 0, "E": 1, "S": 2, "W": 3}
DELTA = {0: (0, 1), 1: (1, 0), 2: (0, -1), 3: (-1, 0)}

WORLD_DEFS = {
    "savana": {
        "code": "INF", "title": "Savana delle Impronte", "age": "4-6 anni",
        "language": "Pittogrammi e direzioni", "editor": "icons",
        "description": "Impronte, acacie e tamburi: i primi passi del pensiero computazionale.",
        "theme": {"sky": "#f7c873", "ground": "#c9a227", "accent": "#e76f51", "prop": "acacia"},
        "lab": "Pista delle frecce",
    },
    "giardino": {
        "code": "P1", "title": "Giardino delle Frecce", "age": "6-7 anni",
        "language": "Sequenze iconiche", "editor": "icons",
        "description": "Siepi, serre e lanterne da raggiungere con sequenze ordinate.",
        "theme": {"sky": "#9bdeac", "ground": "#6bbf59", "accent": "#f4a261", "prop": "tree"},
        "lab": "Pista delle frecce",
    },
    "officina": {
        "code": "P2", "title": "Officina dei Fili", "age": "7-8 anni",
        "language": "Stringhe analogiche e perle", "editor": "beads",
        "description": "Fili, perle e mollette: si programma infilando istruzioni.",
        "theme": {"sky": "#c7b9ff", "ground": "#8d7bd6", "accent": "#ffb703", "prop": "gear"},
        "lab": "Atelier delle stringhe",
    },
    "borgo": {
        "code": "P3", "title": "Borgo dei Comandi", "age": "8-9 anni",
        "language": "Testo italiano, x2/x3, RIPETI", "editor": "text",
        "description": "Il primo linguaggio scritto: frasi comando chiare e verificabili.",
        "theme": {"sky": "#a8dadc", "ground": "#588157", "accent": "#e76f51", "prop": "house"},
        "lab": "Pista delle frecce",
    },
    "isola": {
        "code": "P4", "title": "Isola Cartesiana", "age": "9-10 anni",
        "language": "Coordinate e piano XY", "editor": "coordinates",
        "description": "Un'isola a quadretti dove ogni punto ha un nome: (x, y).",
        "theme": {"sky": "#90e0ef", "ground": "#00b4d8", "accent": "#ffb703", "prop": "palm"},
        "lab": "Museo delle coordinate",
    },
    "centro": {
        "code": "P5", "title": "Centro di Ricerca", "age": "10-11 anni",
        "language": "Variabili, SE, FINCHÉ", "editor": "pseudocode",
        "description": "Sensori, provette e quattro quadranti: le decisioni entrano nel codice.",
        "theme": {"sky": "#cdb4db", "ground": "#6d597a", "accent": "#ffafcc", "prop": "antenna"},
        "lab": "Serra dei dati",
    },
    "cittadella": {
        "code": "S1", "title": "Cittadella delle Funzioni", "age": "11-12 anni",
        "language": "Funzioni, parametri, booleani", "editor": "structured",
        "description": "Procedure riutilizzabili per far funzionare una cittadella modulare.",
        "theme": {"sky": "#bde0fe", "ground": "#457b9d", "accent": "#ffd166", "prop": "tower"},
        "lab": "Officina dei robot",
    },
    "arcipelago": {
        "code": "S2", "title": "Arcipelago degli Algoritmi", "age": "12-13 anni",
        "language": "Liste, matrici, dati", "editor": "data",
        "description": "Isole, rotte e magazzini: gli algoritmi lavorano sui dati.",
        "theme": {"sky": "#a8dadc", "ground": "#1d3557", "accent": "#f1faee", "prop": "boat"},
        "lab": "Porto delle strategie",
    },
    "metropoli": {
        "code": "S3", "title": "Metropoli dei Sistemi", "age": "13-14 anni",
        "language": "Stati, eventi, grafi", "editor": "systems",
        "description": "Una città di sistemi interconnessi: progettare, testare, spiegare.",
        "theme": {"sky": "#22223b", "ground": "#4a4e69", "accent": "#f2e9e4", "prop": "skyscraper"},
        "lab": "Sala dei sistemi",
    },
}

ENTITY_ACTIONS = {
    "RACCOGLI": ("collect", "Oggetto"),
    "PRENDI": ("collect", "Materiale"),
    "TOCCA": ("activate", "Meccanismo"),
    "ATTIVA": ("activate", "Dispositivo"),
    "APRI": ("activate", "Cancello"),
    "ACCENDI": ("activate", "Lanterna"),
    "SUONA": ("activate", "Campanello"),
    "DEPOSITA": ("target", "Deposito"),
    "LASCIA": ("target", "Consegna"),
    "FOTO": ("photo", "Reperto"),
    "SCANSIONA": ("photo", "Stazione"),
}

EVENT_ACTIONS = {"SALUTA", "PAUSA"}


def key(cell):
    return f"{cell[0]},{cell[1]}"


def entity_for(mid, action, cell, label=None):
    kind, default_label = ENTITY_ACTIONS[action]
    return {
        "id": f"{mid.lower()}-{kind}-{cell[0]}_{cell[1]}",
        "kind": kind,
        "cell": list(cell),
        "label": label or default_label,
        "glyph": {"collect": "*", "activate": "!", "target": "v", "photo": "o"}[kind],
        "required": True,
    }


def relative_program(route, actions, spawn, heading):
    """Generate an executable relative program (icons/beads/text)."""
    pos = list(spawn)
    h = HEADINGS[heading]
    lines = []
    for act in actions.get(key(pos), []):
        lines.append(act)
    for nxt in route:
        dx = nxt[0] - pos[0]
        dy = nxt[1] - pos[1]
        if dx and dy:
            raise ValueError(f"route segment not orthogonal: {pos} -> {nxt}")
        if dx > 0:
            want = HEADINGS["E"]
        elif dx < 0:
            want = HEADINGS["W"]
        elif dy > 0:
            want = HEADINGS["N"]
        else:
            want = HEADINGS["S"]
        turn = (want - h) % 4
        if turn == 1:
            lines.append("DESTRA")
        elif turn == 2:
            lines.append("DESTRA")
            lines.append("DESTRA")
        elif turn == 3:
            lines.append("SINISTRA")
        dist = abs(dx) + abs(dy)
        lines.append(f"AVANTI {dist}")
        h = want
        pos = list(nxt)
        for act in actions.get(key(pos), []):
            lines.append(act)
    return "\n".join(lines)


def coordinate_program(route, actions, spawn):
    pos = list(spawn)
    lines = []
    for act in actions.get(key(pos), []):
        lines.append(act)
    for nxt in route:
        lines.append(f"VAI A ({nxt[0]},{nxt[1]})")
        pos = list(nxt)
        for act in actions.get(key(pos), []):
            lines.append(act)
    return "\n".join(lines)


def make_hints(mid, title, route, action_cells, program, editor):
    if route:
        target = route[-1]
        if editor == "coordinates":
            h1 = f"Guarda la destinazione: si trova in ({target[0]}, {target[1]}). Ricorda che si scrive prima la X, poi la Y."
            h2 = "Esegui un passo alla volta e confronta la posizione nell'HUD con la destinazione."
            h3 = "Prova a costruire il percorso con una sequenza di VAI A, fermandoti sui punti intermedi."
        else:
            h1 = "Osserva la meta e la direzione in cui guarda Nilo: AVANTI è sempre rispetto al suo muso."
            h2 = "Ripeti il percorso con il passo-passo e cerca la prima istruzione in cui la traccia si allontana dalla meta."
            h3 = "Scomponi il percorso: prima raggiungi la prima svolta, poi conta le caselle e completa la sequenza."
    else:
        h1 = "Leggi l'obiettivo matematico e individua quali dati hai già nella scena."
        h2 = "Controlla una variabile alla volta: esegui, osserva il pannello e correggi la prima differenza."
        h3 = "Scrivi prima il caso più semplice, verificalo, poi aggiungi condizioni e cicli."
    return [
        {"level": 1, "text": h1},
        {"level": 2, "text": h2},
        {"level": 3, "text": h3},
    ]


def build(spec, catalog, world):
    mid = spec["id"]
    cat = catalog[mid]
    editor = spec.get("editor", world["editor"])
    grid = spec.get("grid", {"min_x": 0, "min_y": 0, "max_x": world.get("max_x", 9), "max_y": world.get("max_y", 7)})
    spawn = spec.get("spawn", [0, 0])
    heading = spec.get("heading", "E")
    route = [list(c) for c in spec.get("route", [])]
    raw_actions = spec.get("actions", {})
    actions = {k: (v if isinstance(v, list) else [v]) for k, v in raw_actions.items()}

    entities = []
    for k, acts in actions.items():
        x, y = [int(v) for v in k.split(",")]
        for act in acts:
            if act in ENTITY_ACTIONS:
                entities.append(entity_for(mid, act, [x, y], spec.get("entity_label")))
    entities.extend(spec.get("entities", []))

    if spec.get("program"):
        reference = spec["program"]
    elif editor == "coordinates":
        reference = coordinate_program(route, actions, spawn)
    else:
        reference = relative_program(route, actions, spawn, heading)

    goal = {}
    if route:
        goal["reach"] = route[-1]
    collected = [e["id"] for e in entities if e.get("required") and e["kind"] == "collect"]
    activated = [e["id"] for e in entities if e.get("required") and e["kind"] in ("activate", "target")]
    photos = [e["id"] for e in entities if e.get("required") and e["kind"] == "photo"]
    if collected:
        goal["collect_all"] = collected
    if activated:
        goal["activate_all"] = activated
    if photos:
        goal["photo_all"] = photos
    if spec.get("ordered_visits"):
        goal["visit_order"] = route
    if spec.get("trace_closed"):
        goal["trace_closed"] = True
    event_counts = {}
    for acts in actions.values():
        for act in acts:
            if act in EVENT_ACTIONS or act in ("SUONA", "ATTRAVERSA", "LASCIA", "SCANSIONA", "FOTO", "VERSA"):
                key_name = act.lower()
                event_counts[key_name] = event_counts.get(key_name, 0) + 1
    for k, v in spec.get("event_counts", {}).items():
        event_counts[k] = v
    if event_counts:
        goal["event_counts"] = event_counts
    if spec.get("vars"):
        goal["vars"] = spec["vars"]
    if spec.get("min_vars"):
        goal["min_vars"] = spec["min_vars"]
    goal.update(spec.get("goal_extra", {}))

    wrong = spec.get("wrong", "DESTRA")
    tests = [
        {"name": "reference_succeeds", "program": reference, "expect_success": True},
        {"name": "incomplete_fails", "program": wrong, "expect_success": False},
    ]
    for t in spec.get("tests", []):
        tests.append(t)

    hints = spec.get("hints") or make_hints(mid, cat["title"], route, list(actions), reference, editor)
    mission = {
        "schema_version": 1,
        "id": mid,
        "world": world["id"],
        "school_level": world["code"],
        "age_hint": world["age"],
        "title": cat["title"],
        "editor": editor,
        "narrative": cat["scene"],
        "coding_goal": cat["coding_goal"],
        "math_objective": cat["math_objective"],
        "success_text": cat["success_text"],
        "extension": cat["extension"],
        "design_reference": cat["design_reference"],
        "grid": grid,
        "spawn": {"cell": spawn, "heading": heading},
        "obstacles": spec.get("obstacles", []),
        "entities": entities,
        "initial_vars": spec.get("initial_vars", {}),
        "sensors": spec.get("sensors", {}),
        "timers": spec.get("timers", []),
        "allowed_ops": spec.get("allowed_ops", []),
        "reference_program": reference,
        "starter_program": spec.get("starter_program", ""),
        "goal": goal,
        "hints": hints,
        "tests": tests,
        "optional_extensions": [cat["extension"]],
        "accessibility_notes": "Comandi grandi, nessun timer obbligatorio, replay passo-passo, sottotitoli e narrazione facoltativa.",
        "completion_badges": spec.get("badges", ["missione_completata"]),
        "estimated_minutes": spec.get("minutes", 10),
        "tags": spec.get("tags", [world["code"].lower(), editor]),
        "narration_line": spec.get("narration", f"{cat['title']}. {cat['scene']}"),
        "scale_m": spec.get("scale_m", 1),
        "scene_theme": world["theme"],
    }
    if spec.get("max_steps"):
        mission["goal"]["max_steps_for_badge"] = spec["max_steps"]
    return mission


# ---------------------------------------------------------------------------
# Mission gameplay specifications
# ---------------------------------------------------------------------------

SPECS = []


def add(**kw):
    SPECS.append(kw)


# --- INFANZIA --------------------------------------------------------------
add(id="INF-01", world="savana", route=[[1, 0]], entities=[{"id": "inf01-target", "kind": "target", "cell": [1, 0], "label": "Farfalla", "glyph": "~"}], target_note="farfalla")
add(id="INF-02", world="savana", route=[[1, 0], [2, 0]], entities=[{"id": "inf02-target", "kind": "target", "cell": [2, 0], "label": "Albero", "glyph": "T"}])
add(id="INF-03", world="savana", heading="N", route=[[0, 1], [1, 1]], entities=[{"id": "inf03-target", "kind": "target", "cell": [1, 1], "label": "Acacia", "glyph": "T"}])
add(id="INF-04", world="savana", route=[[0, 1], [0, 2]], actions={"0,2": "TOCCA"}, entity_label="Tamburo")
add(id="INF-05", world="savana", route=[[1, 0], [2, 0]], entities=[{"id": "inf05-target", "kind": "target", "cell": [2, 0], "label": "Isola", "glyph": "O"}], obstacles=[[1, 1], [2, 1], [3, 1]])
add(id="INF-06", world="savana", route=[[1, 0], [2, 0], [3, 0]], actions={"1,0": "RACCOGLI", "2,0": "RACCOGLI", "3,0": "RACCOGLI"}, entity_label="Fiore")
add(id="INF-07", world="savana", route=[[1, 0], [2, 0], [3, 0]], program="AVANTI 1\nPAUSA\nAVANTI 1\nPAUSA\nAVANTI 1", goal_extra={"reach": [3, 0], "event_counts": {"pausa": 2}})
add(id="INF-08", world="savana", spawn=[1, 0], route=[[1, 1]], actions={"1,1": "RACCOGLI"}, entity_label="Lucciola")
add(id="INF-09", world="savana", route=[[1, 0], [2, 0], [3, 0]], actions={"1,0": "TOCCA", "2,0": "TOCCA", "3,0": "TOCCA"}, entity_label="Pietra numerata")
add(id="INF-10", world="savana", heading="N", route=[[0, 1], [1, 1], [1, 2]], actions={"1,2": "SUONA"}, entity_label="Campanello")

# --- PRIMARIA 1 ------------------------------------------------------------
add(id="P1-01", world="giardino", route=[[1, 0], [2, 0], [3, 0], [4, 0]], entities=[{"id": "p101-target", "kind": "target", "cell": [4, 0], "label": "Serra", "glyph": "H"}])
add(id="P1-02", world="giardino", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0]], entities=[{"id": "p102-target", "kind": "target", "cell": [5, 0], "label": "Riva", "glyph": "~"}])
add(id="P1-03", world="giardino", heading="N", route=[[1, 0]], actions={"1,0": "RACCOGLI"}, entity_label="Insegna")
add(id="P1-04", world="giardino", route=[[1, 0], [1, 1]], actions={"1,0": "PRENDI", "1,1": "DEPOSITA"}, entity_label="Semi")
add(id="P1-05", world="giardino", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0], [7, 0], [8, 0]], entities=[{"id": "p105-target", "kind": "target", "cell": [8, 0], "label": "Traguardo", "glyph": "F"}])
add(id="P1-06", world="giardino", spawn=[0, 2], heading="N", route=[[0, 3], [1, 3], [1, 2]], entities=[{"id": "p106-target", "kind": "target", "cell": [1, 2], "label": "Fontana", "glyph": "O"}])
add(id="P1-07", world="giardino", route=[[1, 0], [2, 0], [3, 0]], actions={"1,0": "TOCCA", "2,0": "TOCCA", "3,0": "TOCCA"}, entity_label="Piastrella")
add(id="P1-08", world="giardino", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0]], actions={"5,0": "APRI"}, entities=[{"id": "p108-target", "kind": "target", "cell": [5, 0], "label": "Porta 9", "glyph": "9"}], obstacles=[[4, 1], [5, 1]], entity_label="Porta")
add(id="P1-09", world="giardino", route=[[1, 0], [1, 1], [2, 1], [2, 2]], entities=[{"id": "p109-target", "kind": "target", "cell": [2, 2], "label": "Lanterna", "glyph": "L"}], starter_program="AVANTI 1\nDESTRA\nAVANTI 2\nSINISTRA\nAVANTI 1", wrong="AVANTI 1\nDESTRA\nAVANTI 2")
add(id="P1-10", world="giardino", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0]], actions={"2,0": "ACCENDI", "5,0": "ACCENDI"}, entities=[{"id": "p110-target", "kind": "target", "cell": [6, 0], "label": "Piazza", "glyph": "P"}], entity_label="Lanterna")

# --- PRIMARIA 2 ------------------------------------------------------------
add(id="P2-01", world="officina", route=[[1, 0], [2, 0], [3, 0], [4, 0]], entities=[{"id": "p201-target", "kind": "target", "cell": [4, 0], "label": "Banco", "glyph": "B"}])
add(id="P2-02", world="officina", heading="N", route=[[0, 1], [1, 1], [2, 1]], entities=[{"id": "p202-target", "kind": "target", "cell": [2, 1], "label": "Pista a L", "glyph": "L"}])
add(id="P2-03", world="officina", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0]], entities=[{"id": "p203-target", "kind": "target", "cell": [5, 0], "label": "Piattaforma", "glyph": "P"}], obstacles=[[0, 1], [1, 1], [2, 1]])
add(id="P2-04", world="officina", spawn=[0, 2], heading="N", route=[[0, 3], [1, 3], [1, 2]], entities=[{"id": "p204-target", "kind": "target", "cell": [1, 2], "label": "Filo", "glyph": "F"}])
add(id="P2-05", world="officina", heading="N", route=[[0, 1], [1, 1], [2, 1]], entities=[{"id": "p205-target", "kind": "target", "cell": [2, 1], "label": "Meta speculare", "glyph": "S"}])
add(id="P2-06", world="officina", route=[[1, 0], [2, 0]], entities=[{"id": "p206-target", "kind": "target", "cell": [2, 0], "label": "Cassa", "glyph": "C"}], obstacles=[[3, 0], [3, 1], [4, 0]])
add(id="P2-07", world="officina", grid={"min_x": 0, "min_y": 0, "max_x": 12, "max_y": 5}, route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0], [7, 0], [8, 0], [9, 0], [10, 0]], entities=[{"id": "p207-target", "kind": "target", "cell": [10, 0], "label": "Sensore", "glyph": "S"}])
add(id="P2-08", world="officina", route=[[1, 0], [1, 1], [2, 1], [2, 2]], entities=[{"id": "p208-target", "kind": "target", "cell": [2, 2], "label": "Meta", "glyph": "M"}], starter_program="AVANTI 1\nSINISTRA\nAVANTI 1\nSINISTRA\nAVANTI 1")
add(id="P2-09", world="officina", route=[[1, 0], [1, 1]], actions={"1,0": "TOCCA", "1,1": "SUONA"}, entity_label="Pozzo")
add(id="P2-10", world="officina", route=[[1, 0], [2, 0], [3, 0]], actions={"3,0": "TOCCA"}, entity_label="Fontana")

# --- PRIMARIA 3 ------------------------------------------------------------
add(id="P3-01", world="borgo", route=[[1, 0], [2, 0], [3, 0]], entities=[{"id": "p301-target", "kind": "target", "cell": [3, 0], "label": "Fontana", "glyph": "F"}])
add(id="P3-02", world="borgo", heading="N", route=[[1, 0], [2, 0]], entities=[{"id": "p302-target", "kind": "target", "cell": [2, 0], "label": "Incrocio", "glyph": "I"}])
add(id="P3-03", world="borgo", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0]], entities=[{"id": "p303-target", "kind": "target", "cell": [6, 0], "label": "Corridoio", "glyph": "C"}], program="AVANTI 2 x3")
add(id="P3-04", world="borgo", heading="N", route=[[0, 2], [2, 2], [2, 0]], program="RIPETI x3 { AVANTI 2; DESTRA }", entities=[{"id": "p304-target", "kind": "target", "cell": [2, 0], "label": "Guardiano", "glyph": "G"}])
add(id="P3-05", world="borgo", route=[[2, 0], [4, 0], [6, 0]], actions={"2,0": "FOTO", "4,0": "FOTO", "6,0": "FOTO"}, program="RIPETI x3 { AVANTI 2; FOTO }", entity_label="Torre")
add(id="P3-06", world="borgo", heading="N", route=[], program="RIPETI x4 { AVANTI 3; DESTRA }", goal_extra={"reach": [0, 0], "trace_closed": True}, entities=[{"id": "p306-target", "kind": "target", "cell": [0, 0], "label": "Mulino", "glyph": "M"}], wrong="AVANTI 3")
add(id="P3-07", world="borgo", route=[[1, 0], [2, 0], [3, 0], [4, 0]], program="AVANTI 1 x4", entities=[{"id": "p307-target", "kind": "target", "cell": [4, 0], "label": "Corridoio", "glyph": "C"}])
add(id="P3-08", world="borgo", route=[[1, 0], [2, 0], [3, 0], [4, 0], [5, 0]], program="AVANTI (2+3)", entities=[{"id": "p308-target", "kind": "target", "cell": [5, 0], "label": "Mercato", "glyph": "M"}])
add(id="P3-09", world="borgo", heading="N", route=[[0, 2], [2, 2]], program="RIPETI x2 { AVANTI 2; DESTRA }", entities=[{"id": "p309-target", "kind": "target", "cell": [2, 2], "label": "Cantiere", "glyph": "C"}], starter_program="RIPETI x2 { AVANTI 2 DESTRA", wrong="RIPETI x2 { AVANTI 2 DESTRA", tests=[{"name": "syntax_error_fails", "program": "RIPETI x2 { AVANTI 2 DESTRA", "expect_success": False}])
add(id="P3-10", world="borgo", heading="N", route=[[2, 2]], actions={"2,2": "TOCCA"}, program="RIPETI x3 { AVANTI 2; DESTRA; SALUTA }\nDESTRA\nAVANTI 2\nTOCCA", entity_label="Porta")

# --- PRIMARIA 4 ------------------------------------------------------------
add(id="P4-01", world="isola", grid={"min_x": 0, "min_y": 0, "max_x": 7, "max_y": 7}, route=[[2, 1]], program="VAI A (2,1)", entities=[{"id": "p401-target", "kind": "target", "cell": [2, 1], "label": "Bandiera", "glyph": "B"}])
add(id="P4-02", world="isola", route=[[3, 0], [3, 2]], program="MUOVI X +3\nMUOVI Y +2", entities=[{"id": "p402-target", "kind": "target", "cell": [3, 2], "label": "Raccolta", "glyph": "R"}])
add(id="P4-03", world="isola", route=[[4, 0], [4, 3]], program="MUOVI X +4\nMUOVI Y +3", entities=[{"id": "p403-target", "kind": "target", "cell": [4, 3], "label": "Punto", "glyph": "P"}])
add(id="P4-04", world="isola", route=[[1, 1], [5, 1], [5, 3], [1, 3]], ordered_visits=True, entities=[{"id": "p404-target", "kind": "target", "cell": [1, 3], "label": "Vertice", "glyph": "V"}])
add(id="P4-05", world="isola", route=[], program="MUOVI X +4\nMUOVI Y +2\nMUOVI X -4\nMUOVI Y -2", goal_extra={"reach": [0, 0], "trace_closed": True}, entities=[{"id": "p405-target", "kind": "target", "cell": [0, 0], "label": "Recinto", "glyph": "R"}], wrong="MUOVI X +4")
add(id="P4-06", world="isola", route=[[2, 4], [4, 2]], ordered_visits=True, entities=[{"id": "p406-target", "kind": "target", "cell": [4, 2], "label": "Giardino", "glyph": "G"}])
add(id="P4-07", world="isola", route=[[1, 1], [3, 1], [3, 4], [5, 4]], ordered_visits=True, entities=[{"id": "p407-target", "kind": "target", "cell": [5, 4], "label": "Fermata D", "glyph": "D"}])
add(id="P4-08", world="isola", route=[[1, 0], [1, 1], [3, 1], [3, 0], [4, 0]], obstacles=[[2, 0]], entities=[{"id": "p408-target", "kind": "target", "cell": [4, 0], "label": "Uscita", "glyph": "U"}])
add(id="P4-09", world="isola", route=[[3, 0], [3, 2]], program="MUOVI X +3\nMUOVI Y +2", scale_m=2, entities=[{"id": "p409-target", "kind": "target", "cell": [3, 2], "label": "Serra", "glyph": "S"}])
add(id="P4-10", world="isola", spawn=[1, 1], route=[[1, 1], [5, 1], [4, 4], [2, 4]], program="TRACCIA (1,1)\nTRACCIA (5,1)\nTRACCIA (4,4)\nTRACCIA (2,4)\nCHIUDI", goal_extra={"reach": [1, 1], "trace_closed": True}, entities=[{"id": "p410-target", "kind": "target", "cell": [1, 1], "label": "Museo", "glyph": "M"}], wrong="TRACCIA (1,1)\nTRACCIA (5,1)")

# --- PRIMARIA 5 ------------------------------------------------------------
P5_GRID = {"min_x": -6, "min_y": -6, "max_x": 6, "max_y": 6}
add(id="P5-01", world="centro", grid=P5_GRID, route=[[-2, 3], [3, -1]], program="VAI A (-2,3)\nVAI A (3,-1)", ordered_visits=True, entities=[{"id": "p501-target", "kind": "target", "cell": [3, -1], "label": "Sensore", "glyph": "S"}])
add(id="P5-02", world="centro", grid=P5_GRID, spawn=[4, 1], route=[], program="MUOVI X -3\nMUOVI Y +2", goal_extra={"reach": [1, 3]}, entities=[{"id": "p502-target", "kind": "target", "cell": [1, 3], "label": "Vento", "glyph": "V"}])
add(id="P5-03", world="centro", grid=P5_GRID, route=[[1, 0], [2, 0], [3, 0], [4, 0]], actions={"1,0": "RACCOGLI", "2,0": "RACCOGLI", "3,0": "RACCOGLI", "4,0": "RACCOGLI"}, program="IMPOSTA casse = 0\nRIPETI x4 { AVANTI 1; RACCOGLI; casse = casse + 1 }", vars={"casse": 4}, entity_label="Cassa")
add(id="P5-04", world="centro", grid=P5_GRID, initial_vars={"acqua": 3}, sensors={"acqua": 3}, program="SE acqua >= 2 ALLORA { APRI } ALTRIMENTI { ASPETTA }", entities=[{"id": "p504-gate", "kind": "activate", "cell": [0, 0], "label": "Porta", "glyph": "P", "required": True}], goal_extra={"activate_all": ["p504-gate"]}, wrong="ASPETTA")
add(id="P5-05", world="centro", grid=P5_GRID, initial_vars={"batteria": 21}, sensors={"batteria": 21}, route=[], program="SE batteria > 20 ALLORA { AVANTI 1 } ALTRIMENTI { RICARICA }", goal_extra={"reach": [1, 0]}, entities=[{"id": "p505-target", "kind": "target", "cell": [1, 0], "label": "Ponte", "glyph": "P"}])
add(id="P5-06", world="centro", grid=P5_GRID, initial_vars={"acqua": 2}, sensors={"acqua": 2}, program="FINCHÉ acqua < 5 { VERSA 1 }", vars={"acqua": 5}, goal_extra={"event_counts": {"versa": 3}}, wrong="VERSA 1")
add(id="P5-07", world="centro", grid=P5_GRID, initial_vars={"elenco_punti": [[-1, 2], [2, 2], [2, -2], [-1, -2]]}, route=[[-1, 2], [2, 2], [2, -2], [-1, -2]], program="PER OGNI punto IN elenco_punti { VAI A punto; FOTO }", actions={"-1,2": "FOTO", "2,2": "FOTO", "2,-2": "FOTO", "-1,-2": "FOTO"}, ordered_visits=True, entity_label="Reperto")
add(id="P5-08", world="centro", grid=P5_GRID, route=[[1, 0], [2, 0], [3, 0]], actions={"1,0": "SCANSIONA", "2,0": "SCANSIONA", "3,0": "SCANSIONA"}, program="PROCEDURA controlla { AVANTI 1; SCANSIONA }\ncontrolla() x3", entity_label="Stazione")
add(id="P5-09", world="centro", grid=P5_GRID, route=[], program="IMPOSTA x = 0\nIMPOSTA y = 0\nRIPETI x3 { x = x + 1 }\nRIPETI x2 { y = y + 1 }\nVAI A (x,y)", vars={"x": 3, "y": 2}, goal_extra={"reach": [3, 2]}, starter_program="IMPOSTA x = 0\nIMPOSTA y = 0\nRIPETI x3 { x = x + 2 }\nRIPETI x2 { y = y + 2 }\nVAI A (x,y)", wrong="VAI A (4,2)", entities=[{"id": "p509-target", "kind": "target", "cell": [3, 2], "label": "Sensore", "glyph": "S"}])
add(id="P5-10", world="centro", grid=P5_GRID, route=[[1, 1], [-1, 1], [-1, -1]], actions={"1,1": "RACCOGLI", "-1,1": "RACCOGLI", "-1,-1": "RACCOGLI"}, program="IMPOSTA consegne = 0\nPROCEDURA consegna { RACCOGLI; consegne = consegne + 1 }\nVAI A (1,1); consegna()\nVAI A (-1,1); consegna()\nVAI A (-1,-1); consegna()", vars={"consegne": 3}, entity_label="Provvista")

# --- SECONDARIA 1 ----------------------------------------------------------
add(id="S1-01", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, route=[[2, 0], [4, 0], [6, 0]], actions={"2,0": "ATTIVA", "4,0": "ATTIVA", "6,0": "ATTIVA"}, program="PROCEDURA apri(x) { VAI A (x,0); ATTIVA }\napri(2)\napri(4)\napri(6)", entity_label="Cancello")
add(id="S1-02", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"badge_valido": True, "batteria": 40}, sensors={"batteria": 40}, program="SE badge_valido E batteria >= 30 ALLORA { APRI } ALTRIMENTI { SEGNALA }", entities=[{"id": "s102-gate", "kind": "activate", "cell": [0, 0], "label": "Porta", "glyph": "P", "required": True}], goal_extra={"activate_all": ["s102-gate"]}, wrong="SE badge_valido O batteria >= 30 ALLORA { SEGNALA } ALTRIMENTI { APRI }")
add(id="S1-03", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, heading="N", route=[], program="PROCEDURA sali(n) { RIPETI n VOLTE { AVANTI 1 } }\nsali(2) x4", goal_extra={"reach": [0, 8]}, entities=[{"id": "s103-target", "kind": "target", "cell": [0, 8], "label": "Torre", "glyph": "T"}])
add(id="S1-04", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, sensors={"cancello_aperto": False}, timers=[{"var": "cancello_aperto", "every": 1, "mode": "toggle"}], program="FINCHÉ NON cancello_aperto { ASPETTA 1 }\nATTRAVERSA", goal_extra={"event_counts": {"attraversa": 1}}, wrong="DESTRA")
add(id="S1-05", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="FUNZIONE area(b, h) { RITORNA b * h }\nIMPOSTA a1 = area(2,3)\nIMPOSTA a2 = area(4,5)\nIMPOSTA a3 = area(6,2)", vars={"a1": 6, "a2": 20, "a3": 12}, wrong="IMPOSTA a1 = 6")
add(id="S1-06", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"x1": 2, "y1": 3, "x2": -4, "y2": 2, "x3": -1, "y3": -5, "x4": 6, "y4": -1}, program="""IMPOSTA q1 = 0
IMPOSTA q2 = 0
IMPOSTA q3 = 0
IMPOSTA q4 = 0
SE x1 > 0 E y1 > 0 ALLORA { q1 = 1 }
SE x2 < 0 E y2 > 0 ALLORA { q2 = 2 }
SE x3 < 0 E y3 < 0 ALLORA { q3 = 3 }
SE x4 > 0 E y4 < 0 ALLORA { q4 = 4 }""", vars={"q1": 1, "q2": 2, "q3": 3, "q4": 4}, wrong="IMPOSTA q1 = 1")
add(id="S1-07", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"misure": [-1, 101, 50]}, program="""IMPOSTA validi = 0
IMPOSTA errori = 0
PER OGNI v IN misure { SE v >= 0 E v <= 100 ALLORA { validi = validi + 1 } ALTRIMENTI { errori = errori + 1 } }""", vars={"validi": 1, "errori": 2}, wrong="IMPOSTA validi = 3")
add(id="S1-08", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 4, "max_y": 4}, entities=[{"id": f"s108-{x}_{y}", "kind": "activate", "cell": [x, y], "label": "Cella", "glyph": "C"} for y in range(5) for x in range(5)], program="PER y DA 0 A 4 { PER x DA 0 A 4 { VAI A (x,y); ATTIVA } }", goal_extra={"activate_all": [f"s108-{x}_{y}" for y in range(5) for x in range(5)]}, wrong="VAI A (0,0)\nATTIVA")
add(id="S1-09", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="FUNZIONE distanzaX(a, b) { RITORNA ASS(b - a) }\nIMPOSTA d1 = distanzaX(-2,3)\nIMPOSTA d2 = distanzaX(0,0)\nIMPOSTA d3 = distanzaX(5,2)\nIMPOSTA d4 = distanzaX(-4,-1)\nIMPOSTA d5 = distanzaX(6,6)", vars={"d1": 5, "d2": 0, "d3": 3, "d4": 3, "d5": 0}, wrong="IMPOSTA d1 = 0")
add(id="S1-10", world="cittadella", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, entities=[{"id": f"s110-{x}_{y}", "kind": "activate", "cell": [x, y], "label": "Settore", "glyph": "S"} for x, y in [(1, 1), (5, 1), (5, 5), (1, 5)]], program="""IMPOSTA allarmi = 0
PROCEDURA visita(x, y) { VAI A (x,y); ATTIVA }
visita(1,1)
visita(5,1)
visita(5,5)
visita(1,5)""", goal_extra={"activate_all": [f"s110-{x}_{y}" for x, y in [(1, 1), (5, 1), (5, 5), (1, 5)]], "vars": {"allarmi": 0}}, wrong="visita(1,1)")

# --- SECONDARIA 2 ----------------------------------------------------------
add(id="S2-01", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"consegne": [[1, 1], [3, 1], [5, 1], [5, 3], [3, 3], [1, 3]]}, route=[[1, 1], [3, 1], [5, 1], [5, 3], [3, 3], [1, 3]], ordered_visits=True, program="PER OGNI punto IN consegne { VAI A punto; LASCIA }", actions={"1,1": "LASCIA", "3,1": "LASCIA", "5,1": "LASCIA", "5,3": "LASCIA", "3,3": "LASCIA", "1,3": "LASCIA"}, entity_label="Consegna")
add(id="S2-02", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"letture": [8, 10, 12, 9, 11]}, program="IMPOSTA somma = 0\nPER OGNI v IN letture { somma = somma + v }\nIMPOSTA media = somma / LUNGHEZZA(letture)", vars={"media": 10}, wrong="IMPOSTA media = 0")
add(id="S2-03", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"punti": [[1, 2], [3, 1], [4, 3]]}, program="IMPOSTA scalati = []\nPER OGNI p IN punti { AGGIUNGI(scalati, [p.x * 2, p.y * 2]) }", vars={"scalati": [[2, 4], [6, 2], [8, 6]]}, wrong="IMPOSTA scalati = []")
add(id="S2-04", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"lunghezze": [7, 4, 9, 3, 6]}, program="""IMPOSTA minimo = lunghezze[0]
IMPOSTA indice = 0
PER i DA 0 A 4 { SE lunghezze[i] < minimo ALLORA { minimo = lunghezze[i]; indice = i } }""", vars={"minimo": 3, "indice": 3}, wrong="IMPOSTA minimo = 7")
add(id="S2-05", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 5, "max_y": 5}, route=[[1, 0], [1, 1], [3, 1], [3, 2], [5, 2], [5, 4]], ordered_visits=True, obstacles=[[2, 0], [4, 1], [1, 3], [3, 3]], program="VAI A (1,0)\nVAI A (1,1)\nVAI A (3,1)\nVAI A (3,2)\nVAI A (5,2)\nVAI A (5,4)", entities=[{"id": "s205-target", "kind": "target", "cell": [5, 4], "label": "Meta", "glyph": "M"}], wrong="VAI A (5,0)")
add(id="S2-06", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"carica_percentuale": 60}, sensors={"carica_percentuale": 60}, program="SE carica_percentuale < 70 ALLORA { RICARICA } ALTRIMENTI { SEGNALA }", vars={"ricarica": True}, wrong="SE carica_percentuale < 70 ALLORA { SEGNALA } ALTRIMENTI { RICARICA }", tests=[{"name": "75_percent_no_recharge", "program": "SE carica_percentuale < 70 ALLORA { RICARICA } ALTRIMENTI { SEGNALA }", "expect_success": False, "override": {"initial_vars": {"carica_percentuale": 75}, "sensors": {"carica_percentuale": 75}}}])
add(id="S2-07", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"pesi": [5, 2, 4, 1, 3]}, program="""PER i DA 0 A 3 { PER j DA 0 A 3 { SE pesi[j] > pesi[j+1] ALLORA { SCAMBIA(pesi, j, j+1) } } }""", vars={"pesi": [1, 2, 3, 4, 5]}, wrong="IMPOSTA pesi = [5,2,4,1,3]")
add(id="S2-08", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"rotte": [["A", 8, 4], ["B", 6, 7], ["C", 9, 3]], "scelta": "C"}, program="""IMPOSTA scelta = "Nessuna"
IMPOSTA migliore = 999
PER OGNI r IN rotte { SE r[2] <= 5 E r[1] < migliore ALLORA { migliore = r[1]; scelta = r[0] } }""", vars={"scelta": "A", "migliore": 8}, wrong="IMPOSTA scelta = \"B\"")
add(id="S2-09", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"distanze": [4, 0, None, 6]}, program="""IMPOSTA somma = 0
IMPOSTA conteggio = 0
PER OGNI d IN distanze { SE d != NULLO ALLORA { somma = somma + d; conteggio = conteggio + 1 } }
IMPOSTA media = somma / conteggio""", vars={"media": 3.3333333, "conteggio": 3}, wrong="IMPOSTA media = 2.5")
add(id="S2-10", world="arcipelago", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"navi": [["N1", 3, 20], ["N2", 4, 25], ["N3", 2, 15]]}, program="""IMPOSTA consegne = 0
IMPOSTA energia = 0
PER OGNI n IN navi { consegne = consegne + n[1]; energia = energia + n[2] }
IMPOSTA test_ok = VERO""", vars={"consegne": 9, "energia": 60, "test_ok": True}, wrong="IMPOSTA consegne = 0")

# --- SECONDARIA 3 ----------------------------------------------------------
add(id="S3-01", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA stato = "CHIUSO"
SE stato == "CHIUSO" ALLORA { stato = "IN_MOVIMENTO" }
SE stato == "IN_MOVIMENTO" ALLORA { stato = "APERTO" }""", vars={"stato": "APERTO"}, wrong="IMPOSTA stato = \"CHIUSO\"")
add(id="S3-02", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA passaggi = 0
IMPOSTA collisioni = 0
PER t DA 1 A 10 { SE t % 2 == 0 ALLORA { passaggi = passaggi + 1 } ALTRIMENTI { collisioni = collisioni + 0 } }""", vars={"passaggi": 5, "collisioni": 0}, wrong="IMPOSTA passaggi = 0")
add(id="S3-03", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"archi": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [0, 6], [2, 6]]}, program="""IMPOSTA nodi = 7
IMPOSTA numero_archi = LUNGHEZZA(archi)
IMPOSTA somma_gradi = 0
PER OGNI a IN archi { somma_gradi = somma_gradi + 2 }""", vars={"nodi": 7, "numero_archi": 8, "somma_gradi": 16}, wrong="IMPOSTA nodi = 8")
add(id="S3-04", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 6, "max_y": 6}, route=[[1, 0], [1, 1], [2, 1], [2, 2], [4, 2], [4, 4]], ordered_visits=True, obstacles=[[2, 0], [3, 1], [1, 3]], program="VAI A (1,0)\nVAI A (1,1)\nVAI A (2,1)\nVAI A (2,2)\nVAI A (4,2)\nVAI A (4,4)", entities=[{"id": "s304-target", "kind": "target", "cell": [4, 4], "label": "Uscita", "glyph": "U"}], wrong="VAI A (6,0)")
add(id="S3-05", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, initial_vars={"oggetti": [["A", 5, 2, 4], ["B", 3, 1, 2], ["C", 2, 3, 5]]}, program="""IMPOSTA scelta = "Nessuno"
IMPOSTA migliore = -999
PER OGNI o IN oggetti { IMPOSTA punteggio = 2 * o[1] - o[2] - o[3]; SE punteggio > migliore ALLORA { migliore = punteggio; scelta = o[0] } }""", vars={"scelta": "A", "migliore": 4}, wrong="IMPOSTA scelta = \"B\"")
add(id="S3-06", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA consegne = 3
IMPOSTA collisioni = 0
IMPOSTA turni = 6""", vars={"consegne": 3, "collisioni": 0}, wrong="IMPOSTA collisioni = 1")
add(id="S3-07", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA nodi10 = 10 * 10
IMPOSTA nodi20 = 20 * 20
IMPOSTA nodi40 = 40 * 40""", vars={"nodi10": 100, "nodi20": 400, "nodi40": 1600}, wrong="IMPOSTA nodi10 = 10")
add(id="S3-08", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA test_superati = 0
RIPETI x8 { test_superati = test_superati + 1 }""", vars={"test_superati": 8}, wrong="IMPOSTA test_superati = 0")
add(id="S3-09", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA moduli = 3
IMPOSTA dipendenze_circolari = 0
IMPOSTA regressione_ok = VERO""", vars={"moduli": 3, "dipendenze_circolari": 0, "regressione_ok": True}, wrong="IMPOSTA moduli = 1")
add(id="S3-10", world="metropoli", grid={"min_x": 0, "min_y": 0, "max_x": 8, "max_y": 8}, program="""IMPOSTA consegne = 3
IMPOSTA collisioni = 0
IMPOSTA test_superati = 10
IMPOSTA energia = 12""", vars={"consegne": 3, "collisioni": 0, "test_superati": 10}, min_vars={"energia": 0}, wrong="IMPOSTA consegne = 2")


def main():
    catalog = json.loads((MISSIONS / "source_catalog.json").read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in SPECS}
    assert len(by_id) == 90, f"expected 90 specs, got {len(by_id)}"
    assert set(by_id) == set(catalog), (set(catalog) - set(by_id), set(by_id) - set(catalog))
    WORLDS.mkdir(parents=True, exist_ok=True)
    # write worlds
    for wid, w in WORLD_DEFS.items():
        info = dict(w)
        info["id"] = wid
        info["max_x"] = 9
        info["max_y"] = 7
        info["mission_ids"] = [m["id"] for m in SPECS if m["world"] == wid]
        (WORLDS / f"{wid}.json").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # clean generated missions (keep source_catalog.json)
    for p in MISSIONS.glob("*.*"):
        if p.name != "source_catalog.json":
            p.unlink()
    for spec in SPECS:
        world = WORLD_DEFS[spec["world"]]
        mission = build(spec, catalog, {**world, "id": spec["world"]})
        (MISSIONS / f"{mission['id']}.json").write_text(
            json.dumps(mission, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    print(f"generated {len(SPECS)} missions in {MISSIONS}")


if __name__ == "__main__":
    main()
