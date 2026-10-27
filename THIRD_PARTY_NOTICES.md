# Third-party notices

ElephantCoding is an original educational game. This file records every
third-party component and where the boundary between original and external
material lies.

## Engine

| Component | Version | Licence | Notes |
| --- | --- | --- | --- |
| Godot Engine | 4.7.2 stable | MIT | https://godotengine.org/license |

The engine's default theme and default font ship inside the Godot editor and
export templates. This repository does not contain a font file and does not
redistribute the engine; see the Godot licence and the font notices that ship
with the engine for their terms.

## Art and 3D

All characters, props, tiles, worlds, portals and UI icons are generated
procedurally from Godot primitives (`godot/scripts/game/nilo.gd`,
`godot/scripts/game/world_builder.gd`) or drawn as original SVG
(`godot/assets/icons/icon.svg`). No third-party model, texture, sprite or font
is bundled.

## Audio

No recorded audio clip is bundled with this repository. The folder
`godot/assets/audio/voice/it/` is a drop-in target for a voice pack. Any clip
added there must be declared in `data/locales/it/voice_manifest.json` with its
author, source URL, licence and attribution; `tools/audio/build_voice_pack.py
--check` enforces the policy.

When voice is enabled and a clip is missing, the game can use the operating
system's Italian text-to-speech voice. That voice is provided by the device and
is never redistributed with the game. Subtitles are always available.

## Mission content

The 90 mission briefs, hints, goal texts and curriculum notes were written for
this project, adapting the project design document supplied by the project
owner. They are original text, not a reproduction of a published book or
course.

## Python tooling

Scripts under `tools/` use the Python standard library only.

## Licence of this project

Unless stated otherwise above, the content of this repository is licensed under
Creative Commons Attribution 4.0 International (CC BY 4.0). See `LICENSE` and
`docs/ATTRIBUTION.md` for the attribution line to reuse.
