# Audio Asset Manifest

## License and source

The real files below are OGG previews from Meta's Oculus Audio Pack 1, pinned
to the [`Meta-open-sound` source revision](https://github.com/facebookincubator/Meta-open-sound/tree/251c0be57d5d1b3242b91f53e0cde62ab1cb42d9/corpora/oculus-audio-pack).
The collection is licensed **Creative Commons Attribution 4.0 International
(CC BY 4.0)**, not CC0. The pack's license and required credit are included at
[`assets/audio/oculus/LICENSE`](./assets/audio/oculus/LICENSE) and
[`assets/audio/oculus/ATTRIBUTION.md`](./assets/audio/oculus/ATTRIBUTION.md).
The OGG files are the source repository's previews, transcoded from the pack's
WAV originals.

No relevant CC0 recordings were verified for this set. These CC BY recordings
are used because the license permits redistribution and commercial use when
attributed. No generated or synthesized audio is used as a fallback.

All files are stored under `assets/audio/oculus/`. Entries are OGG Vorbis files
loaded by `scripts/audio_manager.gd`.

## Integrated real assets

| File | License / source | Use and integration status |
| --- | --- | --- |
| `AMBForst_Forest_LOOP_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as daytime forest ambience in the existing birds/forest ambience slot. This is a general forest bed, not an isolated bird call. |
| `AMBForst_Night_LOOP_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as nighttime insects ambience; source description identifies crickets and insects. |
| `FEETHmn_ShoeGrassRun_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as one grass running-footstep variation. Human shoes on grass. |
| `FEETHmn_ShoeGrassRun_OS_02.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as one grass running-footstep variation. Human shoes on grass. |
| `FEETHmn_ShoeGrassRun_OS_03.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as one grass running-footstep variation. Human shoes on grass. |
| `FEETHmn_ShoeDirtRun_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a dirt-track surrogate for the sand-footstep event; it is not a sand recording. |
| `FEETHmn_ShoeDirtRun_OS_02.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a dirt-track surrogate for the sand-footstep event; it is not a sand recording. |
| `FEETHmn_ShoeDirtRun_OS_03.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a dirt-track surrogate for the sand-footstep event; it is not a sand recording. |
| `FEETHmn_ShoeConcreteRun_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a hard-floor surrogate for the rock-footstep event; it is not a natural-rock recording. |
| `FEETHmn_ShoeConcreteRun_OS_02.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a hard-floor surrogate for the rock-footstep event; it is not a natural-rock recording. |
| `FEETHmn_ShoeConcreteRun_OS_03.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a hard-floor surrogate for the rock-footstep event; it is not a natural-rock recording. |
| `FEETHmn_ShoeWoodRun_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as one wooden-footstep variation. Human shoes on wood. |
| `FEETHmn_ShoeWoodRun_OS_02.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as one wooden-footstep variation. Human shoes on wood. |
| `FEETHmn_ShoeWoodRun_OS_03.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as one wooden-footstep variation. Human shoes on wood. |
| `FEETHmn_ShoeGrassLand_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated for player landing on grass. Human shoes on grass. |
| `FEETHmn_ShoeGrassLand_OS_02.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a landing variation. Human shoes on grass. |
| `RAINVege_ForestRain_LOOP_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated for foliage rain. Also used louder as a storm-rain fallback; it is not a separate heavy-storm recording. |
| `UIClick_WoodConfirm_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated for the generic UI click and successful craft confirmation. It is UI feedback, not crafting Foley. |
| `UIAlert_WoodError_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated for failed-action UI feedback. |
| `WATRWave_OceanWaves_LOOP_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as ocean-wave ambience. |
| `WINDVege_LightWindTreesBirds_LOOP_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as light vegetation wind; the source also contains birds. Storm mode raises its level but does not turn it into a distinct storm-wind recording. |
| `WOODImpt_LargeWoodDrop_OS_01.ogg` | CC BY 4.0, Oculus Audio Pack 1 | Integrated as a shared 3D wooden placement thud for foundation, wall, door, and roof placement. It is a wood-object drop, not dedicated construction Foley. |

## Pending recordings

These are intentionally silent when their event occurs until a suitable,
licensed recording is added. No synthesized tone or unrelated recording is
used to imply that the requested effect exists.

| Sound requirement | Status |
| --- | --- |
| Axe chopping, tree falling, wood breaking | Pending; no suitable recording verified. |
| Pickaxe hits, stone cracks and breaks | Pending; no suitable recording verified. |
| Wood, stone, and berry resource pickups | Pending; no suitable recording verified. |
| Deer calls, alert/flee sounds, deer footsteps | Pending; no deer-specific recording verified. |
| Boar growls/defense sounds and animal running/hooves | Pending; no suitable boar or animal-running recording verified. |
| Sand and natural-stone footsteps | Surrogate audio is wired as listed above; exact surface recordings remain pending. |
| Distinct heavy rain, thunder, lightning, and storm wind | Pending; rain and light-wind files are used as disclosed fallbacks only. |
| Isolated bird calls | Pending; the integrated forest and wind beds are not isolated calls. |
| Campfire crackling | Pending; no suitable recording verified. |
| Diegetic crafting Foley and distinct building sounds | Pending; crafting uses a wooden UI confirmation, and structures share a generic wooden placement thud. |
| Jump, swim, eating, drinking, breathing | Pending; no suitable recordings verified, and some corresponding gameplay actions do not exist. |
