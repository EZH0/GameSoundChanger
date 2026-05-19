# GameSoundChanger

GameSoundChanger is a retail WoW addon that maps your own player spell casts and your own player buff activations to custom sounds.

This addon was created with vibe coding.

## Beta Notes

Version `0.1.2-beta` adds profile sharing, English/Korean UI switching, and a safer player-only aura tracking path. Buff tracking now uses `UNIT_AURA` for the player instead of combat log scanning. When the `/gsc` editor is closed, the addon checks only the buff IDs saved in your rules. When the editor is open, it can scan your player buffs to support the `Use Last` setup flow.

## Features

- Open the sound editor with `/gsc`.
- Track your own spell casts.
- Track your own player buffs.
- Play LibSharedMedia alert sounds.
- Play custom `.ogg` or `.mp3` files from `GameSoundChanger\Sounds`.
- Preview selected sounds before saving.
- Switch the addon UI between English and Korean.
- Save multiple named profiles.
- Export the active profile as a shareable string.
- Import a profile string under a new profile name.
- Manually mute or unmute Blizzard sounds if you know the SoundFileID.

## Use

1. Put `.ogg` or `.mp3` files in `GameSoundChanger\Sounds`.
2. In game, open `Esc > Options > AddOns > GameSoundChanger`, or type `/gsc`.
3. Use the language button if you want to switch between English and Korean.
4. Choose `Track: Spell` or `Track: Buff`.
5. Cast the spell, use the talent or ability, or gain the buff you want to track.
6. Press `Use Last`.
7. Choose a named alert sound from the `LibSharedMedia` dropdown, or switch to `Source: Custom file` and enter a file name such as `my-sound.ogg`.
8. Press `Preview` to test the sound.
9. Press `Add/Update` to save the rule.

The addon can play a sound when a spell starts, succeeds, begins channeling, or when one of your own player buffs is applied/refreshed.

## Profiles

The bottom-left profile controls in the `/gsc` editor are:

```text
Profile
Export Profile
Import Profile
```

`Profile` opens a dropdown containing every saved profile. Selecting a profile switches the editor to that profile.

`Export Profile` exports the active profile as a text string. The addon tries to copy the string to your clipboard automatically. If WoW blocks clipboard access, the export window keeps the string selected so you can press `Ctrl+C`.

`Import Profile` opens a window with two fields. Enter the new profile name in the top field, paste the profile string in the lower field, then press the import button. The imported profile is saved and selected immediately.

## Slash Commands

```text
/gsc
/gsc menu
/gsc on
/gsc off
/gsc last
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

## Korean

GameSoundChanger는 월드 오브 워크래프트 리테일용 애드온입니다. 플레이어 본인의 주문 시전과 플레이어 본인의 버프 발동을 감지해서 원하는 커스텀 효과음을 재생할 수 있습니다.

이 애드온은 바이브 코딩으로 작성되었습니다.

## 베타 참고

`0.1.2-beta` 버전에는 프로파일 공유, 영어/한국어 UI 전환, 플레이어 전용 오라 추적 방식이 추가되었습니다. 버프 추적은 전투 로그를 훑는 대신 플레이어 전용 `UNIT_AURA`를 사용합니다. `/gsc` 편집 창이 닫혀 있을 때는 저장된 버프 ID만 확인하고, 편집 창이 열려 있을 때만 `Use Last` 설정을 돕기 위해 플레이어 버프를 스캔합니다.

## 주요 기능

- `/gsc`로 사운드 편집 창을 열 수 있습니다.
- 플레이어 본인의 주문 시전을 추적합니다.
- 플레이어 본인의 버프를 추적합니다.
- LibSharedMedia 알림 사운드를 사용할 수 있습니다.
- `GameSoundChanger\Sounds` 폴더의 커스텀 `.ogg`, `.mp3` 파일을 사용할 수 있습니다.
- 저장 전 사운드 미리듣기를 지원합니다.
- 애드온 UI를 영어/한국어로 전환할 수 있습니다.
- 여러 개의 이름 있는 프로파일을 저장할 수 있습니다.
- 현재 프로파일을 공유용 문자열로 내보낼 수 있습니다.
- 공유받은 프로파일 문자열을 새 프로파일 이름으로 가져올 수 있습니다.
- Blizzard SoundFileID를 알고 있을 경우 원본 사운드를 수동으로 음소거/해제할 수 있습니다.

## 사용 방법

1. `.ogg` 또는 `.mp3` 파일을 `GameSoundChanger\Sounds` 폴더에 넣습니다.
2. 게임 안에서 `Esc > Options > AddOns > GameSoundChanger`를 열거나 `/gsc`를 입력합니다.
3. 언어 버튼으로 영어/한국어 UI를 전환할 수 있습니다.
4. `Track: Spell` 또는 `Track: Buff`를 선택합니다.
5. 추적하고 싶은 주문, 특성, 능력을 사용하거나 버프를 얻습니다.
6. `Use Last` 버튼을 눌러 마지막으로 감지된 주문 또는 버프 ID를 불러옵니다.
7. `LibSharedMedia` 드롭다운에서 알림 사운드를 고르거나, `Source: Custom file`로 전환한 뒤 `my-sound.ogg` 같은 파일명을 입력합니다.
8. `Preview`로 미리 들어봅니다.
9. `Add/Update`를 눌러 규칙을 저장합니다.

이 애드온은 주문 시전 시작, 성공, 채널링 시작, 플레이어 본인 버프 적용/갱신 시점에 사운드를 재생할 수 있습니다.

## 프로파일

`/gsc` 편집 창 좌측 하단에는 다음 버튼이 있습니다.

```text
프로파일
프로파일 내보내기
프로파일 가져오기
```

`프로파일`은 저장된 모든 프로파일을 드롭다운으로 보여줍니다. 프로파일을 선택하면 해당 프로파일로 전환됩니다.

`프로파일 내보내기`는 현재 활성 프로파일을 공유용 문자열로 내보냅니다. 애드온은 문자열을 클립보드에 자동 복사하려고 시도합니다. WoW에서 클립보드 접근이 차단되면 내보내기 창에서 문자열을 선택된 상태로 보여주므로 `Ctrl+C`로 복사하면 됩니다.

`프로파일 가져오기`를 누르면 두 개의 입력 칸이 있는 창이 열립니다. 위 칸에는 새 프로파일 이름을 입력하고, 아래 칸에는 공유받은 프로파일 문자열을 붙여넣은 뒤 가져오기 버튼을 누르면 됩니다. 가져온 프로파일은 저장되고 즉시 선택됩니다.

## 슬래시 명령어

```text
/gsc - 사운드 편집 창을 열거나 닫습니다.
/gsc menu - 애드온 설정 페이지를 엽니다.
/gsc on - 커스텀 사운드 기능을 켭니다.
/gsc off - 커스텀 사운드 기능을 끕니다.
/gsc last - 마지막으로 감지된 주문과 버프를 표시합니다.
/gsc add <spellID> <soundFile> - 커스텀 사운드 파일을 사용하는 주문 규칙을 추가합니다.
/gsc addbuff <buffID> <soundFile> - 커스텀 사운드 파일을 사용하는 버프 규칙을 추가합니다.
/gsc addlast <soundFile> - 마지막으로 감지된 주문에 커스텀 사운드 파일을 연결합니다.
/gsc addlastbuff <soundFile> - 마지막으로 감지된 버프에 커스텀 사운드 파일을 연결합니다.
/gsc remove SPELL:<spellID> - 저장된 주문 규칙을 삭제합니다.
/gsc remove AURA:<buffID> - 저장된 버프 규칙을 삭제합니다.
/gsc mute <soundFileID> - Blizzard SoundFileID를 알고 있을 경우 해당 원본 사운드를 수동으로 음소거합니다.
/gsc unmute <soundFileID> - 이전에 음소거한 원본 사운드를 다시 해제합니다.
```

드롭다운 사운드 목록은 `LibSharedMedia-3.0`에서 가져옵니다. 이는 ElvUI 채팅 알림, Details, DBM, SharedMedia 팩 등에서 사용하는 것과 같은 방식입니다. 애드온은 `Sounds` 폴더 안의 임의 파일을 자동으로 검색할 수 없으므로, 커스텀 파일은 직접 파일명을 입력해야 합니다.

`mute`와 `unmute` 기능을 사용하려면 Blizzard 사운드 파일 ID가 필요합니다. 이 애드온은 해당 ID를 자동으로 찾아주지 않습니다.
