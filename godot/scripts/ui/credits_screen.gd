extends AppScreen

## Credits, license and attribution. Deliberately explicit about what is
## original, what comes from Godot and what is not bundled.

const CREDITS_TEXT := """ELEPHANTCODING · v0.1.0
Un gioco educativo originale per imparare a programmare con Nilo.

CONTENUTI ORIGINALI
• Codice sorgente, motore di simulazione, parser del linguaggio italiano.
• Personaggio di Nilo, mondi, oggetti e diorami 3D: generati proceduralmente
  con primitive di Godot, nessun modello esterno.
• Testi delle missioni, obiettivi, aiuti e narrative: adattati per questo
  progetto a partire dal documento di progettazione fornito.
• Interfaccia, palette, icone SVG e suoni di interfaccia: originali.
Licenza: Creative Commons Attribution 4.0 International (CC BY 4.0).
Puoi condividere e adattare il materiale citando «ElephantCoding».

MOTORE
• Godot Engine 4.7.2 — licenza MIT.
  https://godotengine.org/license
• Il tema di default usa il font incluso nella distribuzione di Godot.
  Nessun file font aggiuntivo è stato incorporato in questo repository.

VOCE
• Il repository non include clip audio di voci di terze parti non verificate.
• La cartella assets/audio/voice/it/ è il punto di ingresso per un voice pack
  registrato o sintetizzato con licenza compatibile CC BY.
• Ogni clip deve essere elencata in data/locales/it/voice_manifest.json con
  autore, licenza, URL della fonte e attribuzione richiesta.
• In assenza di clip, l'app usa i sottotitoli e, se abilitata, la sintesi
  vocale italiana del sistema operativo. La voce del sistema non viene
  ridistribuita con il gioco.

MISSIONI E CURRICOLO
• 90 missioni in 9 mondi, dalla sequenza iconica ai sistemi complessi.
• Il documento di specifica fornito dall'autore del progetto è la base
  pedagogica; i file JSON in data/missions/ sono la fonte eseguibile.

COME CITARE
ElephantCoding (2026). Coding, matematica e pensiero computazionale con Nilo.
Licenza CC BY 4.0. https://github.com/MaestroLivio/ElephantCoding

NOTE
• I nomi di prodotti e marchi citati appartengono ai rispettivi titolari.
• Le licenze complete sono in LICENSE e THIRD_PARTY_NOTICES.md.
"""


func build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Palette.BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.style(Color(0.06, 0.10, 0.17, 0.96), 18, Color(1, 1, 1, 0.10), 1))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 40
	bar.offset_right = -40
	bar.offset_top = 26
	bar.offset_bottom = 110
	add_child(bar)
	var h := Palette.hbox(14)
	bar.add_child(h)
	var back := Palette.ghost_button("← MENU", 16)
	back.custom_minimum_size = Vector2(130, 54)
	back.pressed.connect(func(): go("menu"))
	h.add_child(back)
	var t := Palette.vbox(1)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	t.add_child(Palette.label("TRASPARENZA SU CODICE, ARTE E VOCI", 12, Palette.MUTED))
	t.add_child(Palette.title("Crediti e licenze", 27))
	h.add_child(Palette.chip("CC BY 4.0", Palette.GREEN, Palette.INK))

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.style(Palette.CARD, 22, Color(1, 1, 1, 0.10), 1))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 128
	panel.offset_bottom = -94
	add_child(panel)
	var scroll := Palette.scroll()
	panel.add_child(scroll)
	var box := Palette.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var text := Palette.label(CREDITS_TEXT, 14, Palette.CREAM, true)
	text.custom_minimum_size = Vector2(0, 900)
	box.add_child(text)

	var footer := Palette.hbox(10)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 120
	footer.offset_right = -120
	footer.offset_top = -78
	footer.offset_bottom = -26
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	footer.add_child(Palette.label("Il progetto è pensato per scuole e ambienti immersivi. Nessun account, nessuna pubblicità, nessun tracciamento.", 12, Palette.MUTED))
