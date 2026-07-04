Audio assets
============

Runtime sound effects are limited to:

- `dragon_fire_flame_pip.wav`: dragon fire breath.
- `enemy_explosion_ultimate_snap_boom_007.ogg`: enemy burst.

Music
=====

The in-game BGM is intentionally split into:

- `game_bgm_intro.flac`: one-shot intro.
- `game_bgm_loop.flac`: seamless 96-second loop body.

Do not replace this with a single MP3 loop. MP3 encoder delay/padding can make
the loop boundary audible even when the source waveform is aligned.

Windows compatibility variants
==============================

The Windows `just_audio` backend uses Windows MediaPlayer, which does not
reliably decode OGG. Windows uses WAV for the enemy-hit one-shot sound:

- `enemy_explosion_ultimate_snap_boom_007.wav` for
  `enemy_explosion_ultimate_snap_boom_007.ogg`

Sources
=======

`dragon_fire_flame_pip.wav`
- Source: generated locally for this game.

`enemy_explosion_ultimate_snap_boom_007.ogg` /
`enemy_explosion_ultimate_snap_boom_007.wav`
- Source: SFX: The Ultimate 2017 16 bit Mini pack / Explosion__007.
- License: Creative Commons Zero (CC0)
- URL: https://opengameart.org/content/sfx-the-ultimate-2017-16-bit-mini-pack

`game_bgm.ogg` / `game_bgm.mp3` / `game_bgm_intro.*` / `game_bgm_loop.*`
- Source: YouFulca / Sky-Airship loop ("Tenkakeru Hikutei").
- Source page: https://youfulca.com/2022/08/11/field_airship/
- License terms: https://youfulca.com/kiyaku_jp/
- License summary: commercial use and modification are allowed for use in the
  game; redistributing or selling the audio material itself as a material
  collection is prohibited. Credit is recommended.
- Recommended credit: Music: YouFulca (https://youfulca.com/)
