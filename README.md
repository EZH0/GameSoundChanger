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

## 한국어

GameSoundChanger는 월드 오브 워크래프트 리테일용 애드온입니다. 플레이어의 특정 주문 시전이나 버프 발동을 감지해서 원하는 커스텀 효과음을 재생할 수 있습니다.

### 설치

`GameSoundChanger` 폴더를 아래 경로에 복사합니다.

```text
D:\World of Warcraft\_retail_\Interface\AddOns\
```

이후 와우 클라이언트를 완전히 재시작합니다.

### 사용 방법

1. `.ogg` 또는 `.mp3` 파일을 `GameSoundChanger\Sounds` 폴더에 넣습니다.
2. 게임 안에서 `Esc > Options > AddOns > GameSoundChanger`를 열거나 `/gsc`를 입력합니다.
3. `Track: Spell` 또는 `Track: Buff`를 선택합니다.
4. 추적하고 싶은 주문, 특성, 능력을 사용하거나 버프를 얻습니다.
5. `Use Last` 버튼을 눌러 마지막으로 감지된 주문 또는 버프 ID를 불러옵니다.
6. `LibSharedMedia` 드롭다운에서 알림 사운드를 고르거나, `Source: Custom file`로 전환한 뒤 `my-sound.ogg` 같은 파일명을 입력합니다.
7. `Preview`로 미리 들어보고 `Add/Update`를 눌러 저장합니다.

이 애드온은 주문 시전 시작, 성공, 채널링 시작, 플레이어 버프 적용/갱신 시점에 사운드를 재생할 수 있습니다.

### 슬래시 명령어

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
