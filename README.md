# GameSoundChanger

GameSoundChanger is a retail WoW addon prototype that maps player spell casts or player buff activations to custom sounds.

## Install

Copy the `GameSoundChanger` folder into:

```text
D:\World of Warcraft\_retail_\Interface\AddOns\
```

Then restart the WoW client.

## Use

1. Put `.ogg` or `.mp3` files in `GameSoundChanger\Sounds`.
2. In game, open `Esc > Options > AddOns > GameSoundChanger`, or type `/gsc`.
3. Choose `Track: Spell` or `Track: Buff`.
4. Cast the spell/talent/ability, or gain the buff you want to track.
5. Press `Use Last`.
6. Choose a named alert sound from the `LibSharedMedia` dropdown, or switch to `Source: Custom file` and enter a file name such as `my-sound.ogg`.
7. Press `Add/Update`.

The addon can play a sound when a spell starts, succeeds, begins channeling, or when a player buff is applied/refreshed.

## Slash commands

```text
/gsc
/gsc menu
/gsc on
/gsc off
/gsc add <spellID> <soundFile>
/gsc addbuff <buffID> <soundFile>
/gsc addlast <soundFile>
/gsc addlastbuff <soundFile>
/gsc remove SPELL:<spellID>
/gsc remove AURA:<buffID>
/gsc mute <soundFileID>
/gsc unmute <soundFileID>
```

Dropdown choices come from `LibSharedMedia-3.0`, the same named sound pool used by ElvUI chat alerts, Details, DBM, SharedMedia packs, and similar addons. The addon cannot enumerate arbitrary files inside the custom `Sounds` folder, so custom files still need a typed file name.

`mute` and `unmute` require Blizzard sound file IDs. The addon cannot discover those IDs automatically.
