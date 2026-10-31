# Jog & Slow Walk

A small PAYDAY 2 mod that adds a jog between walking and sprinting.

In vanilla you either walk or you sprint, and sprinting kills your aim and your stealth. This gives you a middle gear: faster than walking, with a bit more headbob, and you can keep your weapon up. Hold a key and you also get a slow walk for when you really don't want to be heard coming.

## How it works

**Jog:** tap the run key. You move a bit faster than walking (1.35x) and your camera bobs a bit more (1.5x). Jogging uses stamina, just less than a real sprint.

**Sprint:** double tap the run key. This is the normal sprint.

**Slow walk:** hold the slow walk key (left alt by default). You move at 0.7x speed with almost no headbob (0.25x).

It follows your game's run setting:

- *Hold to run off:* tap = toggle jog, double tap = sprint.
- *Hold to run on:* hold = jog, double tap and hold = sprint.

Some details:

- Aiming down sights cancels jog and sprint, unless the weapon allows running and shooting.
- Tapping run while crouched stands you up and starts a jog.
- Slow walk also works while crouched.
- Reloading stops a sprint. There is an option to keep jogging through the reload.
- Heavy bags that can't be run with can't be jogged or sprinted with either. Light bags are fine.

## Install

You need [SuperBLT](https://superblt.znix.xyz/) (or the original BLT) installed.

1. Download or clone this repo.
2. Put the `jog_slow_walk` folder into your `mods` folder in the PAYDAY 2 directory.
3. Start the game. The mod has `needs_restart` set, so if you installed it while the game was running, restart it.

The folder should look like this:

```
mods/
  jog_slow_walk/
    mod.txt
    lua/
    loc/
```

## Setup

Bind your slow walk key under **Options > Mod Keybinds > Slow walk key**. On the first start the mod sets it to left alt if nothing is bound yet. After that it's yours, so you can rebind or unbind it freely.

Mouse buttons work as the slow walk key too.

## Options

Open them under **Options > Mod Options > Jog & Slow Walk**. Settings are saved to `jog_slow_walk.json` in your BLT save folder.

| Option | What it does | Default |
| --- | --- | --- |
| Double tap window | How many seconds can pass between two taps to count as a sprint (0.05 - 1.0). | 0.2 |
| Slow walk cancels run | Holding the slow key ends jog and sprint instead of just pausing them. | on |
| Keep jogging after reload | If a reload stops your sprint, you keep jogging instead of standing still. | off |
| LMB cancels running | Shooting ends your current run, like in vanilla. | off |

## Tweaking the numbers

Speed, headbob and stamina values are not in the menu. They are the constants at the top of `lua/jog_slow_walk.lua`:

```lua
local SPEED, HEADBOB, STAMINA = 1.35, 1.5, 0.5
local SLOW_SPEED, SLOW_HEADBOB = 0.7, 0.25
```

Change them, restart the game, done.

## Languages

English, German, Russian and Simplified Chinese. The mod picks the language from your BLT setting and falls back to English. To add another language, copy `loc/en.txt`, rename it to your language code and translate the values.

## Notes

- This only changes your own movement. It is not meant for other players' clients, and I haven't tested it in every situation, so if something feels off (weird sprint stutter while shooting, slow walk getting stuck), please open an issue and tell me what you were doing.
- The mod hooks `PlayerStandard`. Other mods that heavily change running or movement speed can conflict with it.
