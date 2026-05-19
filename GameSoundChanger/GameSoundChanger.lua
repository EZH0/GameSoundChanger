local ADDON_NAME = ...
if not ADDON_NAME or ADDON_NAME == "" then
	ADDON_NAME = "GameSoundChanger"
end

local PREFIX = "|cff66ccffGameSoundChanger:|r "
local BASE_SOUND_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"
local ROWS_PER_PAGE = 8
local SOUND_ROWS_PER_PAGE = 10
local PROFILE_EXPORT_VERSION = "GSC1"

local CHANNELS = { "Master", "SFX", "Ambience", "Dialog", "Music" }
local RULE_TYPES = { "SPELL", "AURA" }
local SPELL_TRIGGERS = { "SUCCEEDED", "START", "CHANNEL_START", "ANY" }
local AURA_TRIGGERS = { "APPLIED", "REFRESH", "ANY" }
local EVENT_TO_TRIGGER = {
	UNIT_SPELLCAST_SUCCEEDED = "SUCCEEDED",
	UNIT_SPELLCAST_START = "START",
	UNIT_SPELLCAST_CHANNEL_START = "CHANNEL_START",
}

local defaults = {
	enabled = true,
	channel = "Master",
	locale = "en",
	activeProfile = "Default",
	rules = {},
	mappings = {},
	mutedSoundFileIDs = {},
	profiles = {},
}

local addon = CreateFrame("Frame")
local ui
local settingsPanel
local settingsCategory
local rows = {}
local page = 1
local lastSpell = {}
local lastAura = {}
local failedSoundAt = {}
local mediaSoundChoices
local migratedLegacyMappings
local auraStates = {}
local ApplyMutedSoundFiles

local localeText = {
	en = {
		addUpdate = "Add/Update",
		alertListHint = "Alert list sounds come from LibSharedMedia. Custom files still go in Interface\\AddOns\\GameSoundChanger\\Sounds.",
		buff = "Buff",
		channel = "Channel: %s",
		close = "Close",
		copied = "Profile string copied to clipboard.",
		copyFallback = "Clipboard copy was blocked. Press Ctrl+C in the export box.",
		customFile = "Source: Custom file",
		disabled = "Disabled.",
		enabled = "Enabled",
		enabledMessage = "Enabled.",
		export = "Export Profile",
		exportTitle = "Export Profile",
		import = "Import Profile",
		importName = "Profile name",
		importString = "Profile string",
		importTitle = "Import Profile",
		language = "Language: English",
		lastBuff = "Last buff: %s",
		lastBuffNone = "Last buff: none yet",
		lastSpell = "Last spell: %s",
		lastSpellNone = "Last spell: none yet",
		noImportName = "Enter a profile name.",
		noImportString = "Enter a profile string.",
		noSound = "Choose an alert sound or custom sound file.",
		page = "Page %d / %d",
		profile = "Profile: %s",
		profileImported = "Imported profile: %s.",
		profileSwitched = "Switched to profile: %s.",
		rules = "Rules",
		settingsChannel = "Sound channel: %s",
		settingsCount = "Saved rules: %d",
		settingsDescription = "Choose player spells or player buff activations, then play named alert sounds from LibSharedMedia or custom audio.",
		settingsEnable = "Enable custom sounds",
		settingsOpen = "Open Sound Editor",
		settingsTip = "Tip: cast a spell or gain a buff, open the sound editor, press Use Last, then choose an alert sound.",
		soundEditor = "GameSoundChanger",
		soundSource = "Source: Alert list",
		spell = "Spell",
		spellOrBuffID = "%s ID",
		track = "Track: %s",
		trigger = "Trigger: %s",
		useLast = "Use Last",
		preview = "Preview",
	},
	ko = {
		addUpdate = "추가/갱신",
		alertListHint = "알림 사운드는 LibSharedMedia에서 가져옵니다. 커스텀 파일은 Interface\\AddOns\\GameSoundChanger\\Sounds에 넣어주세요.",
		buff = "버프",
		channel = "채널: %s",
		close = "닫기",
		copied = "프로파일 문자열을 클립보드에 복사했습니다.",
		copyFallback = "클립보드 복사가 차단되었습니다. 내보내기 칸에서 Ctrl+C를 눌러주세요.",
		customFile = "소스: 커스텀 파일",
		disabled = "비활성화했습니다.",
		enabled = "활성화",
		enabledMessage = "활성화했습니다.",
		export = "프로파일 내보내기",
		exportTitle = "프로파일 내보내기",
		import = "프로파일 가져오기",
		importName = "프로파일 이름",
		importString = "프로파일 문자열",
		importTitle = "프로파일 가져오기",
		language = "언어: 한국어",
		lastBuff = "마지막 버프: %s",
		lastBuffNone = "마지막 버프: 없음",
		lastSpell = "마지막 주문: %s",
		lastSpellNone = "마지막 주문: 없음",
		noImportName = "프로파일 이름을 입력하세요.",
		noImportString = "프로파일 문자열을 입력하세요.",
		noSound = "알림 사운드 또는 커스텀 사운드 파일을 선택하세요.",
		page = "페이지 %d / %d",
		profile = "프로파일: %s",
		profileImported = "프로파일을 가져왔습니다: %s.",
		profileSwitched = "프로파일을 전환했습니다: %s.",
		rules = "규칙",
		settingsChannel = "사운드 채널: %s",
		settingsCount = "저장된 규칙: %d",
		settingsDescription = "플레이어 주문 또는 플레이어 버프 발동을 선택한 뒤 LibSharedMedia 알림음이나 커스텀 사운드를 재생합니다.",
		settingsEnable = "커스텀 사운드 활성화",
		settingsOpen = "사운드 편집기 열기",
		settingsTip = "팁: 주문을 사용하거나 버프를 얻은 뒤 사운드 편집기에서 Use Last를 누르고 알림음을 선택하세요.",
		soundEditor = "GameSoundChanger",
		soundSource = "소스: 알림 목록",
		spell = "주문",
		spellOrBuffID = "%s ID",
		track = "추적: %s",
		trigger = "발동: %s",
		useLast = "최근 항목",
		preview = "미리듣기",
	},
}

local function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
	else
		print(PREFIX .. tostring(message))
	end
end

local function Trim(value)
	value = value or ""
	return value:match("^%s*(.-)%s*$")
end

local function SafeNumber(value)
	local ok, numberValue = pcall(tonumber, value)
	if ok then
		return numberValue
	end
	return nil
end

local function L(key, ...)
	local db = GameSoundChangerDB
	local locale = db and db.locale or "en"
	local text = (localeText[locale] and localeText[locale][key]) or localeText.en[key] or key
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

local function CopyDefaults(source, target)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyDefaults(value, target[key])
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function CopyTable(source)
	local target = {}
	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = CopyTable(value)
		else
			target[key] = value
		end
	end
	return target
end

local function NormalizeProfileName(name)
	name = Trim(name)
	if name == "" then
		return "Default"
	end
	return name
end

local function MakeProfileFromDB(db)
	return {
		enabled = db.enabled ~= false,
		channel = db.channel or "Master",
		locale = db.locale or "en",
		rules = CopyTable(db.rules),
		mutedSoundFileIDs = CopyTable(db.mutedSoundFileIDs),
	}
end

local function BindActiveProfile(db)
	db.activeProfile = NormalizeProfileName(db.activeProfile)
	if type(db.profiles) ~= "table" then
		db.profiles = {}
	end
	if type(db.profiles[db.activeProfile]) ~= "table" then
		db.profiles[db.activeProfile] = MakeProfileFromDB(db)
	end

	local profile = db.profiles[db.activeProfile]
	if type(profile.rules) ~= "table" then
		profile.rules = {}
	end
	if type(profile.mutedSoundFileIDs) ~= "table" then
		profile.mutedSoundFileIDs = {}
	end

	profile.enabled = profile.enabled ~= false
	profile.channel = profile.channel or "Master"
	profile.locale = profile.locale or db.locale or "en"

	db.enabled = profile.enabled
	db.channel = profile.channel
	db.locale = profile.locale
	db.rules = profile.rules
	db.mutedSoundFileIDs = profile.mutedSoundFileIDs
end

local function DB()
	if type(GameSoundChangerDB) ~= "table" then
		GameSoundChangerDB = {}
	end
	CopyDefaults(defaults, GameSoundChangerDB)
	BindActiveProfile(GameSoundChangerDB)
	return GameSoundChangerDB
end

local function SaveCurrentProfile()
	local db = DB()
	local profileName = NormalizeProfileName(db.activeProfile)
	if type(db.profiles[profileName]) ~= "table" then
		db.profiles[profileName] = {}
	end

	local profile = db.profiles[profileName]
	profile.enabled = db.enabled ~= false
	profile.channel = db.channel or "Master"
	profile.locale = db.locale or "en"
	profile.rules = db.rules or {}
	profile.mutedSoundFileIDs = db.mutedSoundFileIDs or {}
end

local function GetProfileNames()
	local names = {}
	for name in pairs(DB().profiles or {}) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function ActivateProfile(name)
	local db = DB()
	name = NormalizeProfileName(name)
	if type(db.profiles[name]) ~= "table" then
		db.profiles[name] = {
			enabled = true,
			channel = "Master",
			locale = db.locale or "en",
			rules = {},
			mutedSoundFileIDs = {},
		}
	end
	db.activeProfile = name
	BindActiveProfile(db)
	ApplyMutedSoundFiles()
	auraStates = {}
	Print(L("profileSwitched", name))
end

local function Contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function NextValue(list, current)
	for index, item in ipairs(list) do
		if item == current then
			return list[(index % #list) + 1]
		end
	end
	return list[1]
end

local function NormalizePath(path)
	path = Trim(path):gsub("/", "\\")
	if path == "" then
		return nil
	end

	local lowered = string.lower(path)
	if lowered:match("^interface\\") or lowered:match("^sound\\") then
		return path
	end

	if lowered:match("^sounds\\") then
		return "Interface\\AddOns\\" .. ADDON_NAME .. "\\" .. path
	end

	return BASE_SOUND_PATH .. path
end

local function GetSpellName(spellID)
	spellID = SafeNumber(spellID)
	if not spellID then
		return nil
	end

	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		if info and info.name then
			return info.name
		end
	end

	if GetSpellInfo then
		local name = GetSpellInfo(spellID)
		if name then
			return name
		end
	end

	return "Spell " .. spellID
end

local function GetTriggerList(ruleType)
	if ruleType == "AURA" then
		return AURA_TRIGGERS
	end
	return SPELL_TRIGGERS
end

local function TriggerMatches(savedTrigger, eventTrigger)
	savedTrigger = savedTrigger or "SUCCEEDED"
	return savedTrigger == "ANY" or savedTrigger == eventTrigger
end

local function RuleKey(ruleType, id)
	id = tonumber(id)
	if not id then
		return nil
	end
	return ruleType .. ":" .. id
end

local function RuleTypeLabel(ruleType)
	if ruleType == "AURA" then
		return L("buff")
	end
	return L("spell")
end

local function NormalizeSound(sound)
	if type(sound) == "table" then
		if sound.type == "kit" then
			local kit = tonumber(sound.kit or sound.id)
			if kit then
				return {
					type = "kit",
					kit = kit,
					label = sound.label or sound.name or tostring(kit),
				}
			end
		elseif sound.type == "lsm" then
			local name = Trim(sound.name or sound.label)
			if name ~= "" then
				return {
					type = "lsm",
					name = name,
					path = sound.path,
					label = sound.label or name,
				}
			end
		elseif sound.type == "file" or sound.path then
			local path = NormalizePath(sound.path)
			if path then
				return {
					type = "file",
					path = path,
				}
			end
		end
	elseif type(sound) == "string" then
		local path = NormalizePath(sound)
		if path then
			return {
				type = "file",
				path = path,
			}
		end
	end

	return nil
end

local function FormatSoundLabel(sound)
	sound = NormalizeSound(sound)
	if not sound then
		return "No sound"
	end

	if sound.type == "kit" then
		return "SOUNDKIT: " .. (sound.label or tostring(sound.kit)) .. " (" .. sound.kit .. ")"
	end

	if sound.type == "lsm" then
		return "Alert: " .. (sound.name or sound.label or "Unknown")
	end

	local path = sound.path or ""
	return "Custom: " .. (path:match("[^\\]+$") or path)
end

local function EncodeToken(value)
	value = tostring(value or "")
	return (value:gsub("([^%w _%.%-])", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

local function DecodeToken(value)
	value = tostring(value or "")
	return (value:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function SplitLine(line)
	local parts = {}
	for part in string.gmatch(line .. "|", "(.-)|") do
		parts[#parts + 1] = DecodeToken(part)
	end
	return parts
end

local function SoundToTokens(sound)
	sound = NormalizeSound(sound)
	if not sound then
		return { "file", "" }
	end

	if sound.type == "kit" then
		return { "kit", tostring(sound.kit or ""), sound.label or "" }
	elseif sound.type == "lsm" then
		return { "lsm", sound.name or "", sound.path or "", sound.label or "" }
	end

	return { "file", sound.path or "" }
end

local function TokensToSound(parts, startIndex)
	local soundType = parts[startIndex]
	if soundType == "kit" then
		return NormalizeSound({
			type = "kit",
			kit = parts[startIndex + 1],
			label = parts[startIndex + 2],
		})
	elseif soundType == "lsm" then
		return NormalizeSound({
			type = "lsm",
			name = parts[startIndex + 1],
			path = parts[startIndex + 2],
			label = parts[startIndex + 3],
		})
	end

	return NormalizeSound({
		type = "file",
		path = parts[startIndex + 1],
	})
end

local function SerializeProfile(profile)
	profile = profile or MakeProfileFromDB(DB())
	local lines = {
		PROFILE_EXPORT_VERSION,
		table.concat({
			"S",
			EncodeToken(profile.enabled ~= false and "1" or "0"),
			EncodeToken(profile.channel or "Master"),
			EncodeToken(profile.locale or "en"),
		}, "|"),
	}

	local ruleKeys = {}
	for key in pairs(profile.rules or {}) do
		ruleKeys[#ruleKeys + 1] = key
	end
	table.sort(ruleKeys)

	for _, key in ipairs(ruleKeys) do
		local rule = profile.rules[key]
		local soundTokens = SoundToTokens(rule.sound)
		local parts = {
			"R",
			rule.type or "SPELL",
			tostring(rule.id or ""),
			rule.trigger or "ANY",
			rule.name or "",
		}
		for _, token in ipairs(soundTokens) do
			parts[#parts + 1] = token
		end
		for index, value in ipairs(parts) do
			parts[index] = EncodeToken(value)
		end
		lines[#lines + 1] = table.concat(parts, "|")
	end

	local muted = {}
	for fileID, enabled in pairs(profile.mutedSoundFileIDs or {}) do
		if enabled then
			muted[#muted + 1] = tostring(fileID)
		end
	end
	table.sort(muted)
	for _, fileID in ipairs(muted) do
		lines[#lines + 1] = "M|" .. EncodeToken(fileID)
	end

	return table.concat(lines, "\n")
end

local function DeserializeProfile(text)
	text = Trim(text)
	if text == "" then
		return nil, L("noImportString")
	end

	local profile = {
		enabled = true,
		channel = "Master",
		locale = "en",
		rules = {},
		mutedSoundFileIDs = {},
	}

	local first = true
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		line = Trim(line)
		if line ~= "" then
			if first then
				first = false
				if line ~= PROFILE_EXPORT_VERSION then
					return nil, "Unsupported profile string."
				end
			else
				local parts = SplitLine(line)
				if parts[1] == "S" then
					profile.enabled = parts[2] ~= "0"
					profile.channel = parts[3] ~= "" and parts[3] or "Master"
					profile.locale = (parts[4] == "ko") and "ko" or "en"
				elseif parts[1] == "R" then
					local ruleType = (parts[2] == "AURA" or parts[2] == "SPELL") and parts[2] or "SPELL"
					local id = tonumber(parts[3])
					local trigger = parts[4] or "ANY"
					local sound = TokensToSound(parts, 6)
					local key = RuleKey(ruleType, id)
					if key and sound then
						profile.rules[key] = {
							type = ruleType,
							id = id,
							trigger = trigger,
							name = parts[5] ~= "" and parts[5] or GetSpellName(id),
							sound = sound,
						}
					end
				elseif parts[1] == "M" then
					local fileID = tonumber(parts[2])
					if fileID then
						profile.mutedSoundFileIDs[fileID] = true
					end
				end
			end
		end
	end

	return profile
end

local function GetSharedMedia()
	if LibStub then
		return LibStub("LibSharedMedia-3.0", true)
	end
	return nil
end

local function BuildSoundChoices()
	local lsm = GetSharedMedia()
	local choices = {}

	if lsm and lsm.List and lsm.Fetch then
		local names = lsm:List("sound") or {}
		for _, name in ipairs(names) do
			local path = lsm:Fetch("sound", name, true)
			if name ~= "None" and path and path ~= 1 then
				choices[#choices + 1] = {
					source = "lsm",
					name = name,
					path = path,
					label = name,
				}
			end
		end
	end

	table.sort(choices, function(a, b)
		return a.name < b.name
	end)

	mediaSoundChoices = choices
	return mediaSoundChoices
end

local function FilterSoundChoices(filter)
	local choices = BuildSoundChoices()
	filter = string.lower(Trim(filter))
	if filter == "" then
		return choices
	end

	local filtered = {}
	for _, choice in ipairs(choices) do
		if string.find(string.lower(choice.name), filter, 1, true) or string.find(string.lower(tostring(choice.path or "")), filter, 1, true) then
			filtered[#filtered + 1] = choice
		end
	end
	return filtered
end

local function GetDefaultSound()
	local choices = BuildSoundChoices()

	if choices[1] then
		return {
			type = "lsm",
			name = choices[1].name,
			path = choices[1].path,
			label = choices[1].name,
		}
	end

	return nil
end

local function PlayFileSound(path)
	path = NormalizePath(path)
	if not path then
		Print("No custom sound file set.")
		return
	end

	local ok, played = pcall(PlaySoundFile, path, DB().channel or "Master")
	if not ok or played == false then
		local now = GetTime and GetTime() or 0
		if not failedSoundAt[path] or now - failedSoundAt[path] > 5 then
			Print("Could not play: " .. path)
			failedSoundAt[path] = now
		end
	end
end

local function PlaySelectedSound(sound)
	sound = NormalizeSound(sound)
	if not sound then
		Print("Choose a sound first.")
		return
	end

	if sound.type == "kit" then
		local ok, played = pcall(PlaySound, sound.kit, DB().channel or "Master")
		if not ok or played == false then
			Print("Could not play built-in sound " .. sound.kit .. ".")
		end
	elseif sound.type == "lsm" then
		local path = sound.path
		local lsm = GetSharedMedia()
		if lsm and lsm.Fetch and sound.name then
			path = lsm:Fetch("sound", sound.name, true) or path
		end

		if type(path) == "number" then
			local ok, played = pcall(PlaySound, path, DB().channel or "Master")
			if not ok or played == false then
				Print("Could not play alert sound " .. (sound.name or path) .. ".")
			end
		else
			PlayFileSound(path)
		end
	else
		PlayFileSound(sound.path)
	end
end

function ApplyMutedSoundFiles()
	for fileID, muted in pairs(DB().mutedSoundFileIDs) do
		local numericID = tonumber(fileID)
		if numericID and muted and MuteSoundFile then
			MuteSoundFile(numericID)
		end
	end
end

local function MigrateLegacyMappings()
	if migratedLegacyMappings then
		return
	end

	local db = DB()
	if type(db.rules) ~= "table" then
		db.rules = {}
	end

	for spellID, mapping in pairs(db.mappings or {}) do
		local id = tonumber(spellID)
		if id then
			local sound
			local trigger = "SUCCEEDED"
			local name = GetSpellName(id)

			if type(mapping) == "table" then
				sound = NormalizeSound(mapping.sound or mapping.path)
				trigger = mapping.trigger or trigger
				name = mapping.name or name
			else
				sound = NormalizeSound(mapping)
			end

			local key = RuleKey("SPELL", id)
			if key and not db.rules[key] and sound then
				db.rules[key] = {
					type = "SPELL",
					id = id,
					name = name,
					trigger = trigger,
					sound = sound,
				}
			end
		end
	end

	migratedLegacyMappings = true
end

local function CountRules()
	MigrateLegacyMappings()
	local count = 0
	for _ in pairs(DB().rules) do
		count = count + 1
	end
	return count
end

local function SortedRuleKeys()
	MigrateLegacyMappings()
	local keys = {}
	for key in pairs(DB().rules) do
		keys[#keys + 1] = key
	end

	table.sort(keys, function(a, b)
		local ruleA = DB().rules[a]
		local ruleB = DB().rules[b]
		if ruleA.type ~= ruleB.type then
			return tostring(ruleA.type) < tostring(ruleB.type)
		end
		return tonumber(ruleA.id or 0) < tonumber(ruleB.id or 0)
	end)

	return keys
end

local material = {
	panel = { 0.025, 0.027, 0.031, 0.98 },
	panelTop = { 0.045, 0.048, 0.054, 1 },
	panelInset = { 0.012, 0.013, 0.016, 0.86 },
	control = { 0.038, 0.041, 0.047, 0.96 },
	controlHover = { 0.075, 0.081, 0.091, 0.98 },
	controlDown = { 0.018, 0.02, 0.024, 1 },
	rowOdd = { 0.025, 0.027, 0.031, 0.64 },
	rowEven = { 0.042, 0.045, 0.052, 0.62 },
	border = { 0.18, 0.19, 0.21, 1 },
	borderBright = { 0.34, 0.36, 0.39, 1 },
	accent = { 0.16, 0.68, 0.92, 1 },
	text = { 0.86, 0.88, 0.9, 1 },
	textDim = { 0.58, 0.61, 0.65, 1 },
}

local function SetVertexColor(texture, color)
	texture:SetColorTexture(color[1], color[2], color[3], color[4])
end

local function AddBorder(frame, color)
	color = color or material.border

	frame.leftBorder = frame:CreateTexture(nil, "BORDER")
	frame.leftBorder:SetPoint("TOPLEFT")
	frame.leftBorder:SetPoint("BOTTOMLEFT")
	frame.leftBorder:SetWidth(1)
	SetVertexColor(frame.leftBorder, color)

	frame.rightBorder = frame:CreateTexture(nil, "BORDER")
	frame.rightBorder:SetPoint("TOPRIGHT")
	frame.rightBorder:SetPoint("BOTTOMRIGHT")
	frame.rightBorder:SetWidth(1)
	SetVertexColor(frame.rightBorder, color)

	frame.topBorder = frame:CreateTexture(nil, "BORDER")
	frame.topBorder:SetPoint("TOPLEFT")
	frame.topBorder:SetPoint("TOPRIGHT")
	frame.topBorder:SetHeight(1)
	SetVertexColor(frame.topBorder, color)

	frame.bottomBorder = frame:CreateTexture(nil, "BORDER")
	frame.bottomBorder:SetPoint("BOTTOMLEFT")
	frame.bottomBorder:SetPoint("BOTTOMRIGHT")
	frame.bottomBorder:SetHeight(1)
	SetVertexColor(frame.bottomBorder, color)
end

local function AddBackground(frame, color, borderColor)
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints()
	SetVertexColor(frame.bg, color)
	AddBorder(frame, borderColor)
end

local function ApplyButtonState(button, color)
	if button.bg then
		SetVertexColor(button.bg, color)
	end
end

local function CreateLabel(parent, text, width)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetJustifyH("LEFT")
	label:SetText(text)
	if width then
		label:SetWidth(width)
	end
	return label
end

local function CreateButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width or 96, 24)
	AddBackground(button, material.control, material.border)

	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints()
	SetVertexColor(button.highlight, { 0.13, 0.58, 0.82, 0.16 })

	button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	button.label:SetPoint("LEFT", 8, 0)
	button.label:SetPoint("RIGHT", -8, 0)
	button.label:SetJustifyH("CENTER")
	button.label:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])

	button.SetText = function(self, value)
		self.label:SetText(value or "")
	end
	button.GetText = function(self)
		return self.label:GetText()
	end
	button:SetText(text)

	button:SetScript("OnEnter", function(self)
		if self:IsEnabled() then
			ApplyButtonState(self, material.controlHover)
		end
	end)
	button:SetScript("OnLeave", function(self)
		ApplyButtonState(self, material.control)
	end)
	button:SetScript("OnMouseDown", function(self)
		if self:IsEnabled() then
			ApplyButtonState(self, material.controlDown)
			self.label:ClearAllPoints()
			self.label:SetPoint("CENTER", 1, -1)
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		ApplyButtonState(self, self:IsMouseOver() and material.controlHover or material.control)
		self.label:ClearAllPoints()
		self.label:SetPoint("LEFT", 8, 0)
		self.label:SetPoint("RIGHT", -8, 0)
	end)
	button:SetScript("OnDisable", function(self)
		ApplyButtonState(self, { 0.026, 0.028, 0.032, 0.72 })
		self.label:SetTextColor(material.textDim[1], material.textDim[2], material.textDim[3], 0.55)
	end)
	button:SetScript("OnEnable", function(self)
		ApplyButtonState(self, material.control)
		self.label:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])
	end)
	return button
end

local function CreateEditBox(parent, width)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width, 24)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetTextInsets(8, 8, 0, 0)
	box:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])
	AddBackground(box, material.panelInset, material.border)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	return box
end

local function CreateCheckButton(parent, text)
	local check = CreateFrame("CheckButton", nil, parent)
	check:SetSize(22, 22)

	AddBackground(check, material.panelInset, material.border)

	check.mark = check:CreateTexture(nil, "ARTWORK")
	check.mark:SetPoint("CENTER")
	check.mark:SetSize(12, 12)
	SetVertexColor(check.mark, material.accent)
	check.mark:Hide()

	check.Text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	check.Text:SetPoint("LEFT", check, "RIGHT", 8, 0)
	check.Text:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])
	check.Text:SetText(text or "")

	check:SetScript("OnClick", function(self)
		self.mark:SetShown(self:GetChecked())
	end)

	check:HookScript("OnEnter", function(self)
		SetVertexColor(self.bg, material.controlHover)
	end)
	check:HookScript("OnLeave", function(self)
		SetVertexColor(self.bg, material.panelInset)
	end)

	local originalSetChecked = check.SetChecked
	check.SetChecked = function(self, checked)
		originalSetChecked(self, checked)
		self.mark:SetShown(checked)
	end

	return check
end

local function CreateDropdownControl(parent, width)
	local control = CreateFrame("Button", nil, parent)
	control:SetSize(width, 24)
	AddBackground(control, material.control, material.border)

	control.highlight = control:CreateTexture(nil, "HIGHLIGHT")
	control.highlight:SetAllPoints()
	SetVertexColor(control.highlight, { 0.13, 0.58, 0.82, 0.16 })

	control.text = control:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	control.text:SetPoint("LEFT", 8, 0)
	control.text:SetPoint("RIGHT", -28, 0)
	control.text:SetJustifyH("LEFT")
	control.text:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])
	if control.text.SetWordWrap then
		control.text:SetWordWrap(false)
	end

	control.arrow = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	control.arrow:SetPoint("RIGHT", -9, 0)
	control.arrow:SetTextColor(material.accent[1], material.accent[2], material.accent[3], material.accent[4])
	control.arrow:SetText("v")

	control.SetText = function(self, text)
		self.text:SetText(text or "")
	end

	return control
end

local function UpdateRuleButtons()
	if not ui then
		return
	end

	ui.typeButton:SetText(L("track", RuleTypeLabel(ui.currentRuleType)))
	ui.triggerButton:SetText(L("trigger", ui.currentTrigger or "SUCCEEDED"))
	ui.idLabel:SetText(L("spellOrBuffID", RuleTypeLabel(ui.currentRuleType)))
end

local function RefreshSoundSelector()
	if not ui then
		return
	end

	ui.soundModeButton:SetText(ui.currentSoundMode == "CUSTOM" and L("customFile") or L("soundSource"))
	ui.soundPickerButton:SetText(FormatSoundLabel(ui.currentSound))

	local custom = ui.currentSoundMode == "CUSTOM"
	ui.customSoundBox:SetShown(custom)
	ui.soundSearchBox:SetShown(not custom)
	ui.soundPickerButton:SetShown(not custom)
	if ui.soundDropdown and custom then
		ui.soundDropdown:Hide()
	end
end

local function RefreshSoundDropdown()
	if not ui or not ui.soundDropdown then
		return
	end

	local filtered = FilterSoundChoices(ui.soundSearchBox:GetText())
	local totalPages = math.max(1, math.ceil(#filtered / SOUND_ROWS_PER_PAGE))
	if ui.soundDropdownPage > totalPages then
		ui.soundDropdownPage = totalPages
	end
	if ui.soundDropdownPage < 1 then
		ui.soundDropdownPage = 1
	end

	ui.soundDropdown.pageText:SetText(ui.soundDropdownPage .. " / " .. totalPages)
	ui.soundDropdown.prev:SetEnabled(ui.soundDropdownPage > 1)
	ui.soundDropdown.next:SetEnabled(ui.soundDropdownPage < totalPages)

	for index = 1, SOUND_ROWS_PER_PAGE do
		local button = ui.soundDropdown.buttons[index]
		local choice = filtered[((ui.soundDropdownPage - 1) * SOUND_ROWS_PER_PAGE) + index]
		if choice then
			button.choice = choice
			button:SetText(choice.label)
			button:Show()
		else
			button.choice = nil
			button:Hide()
		end
	end
end

local function ToggleSoundDropdown()
	if not ui or ui.currentSoundMode == "CUSTOM" then
		return
	end

	if ui.soundDropdown:IsShown() then
		ui.soundDropdown:Hide()
	else
		ui.soundDropdownPage = 1
		RefreshSoundDropdown()
		ui.soundDropdown:Show()
	end
end

local function SetEditorSound(sound)
	sound = NormalizeSound(sound) or GetDefaultSound()
	ui.currentSound = sound

	if sound and sound.type == "file" then
		ui.currentSoundMode = "CUSTOM"
		ui.customSoundBox:SetText(sound.path or "")
	else
		ui.currentSoundMode = "BUILTIN"
	end

	RefreshSoundSelector()
end

local function GetEditorSound()
	if ui.currentSoundMode == "CUSTOM" then
		local path = NormalizePath(ui.customSoundBox:GetText())
		if not path then
			return nil
		end
		return {
			type = "file",
			path = path,
		}
	end

	return NormalizeSound(ui.currentSound)
end

local function RefreshSettingsPanel()
	if not settingsPanel then
		return
	end

	local db = DB()
	settingsPanel.enabled:SetChecked(db.enabled)
	settingsPanel.enabled.Text:SetText(L("settingsEnable"))
	settingsPanel.channelButton:SetText(L("settingsChannel", db.channel or "Master"))
	settingsPanel.openButton:SetText(L("settingsOpen"))
	settingsPanel.mappingCount:SetText(L("settingsCount", CountRules()))
	if settingsPanel.description then
		settingsPanel.description:SetText(L("settingsDescription"))
	end
	if settingsPanel.note then
		settingsPanel.note:SetText(L("settingsTip"))
	end

	local spellText = L("lastSpellNone")
	if lastSpell.id then
		spellText = L("lastSpell", (lastSpell.name or "Unknown") .. " (" .. lastSpell.id .. ")")
	end

	local auraText = L("lastBuffNone")
	if lastAura.id then
		auraText = L("lastBuff", (lastAura.name or "Unknown") .. " (" .. lastAura.id .. ")")
	end

	settingsPanel.lastSpell:SetText(spellText)
	settingsPanel.lastAura:SetText(auraText)
end

local function RefreshUI()
	if not ui then
		return
	end

	local db = DB()
	ui.enabled:SetChecked(db.enabled)
	ui.enabled.Text:SetText(L("enabled"))
	ui.channelButton:SetText(L("channel", db.channel or "Master"))
	ui.languageButton:SetText(L("language"))
	ui.profileButton:SetText(L("profile", db.activeProfile or "Default"))
	ui.exportButton:SetText(L("export"))
	ui.importButton:SetText(L("import"))
	ui.saveButton:SetText(L("addUpdate"))
	ui.previewButton:SetText(L("preview"))
	ui.useLastButton:SetText(L("useLast"))
	ui.title:SetText(L("soundEditor"))
	ui.hint:SetText(L("alertListHint"))
	ui.rulesHeader:SetText(L("rules"))
	UpdateRuleButtons()
	RefreshSoundSelector()

	if lastSpell.id then
		ui.lastSpellText:SetText(L("lastSpell", (lastSpell.name or "Unknown") .. " (" .. lastSpell.id .. ") via " .. (lastSpell.trigger or "?")))
	else
		ui.lastSpellText:SetText(L("lastSpellNone"))
	end

	if lastAura.id then
		ui.lastAuraText:SetText(L("lastBuff", (lastAura.name or "Unknown") .. " (" .. lastAura.id .. ") via " .. (lastAura.trigger or "?")))
	else
		ui.lastAuraText:SetText(L("lastBuffNone"))
	end

	local keys = SortedRuleKeys()
	local totalPages = math.max(1, math.ceil(#keys / ROWS_PER_PAGE))
	if page > totalPages then
		page = totalPages
	end
	if page < 1 then
		page = 1
	end

	ui.pageText:SetText(L("page", page, totalPages))
	ui.prevButton:SetEnabled(page > 1)
	ui.nextButton:SetEnabled(page < totalPages)

	for index = 1, ROWS_PER_PAGE do
		local row = rows[index]
		local key = keys[((page - 1) * ROWS_PER_PAGE) + index]
		local rule = key and db.rules[key]
		if rule then
			row.ruleKey = key
			row.sound = rule.sound
			row:Show()
			row.kind:SetText(RuleTypeLabel(rule.type))
			row.name:SetText((rule.name or GetSpellName(rule.id) or "Unknown") .. " (" .. rule.id .. ")")
			row.triggerText:SetText(rule.trigger or "ANY")
			row.soundText:SetText(FormatSoundLabel(rule.sound))
		else
			row.ruleKey = nil
			row.sound = nil
			row:Hide()
		end
	end
end

local function UpsertRule(ruleType, id, trigger, sound)
	id = tonumber(id)
	if not id then
		Print("Enter a numeric spell or buff ID.")
		return false
	end

	if not Contains(RULE_TYPES, ruleType) then
		ruleType = "SPELL"
	end

	local triggerList = GetTriggerList(ruleType)
	if not Contains(triggerList, trigger) then
		trigger = triggerList[1]
	end

	sound = NormalizeSound(sound)
	if not sound then
		Print("Choose an alert sound or custom sound file.")
		return false
	end

	local key = RuleKey(ruleType, id)
	DB().rules[key] = {
		type = ruleType,
		id = id,
		name = GetSpellName(id),
		trigger = trigger,
		sound = sound,
	}
	SaveCurrentProfile()

	Print("Mapped " .. RuleTypeLabel(ruleType) .. " " .. id .. " to " .. FormatSoundLabel(sound) .. ".")
	RefreshUI()
	RefreshSettingsPanel()
	return true
end

local function RemoveRule(key)
	if key and DB().rules[key] then
		DB().rules[key] = nil
		SaveCurrentProfile()
		Print("Removed rule " .. key .. ".")
	end
	RefreshUI()
	RefreshSettingsPanel()
end

local function FillEditor(ruleType, id)
	id = tonumber(id)
	if not ui or not id then
		return
	end

	if not Contains(RULE_TYPES, ruleType) then
		ruleType = "SPELL"
	end

	local key = RuleKey(ruleType, id)
	local rule = DB().rules[key]
	ui.currentRuleType = ruleType
	ui.idBox:SetText(tostring(id))
	if rule then
		ui.currentTrigger = rule.trigger or GetTriggerList(ruleType)[1]
		SetEditorSound(rule.sound)
	else
		ui.currentTrigger = GetTriggerList(ruleType)[1]
	end

	UpdateRuleButtons()
	RefreshSoundSelector()
end

local function UseLastForCurrentType()
	if ui.currentRuleType == "AURA" then
		if lastAura.id then
			FillEditor("AURA", lastAura.id)
		else
			Print("Gain a buff first, then press Use Last.")
		end
	else
		if lastSpell.id then
			FillEditor("SPELL", lastSpell.id)
		else
			Print("Cast a spell first, then press Use Last.")
		end
	end
end

local function SelectSoundChoice(choice)
	if not choice then
		return
	end

	ui.currentSound = {
		type = "lsm",
		name = choice.name,
		path = choice.path,
		label = choice.name,
	}
	ui.soundDropdown:Hide()
	RefreshSoundSelector()
end

local function CreateSoundChoiceRow(parent, width)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(width, 24)

	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	SetVertexColor(row.bg, { 0, 0, 0, 0 })

	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints()
	SetVertexColor(row.highlight, { 0.13, 0.58, 0.82, 0.2 })

	row.preview = CreateFrame("Button", nil, row)
	row.preview:SetSize(18, 18)
	row.preview:SetPoint("LEFT", 4, 0)
	AddBackground(row.preview, material.control, material.border)

	row.preview.highlight = row.preview:CreateTexture(nil, "HIGHLIGHT")
	row.preview.highlight:SetAllPoints()
	SetVertexColor(row.preview.highlight, { 0.13, 0.58, 0.82, 0.2 })

	row.preview.icon = row.preview:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	row.preview.icon:SetPoint("CENTER", 1, 0)
	row.preview.icon:SetTextColor(material.accent[1], material.accent[2], material.accent[3], material.accent[4])
	row.preview.icon:SetText(">")

	row.preview:SetScript("OnClick", function(self)
		local choice = self:GetParent().choice
		if choice then
			PlaySelectedSound({
				type = "lsm",
				name = choice.name,
				path = choice.path,
				label = choice.name,
			})
		end
	end)

	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", row.preview, "RIGHT", 8, 0)
	row.label:SetPoint("RIGHT", -8, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])
	if row.label.SetWordWrap then
		row.label:SetWordWrap(false)
	end

	row.SetText = function(self, text)
		self.label:SetText(text or "")
	end

	row:SetScript("OnClick", function(self)
		SelectSoundChoice(self.choice)
	end)

	return row
end

local function CreateSoundDropdown(parent)
	local dropdown = CreateFrame("Frame", nil, parent)
	dropdown:SetSize(540, 300)
	dropdown:SetPoint("TOPLEFT", parent.soundPickerButton, "BOTTOMLEFT", 0, -4)
	dropdown:SetFrameStrata("DIALOG")
	dropdown:SetFrameLevel(parent:GetFrameLevel() + 20)
	dropdown:Hide()
	AddBackground(dropdown, material.panel, material.borderBright)

	dropdown.buttons = {}
	for index = 1, SOUND_ROWS_PER_PAGE do
		local button = CreateSoundChoiceRow(dropdown, 516)
		button:SetPoint("TOPLEFT", 12, -10 - ((index - 1) * 25))
		dropdown.buttons[index] = button
	end

	dropdown.prev = CreateButton(dropdown, "<", 32)
	dropdown.prev:SetPoint("BOTTOMLEFT", 12, 10)
	dropdown.prev:SetScript("OnClick", function()
		ui.soundDropdownPage = ui.soundDropdownPage - 1
		RefreshSoundDropdown()
	end)

	dropdown.pageText = CreateLabel(dropdown, "1 / 1", 80)
	dropdown.pageText:SetPoint("LEFT", dropdown.prev, "RIGHT", 10, 0)

	dropdown.next = CreateButton(dropdown, ">", 32)
	dropdown.next:SetPoint("LEFT", dropdown.pageText, "RIGHT", 10, 0)
	dropdown.next:SetScript("OnClick", function()
		ui.soundDropdownPage = ui.soundDropdownPage + 1
		RefreshSoundDropdown()
	end)

	dropdown.close = CreateButton(dropdown, "Close", 70)
	dropdown.close:SetPoint("BOTTOMRIGHT", -12, 10)
	dropdown.close:SetScript("OnClick", function()
		dropdown:Hide()
	end)

	return dropdown
end

local function RefreshProfileDropdown()
	if not ui or not ui.profileDropdown then
		return
	end

	local names = GetProfileNames()
	ui.profileDropdown:SetHeight(16 + (#names * 25))

	for index, name in ipairs(names) do
		local button = ui.profileDropdown.buttons[index]
		if not button then
			button = CreateButton(ui.profileDropdown, "", 156)
			button:SetPoint("TOPLEFT", 12, -10 - ((index - 1) * 25))
			button:SetScript("OnClick", function(self)
				if self.profileName then
					SaveCurrentProfile()
					ActivateProfile(self.profileName)
					ui.profileDropdown:Hide()
					RefreshUI()
					RefreshSettingsPanel()
				end
			end)
			ui.profileDropdown.buttons[index] = button
		end

		button.profileName = name
		button:SetText(name)
		button:Show()
	end

	for index = #names + 1, #ui.profileDropdown.buttons do
		ui.profileDropdown.buttons[index]:Hide()
	end
end

local function CreateProfileDropdown(parent)
	local dropdown = CreateFrame("Frame", nil, parent)
	dropdown:SetSize(180, 41)
	dropdown:SetPoint("BOTTOMLEFT", parent.profileButton, "TOPLEFT", 0, 4)
	dropdown:SetFrameStrata("DIALOG")
	dropdown:SetFrameLevel(parent:GetFrameLevel() + 20)
	dropdown:Hide()
	AddBackground(dropdown, material.panel, material.borderBright)

	dropdown.buttons = {}

	return dropdown
end

local function ToggleProfileDropdown()
	if not ui or not ui.profileDropdown then
		return
	end

	if ui.profileDropdown:IsShown() then
		ui.profileDropdown:Hide()
	else
		RefreshProfileDropdown()
		ui.profileDropdown:Show()
	end
end

local function CreateTextDialog(name, titleKey, width, height)
	local dialog = CreateFrame("Frame", name, UIParent)
	dialog:SetSize(width, height)
	dialog:SetPoint("CENTER")
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(80)
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:Hide()
	AddBackground(dialog, material.panel, material.borderBright)

	dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	dialog.title:SetPoint("TOPLEFT", 12, -10)
	dialog.title:SetText(L(titleKey))

	dialog.close = CreateButton(dialog, "X", 26)
	dialog.close:SetPoint("TOPRIGHT", -8, -7)
	dialog.close:SetScript("OnClick", function()
		dialog:Hide()
	end)

	return dialog
end

local function ShowExportDialog(exportText)
	if not ui.exportDialog then
		local dialog = CreateTextDialog(ADDON_NAME .. "ExportDialog", "exportTitle", 640, 220)
		dialog.box = CreateEditBox(dialog, 610)
		dialog.box:SetPoint("TOPLEFT", 14, -42)
		dialog.box:SetHeight(126)
		dialog.box:SetMultiLine(true)
		dialog.box:SetMaxLetters(0)

		dialog.note = dialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		dialog.note:SetPoint("TOPLEFT", dialog.box, "BOTTOMLEFT", 0, -10)
		dialog.note:SetWidth(610)
		dialog.note:SetJustifyH("LEFT")

		ui.exportDialog = dialog
	end

	local copied = false
	if CopyToClipboard then
		local ok = pcall(CopyToClipboard, exportText)
		copied = ok
	end

	ui.exportDialog.title:SetText(L("exportTitle"))
	ui.exportDialog.box:SetText(exportText)
	ui.exportDialog.box:SetFocus()
	ui.exportDialog.box:HighlightText()
	ui.exportDialog.note:SetText(copied and L("copied") or L("copyFallback"))
	ui.exportDialog:Show()
	Print(copied and L("copied") or L("copyFallback"))
end

local function ShowImportDialog()
	if not ui.importDialog then
		local dialog = CreateTextDialog(ADDON_NAME .. "ImportDialog", "importTitle", 640, 330)

		dialog.nameLabel = CreateLabel(dialog, L("importName"), 260)
		dialog.nameLabel:SetPoint("TOPLEFT", 16, -44)
		dialog.nameBox = CreateEditBox(dialog, 608)
		dialog.nameBox:SetPoint("TOPLEFT", dialog.nameLabel, "BOTTOMLEFT", 0, -6)

		dialog.stringLabel = CreateLabel(dialog, L("importString"), 260)
		dialog.stringLabel:SetPoint("TOPLEFT", dialog.nameBox, "BOTTOMLEFT", 0, -14)
		dialog.stringBox = CreateEditBox(dialog, 608)
		dialog.stringBox:SetPoint("TOPLEFT", dialog.stringLabel, "BOTTOMLEFT", 0, -6)
		dialog.stringBox:SetHeight(142)
		dialog.stringBox:SetMultiLine(true)
		dialog.stringBox:SetMaxLetters(0)

		dialog.apply = CreateButton(dialog, L("import"), 150)
		dialog.apply:SetPoint("BOTTOMRIGHT", -16, 14)
		dialog.apply:SetScript("OnClick", function()
			local profileName = NormalizeProfileName(dialog.nameBox:GetText())
			local importString = dialog.stringBox:GetText()
			if Trim(dialog.nameBox:GetText()) == "" then
				Print(L("noImportName"))
				return
			end
			if Trim(importString) == "" then
				Print(L("noImportString"))
				return
			end

			local profile, errorMessage = DeserializeProfile(importString)
			if not profile then
				Print(errorMessage or "Could not import profile.")
				return
			end

			local db = DB()
			db.profiles[profileName] = profile
			db.activeProfile = profileName
			BindActiveProfile(db)
			ApplyMutedSoundFiles()
			auraStates = {}
			dialog:Hide()
			RefreshUI()
			RefreshSettingsPanel()
			Print(L("profileImported", profileName))
		end)

		ui.importDialog = dialog
	end

	ui.importDialog.title:SetText(L("importTitle"))
	ui.importDialog.nameLabel:SetText(L("importName"))
	ui.importDialog.stringLabel:SetText(L("importString"))
	ui.importDialog.apply:SetText(L("import"))
	ui.importDialog.nameBox:SetText("")
	ui.importDialog.stringBox:SetText("")
	ui.importDialog:Show()
	ui.importDialog.nameBox:SetFocus()
end

local function CreateUI()
	if ui then
		return ui
	end

	local frame = CreateFrame("Frame", "GameSoundChangerOptionsFrame", UIParent)
	frame:SetSize(920, 610)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	AddBackground(frame, material.panel, material.borderBright)

	frame.TitleBg = frame:CreateTexture(nil, "BORDER")
	frame.TitleBg:SetPoint("TOPLEFT", 1, -1)
	frame.TitleBg:SetPoint("TOPRIGHT", -1, -1)
	frame.TitleBg:SetHeight(30)
	SetVertexColor(frame.TitleBg, material.panelTop)

	frame.inset = CreateFrame("Frame", nil, frame)
	frame.inset:SetPoint("TOPLEFT", 10, -38)
	frame.inset:SetPoint("BOTTOMRIGHT", -10, 10)
	AddBackground(frame.inset, material.panelInset, { 0.075, 0.08, 0.09, 1 })

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 10, 0)
	frame.title:SetTextColor(material.text[1], material.text[2], material.text[3], material.text[4])
	frame.title:SetText("GameSoundChanger")

	frame.closeButton = CreateButton(frame, "X", 26)
	frame.closeButton:SetPoint("TOPRIGHT", -5, -4)
	frame.closeButton:SetScript("OnClick", function()
		frame:Hide()
	end)

	ui = frame
	ui.currentRuleType = "SPELL"
	ui.currentTrigger = "SUCCEEDED"
	ui.currentSoundMode = "BUILTIN"
	ui.currentSound = GetDefaultSound()
	ui.soundDropdownPage = 1

	ui.enabled = CreateCheckButton(frame, "Enabled")
	ui.enabled:SetPoint("TOPLEFT", 16, -34)
	ui.enabled:SetScript("OnClick", function(self)
		self.mark:SetShown(self:GetChecked())
		DB().enabled = self:GetChecked() and true or false
		SaveCurrentProfile()
		RefreshUI()
		RefreshSettingsPanel()
	end)

	ui.channelButton = CreateButton(frame, "Channel: Master", 130)
	ui.channelButton:SetPoint("LEFT", ui.enabled, "RIGHT", 95, 0)
	ui.channelButton:SetScript("OnClick", function()
		local db = DB()
		db.channel = NextValue(CHANNELS, db.channel or "Master")
		SaveCurrentProfile()
		RefreshUI()
		RefreshSettingsPanel()
	end)

	ui.languageButton = CreateButton(frame, L("language"), 150)
	ui.languageButton:SetPoint("LEFT", ui.channelButton, "RIGHT", 12, 0)
	ui.languageButton:SetScript("OnClick", function()
		local db = DB()
		db.locale = db.locale == "ko" and "en" or "ko"
		SaveCurrentProfile()
		RefreshUI()
		RefreshSettingsPanel()
	end)

	ui.lastSpellText = CreateLabel(frame, "Last spell: none yet", 420)
	ui.lastSpellText:SetPoint("TOPLEFT", 20, -70)
	ui.lastAuraText = CreateLabel(frame, "Last buff: none yet", 420)
	ui.lastAuraText:SetPoint("LEFT", ui.lastSpellText, "RIGHT", 20, 0)

	ui.typeButton = CreateButton(frame, "Track: Spell", 126)
	ui.typeButton:SetPoint("TOPLEFT", 20, -106)
	ui.typeButton:SetScript("OnClick", function()
		ui.currentRuleType = NextValue(RULE_TYPES, ui.currentRuleType or "SPELL")
		ui.currentTrigger = GetTriggerList(ui.currentRuleType)[1]
		UpdateRuleButtons()
	end)

	ui.idLabel = CreateLabel(frame, "Spell ID", 72)
	ui.idLabel:SetPoint("LEFT", ui.typeButton, "RIGHT", 12, 0)
	ui.idBox = CreateEditBox(frame, 110)
	ui.idBox:SetPoint("LEFT", ui.idLabel, "RIGHT", 4, 0)

	ui.useLastButton = CreateButton(frame, "Use Last", 86)
	ui.useLastButton:SetPoint("LEFT", ui.idBox, "RIGHT", 10, 0)
	ui.useLastButton:SetScript("OnClick", UseLastForCurrentType)

	ui.triggerButton = CreateButton(frame, "Trigger: SUCCEEDED", 160)
	ui.triggerButton:SetPoint("LEFT", ui.useLastButton, "RIGHT", 10, 0)
	ui.triggerButton:SetScript("OnClick", function()
		ui.currentTrigger = NextValue(GetTriggerList(ui.currentRuleType), ui.currentTrigger)
		UpdateRuleButtons()
	end)

	ui.soundModeButton = CreateButton(frame, "Source: Alert list", 150)
	ui.soundModeButton:SetPoint("TOPLEFT", 20, -140)
	ui.soundModeButton:SetScript("OnClick", function()
		if ui.currentSoundMode == "CUSTOM" then
			ui.currentSoundMode = "BUILTIN"
			if not NormalizeSound(ui.currentSound) or NormalizeSound(ui.currentSound).type ~= "lsm" then
				ui.currentSound = GetDefaultSound()
			end
		else
			ui.currentSoundMode = "CUSTOM"
		end
		RefreshSoundSelector()
	end)

	ui.soundSearchBox = CreateEditBox(frame, 220)
	ui.soundSearchBox:SetPoint("LEFT", ui.soundModeButton, "RIGHT", 12, 0)
	ui.soundSearchBox:SetText("")
	ui.soundSearchBox:SetScript("OnTextChanged", function()
		ui.soundDropdownPage = 1
		RefreshSoundDropdown()
	end)

	ui.soundPickerButton = CreateDropdownControl(frame, 360)
	ui.soundPickerButton:SetPoint("LEFT", ui.soundSearchBox, "RIGHT", 10, 0)
	ui.soundPickerButton:SetScript("OnClick", ToggleSoundDropdown)

	ui.customSoundBox = CreateEditBox(frame, 590)
	ui.customSoundBox:SetPoint("LEFT", ui.soundModeButton, "RIGHT", 12, 0)
	ui.customSoundBox:Hide()

	ui.previewButton = CreateButton(frame, "Preview", 76)
	ui.previewButton:SetPoint("LEFT", ui.soundPickerButton, "RIGHT", 10, 0)
	ui.previewButton:SetScript("OnClick", function()
		PlaySelectedSound(GetEditorSound())
	end)

	ui.saveButton = CreateButton(frame, "Add/Update", 96)
	ui.saveButton:SetPoint("LEFT", ui.previewButton, "RIGHT", 10, 0)
	ui.saveButton:SetScript("OnClick", function()
		UpsertRule(ui.currentRuleType, ui.idBox:GetText(), ui.currentTrigger, GetEditorSound())
	end)

	ui.hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	ui.hint:SetPoint("TOPLEFT", 184, -166)
	ui.hint:SetWidth(690)
	ui.hint:SetJustifyH("LEFT")
	ui.hint:SetText(L("alertListHint"))

	ui.rulesHeader = CreateLabel(frame, L("rules"), 100)
	ui.rulesHeader:SetPoint("TOPLEFT", 20, -202)

	ui.prevButton = CreateButton(frame, "<", 32)
	ui.prevButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -130, -198)
	ui.prevButton:SetScript("OnClick", function()
		page = page - 1
		RefreshUI()
	end)

	ui.pageText = CreateLabel(frame, "Page 1 / 1", 80)
	ui.pageText:SetPoint("LEFT", ui.prevButton, "RIGHT", 10, 0)

	ui.nextButton = CreateButton(frame, ">", 32)
	ui.nextButton:SetPoint("LEFT", ui.pageText, "RIGHT", 10, 0)
	ui.nextButton:SetScript("OnClick", function()
		page = page + 1
		RefreshUI()
	end)

	for index = 1, ROWS_PER_PAGE do
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(880, 32)
		row:SetPoint("TOPLEFT", 20, -230 - ((index - 1) * 34))

		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		if index % 2 == 0 then
			SetVertexColor(row.bg, material.rowEven)
		else
			SetVertexColor(row.bg, material.rowOdd)
		end
		AddBorder(row, { 0.07, 0.075, 0.085, 0.95 })

		row.kind = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.kind:SetPoint("LEFT", 8, 0)
		row.kind:SetWidth(56)
		row.kind:SetJustifyH("LEFT")

		row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.name:SetPoint("LEFT", row.kind, "RIGHT", 8, 0)
		row.name:SetWidth(215)
		row.name:SetJustifyH("LEFT")

		row.triggerText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.triggerText:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
		row.triggerText:SetWidth(96)
		row.triggerText:SetJustifyH("LEFT")

		row.soundText = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		row.soundText:SetPoint("LEFT", row.triggerText, "RIGHT", 8, 0)
		row.soundText:SetWidth(330)
		row.soundText:SetJustifyH("LEFT")
		if row.soundText.SetWordWrap then
			row.soundText:SetWordWrap(false)
		end

		row.preview = CreateButton(row, "Play", 52)
		row.preview:SetPoint("RIGHT", row, "RIGHT", -130, 0)
		row.preview:SetScript("OnClick", function(self)
			if self:GetParent().sound then
				PlaySelectedSound(self:GetParent().sound)
			end
		end)

		row.edit = CreateButton(row, "Edit", 52)
		row.edit:SetPoint("LEFT", row.preview, "RIGHT", 6, 0)
		row.edit:SetScript("OnClick", function(self)
			local rule = DB().rules[self:GetParent().ruleKey]
			if rule then
				FillEditor(rule.type, rule.id)
			end
		end)

		row.remove = CreateButton(row, "Del", 52)
		row.remove:SetPoint("LEFT", row.edit, "RIGHT", 6, 0)
		row.remove:SetScript("OnClick", function(self)
			RemoveRule(self:GetParent().ruleKey)
		end)

		rows[index] = row
	end

	ui.soundDropdown = CreateSoundDropdown(frame)

	ui.profileButton = CreateDropdownControl(frame, 180)
	ui.profileButton:SetPoint("BOTTOMLEFT", 20, 18)
	ui.profileButton:SetScript("OnClick", ToggleProfileDropdown)

	ui.exportButton = CreateButton(frame, L("export"), 150)
	ui.exportButton:SetPoint("LEFT", ui.profileButton, "RIGHT", 10, 0)
	ui.exportButton:SetScript("OnClick", function()
		SaveCurrentProfile()
		ShowExportDialog(SerializeProfile(DB().profiles[DB().activeProfile]))
	end)

	ui.importButton = CreateButton(frame, L("import"), 150)
	ui.importButton:SetPoint("LEFT", ui.exportButton, "RIGHT", 10, 0)
	ui.importButton:SetScript("OnClick", ShowImportDialog)

	ui.profileDropdown = CreateProfileDropdown(frame)

	RefreshUI()
	return ui
end

local function ToggleUI()
	local frame = CreateUI()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		if frame.Raise then
			frame:Raise()
		end
		RefreshUI()
	end
end

local function ShowUI()
	local frame = CreateUI()
	frame:Show()
	if frame.Raise then
		frame:Raise()
	end
	RefreshUI()
end

local function OpenSettingsCategory()
	if settingsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(settingsCategory.ID)
	else
		ShowUI()
	end
end

local function RegisterSettingsPanel()
	if settingsPanel then
		return
	end

	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
		return
	end

	local panel = CreateFrame("Frame", ADDON_NAME .. "SettingsPanel")
	panel.name = "GameSoundChanger"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("GameSoundChanger")

	local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	description:SetWidth(620)
	description:SetJustifyH("LEFT")
	description:SetText("Choose player spells or player buff activations, then play named alert sounds from LibSharedMedia or custom audio.")
	panel.description = description

	panel.enabled = CreateCheckButton(panel, "Enable custom sounds")
	panel.enabled:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
	panel.enabled:SetScript("OnClick", function(self)
		self.mark:SetShown(self:GetChecked())
		DB().enabled = self:GetChecked() and true or false
		SaveCurrentProfile()
		RefreshUI()
		RefreshSettingsPanel()
	end)

	panel.channelButton = CreateButton(panel, "Sound channel: Master", 180)
	panel.channelButton:SetPoint("TOPLEFT", panel.enabled, "BOTTOMLEFT", 4, -10)
	panel.channelButton:SetScript("OnClick", function()
		local db = DB()
		db.channel = NextValue(CHANNELS, db.channel or "Master")
		SaveCurrentProfile()
		RefreshUI()
		RefreshSettingsPanel()
	end)

	panel.openButton = CreateButton(panel, "Open Sound Editor", 170)
	panel.openButton:SetPoint("TOPLEFT", panel.channelButton, "BOTTOMLEFT", 0, -16)
	panel.openButton:SetScript("OnClick", ShowUI)

	panel.mappingCount = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	panel.mappingCount:SetPoint("TOPLEFT", panel.openButton, "BOTTOMLEFT", 0, -18)
	panel.mappingCount:SetWidth(420)
	panel.mappingCount:SetJustifyH("LEFT")

	panel.lastSpell = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	panel.lastSpell:SetPoint("TOPLEFT", panel.mappingCount, "BOTTOMLEFT", 0, -8)
	panel.lastSpell:SetWidth(620)
	panel.lastSpell:SetJustifyH("LEFT")

	panel.lastAura = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	panel.lastAura:SetPoint("TOPLEFT", panel.lastSpell, "BOTTOMLEFT", 0, -8)
	panel.lastAura:SetWidth(620)
	panel.lastAura:SetJustifyH("LEFT")

	local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", panel.lastAura, "BOTTOMLEFT", 0, -18)
	note:SetWidth(620)
	note:SetJustifyH("LEFT")
	note:SetText("Tip: cast a spell or gain a buff, open the sound editor, press Use Last, then choose an alert sound.")
	panel.note = note

	panel:SetScript("OnShow", RefreshSettingsPanel)

	settingsPanel = panel
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name, panel.name)
	category.ID = ADDON_NAME
	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
	RefreshSettingsPanel()
end

local function ShowHelp()
	Print("/gsc - open sound editor")
	Print("/gsc menu - open the WoW AddOns settings page")
	Print("/gsc on | off - enable or disable custom sounds")
	Print("/gsc add <spellID> <soundFile> - legacy custom-file spell rule")
	Print("/gsc addbuff <buffID> <soundFile> - legacy custom-file buff rule")
	Print("/gsc addlast <soundFile> - map the last detected player spell")
	Print("/gsc addlastbuff <soundFile> - map the last detected player buff")
	Print("/gsc remove SPELL:<id> | AURA:<id> - remove a rule")
	Print("/gsc mute <fileID> - mute a Blizzard sound file ID")
	Print("/gsc unmute <fileID> - unmute a Blizzard sound file ID")
	Print("/gsc last - show the last detected spell and buff")
end

local function HandleSlash(message)
	message = Trim(message)
	if message == "" then
		ToggleUI()
		return
	end

	local command, rest = message:match("^(%S+)%s*(.*)$")
	command = string.lower(command or "")
	rest = Trim(rest)

	if command == "help" then
		ShowHelp()
	elseif command == "menu" or command == "options" or command == "config" then
		OpenSettingsCategory()
	elseif command == "on" then
		DB().enabled = true
		SaveCurrentProfile()
		Print(L("enabledMessage"))
		RefreshUI()
		RefreshSettingsPanel()
	elseif command == "off" then
		DB().enabled = false
		SaveCurrentProfile()
		Print(L("disabled"))
		RefreshUI()
		RefreshSettingsPanel()
	elseif command == "last" then
		if lastSpell.id then
			Print("Last spell: " .. (lastSpell.name or "Unknown") .. " (" .. lastSpell.id .. ") via " .. (lastSpell.trigger or "?"))
		else
			Print("Last spell: none yet.")
		end
		if lastAura.id then
			Print("Last buff: " .. (lastAura.name or "Unknown") .. " (" .. lastAura.id .. ") via " .. (lastAura.trigger or "?"))
		else
			Print("Last buff: none yet.")
		end
	elseif command == "add" then
		local spellID, path = rest:match("^(%d+)%s+(.+)$")
		UpsertRule("SPELL", spellID, "SUCCEEDED", { type = "file", path = path })
	elseif command == "addbuff" then
		local auraID, path = rest:match("^(%d+)%s+(.+)$")
		UpsertRule("AURA", auraID, "APPLIED", { type = "file", path = path })
	elseif command == "addlast" then
		if lastSpell.id then
			UpsertRule("SPELL", lastSpell.id, lastSpell.trigger or "SUCCEEDED", { type = "file", path = rest })
		else
			Print("No player spell detected yet.")
		end
	elseif command == "addlastbuff" then
		if lastAura.id then
			UpsertRule("AURA", lastAura.id, lastAura.trigger or "APPLIED", { type = "file", path = rest })
		else
			Print("No player buff detected yet.")
		end
	elseif command == "remove" or command == "delete" or command == "del" then
		if string.find(rest, ":", 1, true) then
			RemoveRule(string.upper(rest))
		else
			RemoveRule(RuleKey("SPELL", rest))
		end
	elseif command == "mute" then
		local fileID = tonumber(rest)
		if fileID and MuteSoundFile then
			DB().mutedSoundFileIDs[fileID] = true
			MuteSoundFile(fileID)
			SaveCurrentProfile()
			Print("Muted sound file ID " .. fileID .. ".")
		else
			Print("Enter a numeric sound file ID.")
		end
	elseif command == "unmute" then
		local fileID = tonumber(rest)
		if fileID and UnmuteSoundFile then
			DB().mutedSoundFileIDs[fileID] = nil
			UnmuteSoundFile(fileID)
			SaveCurrentProfile()
			Print("Unmuted sound file ID " .. fileID .. ".")
		else
			Print("Enter a numeric sound file ID.")
		end
	else
		ShowHelp()
	end
end

local function HandleSpellEvent(event, unit, castGUID, spellID)
	if unit ~= "player" then
		return
	end

	spellID = tonumber(spellID)
	if not spellID then
		return
	end

	local trigger = EVENT_TO_TRIGGER[event]
	local name = GetSpellName(spellID)
	lastSpell.id = spellID
	lastSpell.name = name
	lastSpell.trigger = trigger

	if ui then
		RefreshUI()
	end
	RefreshSettingsPanel()

	local rule = DB().rules[RuleKey("SPELL", spellID)]
	if DB().enabled and rule and TriggerMatches(rule.trigger, trigger) then
		PlaySelectedSound(rule.sound)
	end
end

local function HandlePlayerAura(spellID, spellName, trigger, processed)
	spellID = SafeNumber(spellID)
	if not spellID then
		return
	end

	local key = RuleKey("AURA", spellID)
	if processed and processed[key] then
		return
	end
	if processed then
		processed[key] = true
	end

	lastAura.id = spellID
	lastAura.name = spellName or GetSpellName(spellID)
	lastAura.trigger = trigger

	if ui then
		RefreshUI()
	end
	RefreshSettingsPanel()

	local rule = DB().rules[key]
	if DB().enabled and rule and TriggerMatches(rule.trigger, trigger) then
		PlaySelectedSound(rule.sound)
	end
end

local function ScanPlayerAuras(processed)
	local active = {}

	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for index = 1, 80 do
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
			if not ok or not aura then
				break
			end

					local spellID = SafeNumber(aura.spellId)
			if spellID then
				active[spellID] = true
				if not auraStates[spellID] then
					HandlePlayerAura(spellID, aura.name, "APPLIED", processed)
				end
			end
		end
	elseif UnitAura then
		for index = 1, 80 do
			local name, _, _, _, _, _, _, _, _, spellID = UnitAura("player", index, "HELPFUL")
			if not name then
				break
			end
			spellID = SafeNumber(spellID)
			if spellID then
				active[spellID] = true
				if not auraStates[spellID] then
					HandlePlayerAura(spellID, name, "APPLIED", processed)
				end
			end
		end
	end

	auraStates = active
end

local function HandleUnitAura(unit, updateInfo)
	if unit ~= "player" then
		return
	end

	local processed = {}
	if type(updateInfo) == "table" then
		if type(updateInfo.addedAuras) == "table" then
			for _, aura in ipairs(updateInfo.addedAuras) do
				if aura and aura.isHelpful ~= false then
					HandlePlayerAura(aura.spellId, aura.name, "APPLIED", processed)
				end
			end
		end

		if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID and type(updateInfo.updatedAuraInstanceIDs) == "table" then
			for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
				local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", auraInstanceID)
				if ok and aura and aura.isHelpful ~= false then
					HandlePlayerAura(aura.spellId, aura.name, "REFRESH", processed)
				end
			end
		end
	end

	ScanPlayerAuras(processed)
end

addon:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loadedName = ...
		if loadedName == ADDON_NAME then
			DB()
			MigrateLegacyMappings()
			ApplyMutedSoundFiles()
			RegisterSettingsPanel()
		end
	elseif event == "PLAYER_LOGIN" then
		RegisterSettingsPanel()
		Print("Type /gsc to open the sound editor, or /gsc menu for AddOns settings.")
	elseif EVENT_TO_TRIGGER[event] then
		HandleSpellEvent(event, ...)
	elseif event == "UNIT_AURA" then
		HandleUnitAura(...)
	end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("UNIT_SPELLCAST_START")
addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
addon:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
addon:RegisterUnitEvent("UNIT_AURA", "player")

SLASH_GAMESOUNDCHANGER1 = "/gsc"
SLASH_GAMESOUNDCHANGER2 = "/gamesoundchanger"
SlashCmdList.GAMESOUNDCHANGER = HandleSlash
