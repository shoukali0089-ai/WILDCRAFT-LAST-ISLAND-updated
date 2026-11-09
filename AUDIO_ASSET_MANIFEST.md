# Audio Asset Manifest

No external audio files are included or downloaded. All streams are generated
at runtime as basic synthesized `AudioStreamWAV` placeholders by
`scripts/audio_manager.gd`. These tones/noise bursts are integration placeholders,
not recorded Foley, animal calls, environmental recordings, music, or CC0 asset
substitutes. No third-party audio licenses apply.

## Generated one-shot placeholders

| Category | Sound keys |
| --- | --- |
| Gathering and pickups | `wood_chop`, `tree_impact`, `tree_fall`, `wood_break`, `stone_hit`, `stone_crack`, `stone_break`, `pickup_wood`, `pickup_stone`, `pickup_berries` |
| Player movement | `footstep_grass`, `footstep_sand`, `footstep_rock`, `footstep_wood`, `jump`, `land`, `swim`, `breath`, `exertion` |
| Wildlife | `deer_call`, `deer_alert`, `deer_flee`, `deer_step`, `boar_step`, `boar_growl`, `boar_defend` |
| Weather | `thunder`, `lightning` |
| Crafting and building | `craft_axe`, `craft_spear`, `craft_campfire`, `build_foundation`, `build_wall`, `build_door`, `build_roof` |
| Survival actions and UI | `eat`, `drink`, `action_fail`, `ui_click` |

## Generated ambience-loop placeholders

`ocean`, `birds`, `insects`, `wind`, `light_rain`, `storm_rain`, `campfire`.
Weather and day/night control fades for rain, wind, birds, and insects. Ocean
ambience starts at a low level; campfire ambience is defined but remains off
until a campfire gameplay event exists.

## Gameplay integration status

Player footsteps, landing, exertion, gathering, successful crafting, failed
actions, placed structures, wildlife state/movement events, weather, lightning,
and day/night ambience are connected to existing gameplay events. `jump`,
`swim`, `eat`, `drink`, and `campfire` have placeholder definitions only; the
corresponding player actions or placed campfire are not currently implemented.
There is no music track or recorded audio asset.
