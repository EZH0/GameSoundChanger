local ADDON_NAME = ...
if not ADDON_NAME or ADDON_NAME == "" then
	ADDON_NAME = "GameSoundChanger"
end

local PREFIX = "|cff66ccffGameSoundChanger:|r "
local BASE_SOUND_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"
local ROWS_PER_PAGE = 8
local SOUND_ROWS_PER_PAGE = 10

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
	rules = {},
	mappings = {},
	mutedSoundFileIDs = {},
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

local function DB()
	if type(GameSoundChangerDB) ~= "table" then
		GameSoundChangerDB = {}
	end
	CopyDefaults(defaults, GameSoundChangerDB)
	return GameSoundChangerDB
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
	spellID = tonumber(spellID)
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
		return "Buff"
	end
	return "Spell"
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

local function ApplyMutedSoundFiles()
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
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 96, 24)
	button:SetText(text)
	return button
end

local function CreateEditBox(parent, width)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(width, 24)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	return box
end

local function CreateDropdownControl(parent, width)
	local control = CreateFrame("Button", nil, parent)
	control:SetSize(width, 24)

	control.bg = control:CreateTexture(nil, "BACKGROUND")
	control.bg:SetAllPoints()
	control.bg:SetColorTexture(0.055, 0.055, 0.065, 0.95)

	control.highlight = control:CreateTexture(nil, "HIGHLIGHT")
	control.highlight:SetAllPoints()
	control.highlight:SetColorTexture(0.22, 0.28, 0.34, 0.22)

	control.leftBorder = control:CreateTexture(nil, "BORDER")
	control.leftBorder:SetPoint("TOPLEFT")
	control.leftBorder:SetPoint("BOTTOMLEFT")
	control.leftBorder:SetWidth(1)
	control.leftBorder:SetColorTexture(0.42, 0.42, 0.45, 1)

	control.rightBorder = control:CreateTexture(nil, "BORDER")
	control.rightBorder:SetPoint("TOPRIGHT")
	control.rightBorder:SetPoint("BOTTOMRIGHT")
	control.rightBorder:SetWidth(1)
	control.rightBorder:SetColorTexture(0.42, 0.42, 0.45, 1)

	control.topBorder = control:CreateTexture(nil, "BORDER")
	control.topBorder:SetPoint("TOPLEFT")
	control.topBorder:SetPoint("TOPRIGHT")
	control.topBorder:SetHeight(1)
	control.topBorder:SetColorTexture(0.42, 0.42, 0.45, 1)

	control.bottomBorder = control:CreateTexture(nil, "BORDER")
	control.bottomBorder:SetPoint("BOTTOMLEFT")
	control.bottomBorder:SetPoint("BOTTOMRIGHT")
	control.bottomBorder:SetHeight(1)
	control.bottomBorder:SetColorTexture(0.42, 0.42, 0.45, 1)

	control.text = control:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	control.text:SetPoint("LEFT", 8, 0)
	control.text:SetPoint("RIGHT", -28, 0)
	control.text:SetJustifyH("LEFT")
	if control.text.SetWordWrap then
		control.text:SetWordWrap(false)
	end

	control.arrow = control:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	control.arrow:SetPoint("RIGHT", -9, 0)
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

	ui.typeButton:SetText("Track: " .. RuleTypeLabel(ui.currentRuleType))
	ui.triggerButton:SetText("Trigger: " .. (ui.currentTrigger or "SUCCEEDED"))
	ui.idLabel:SetText(RuleTypeLabel(ui.currentRuleType) .. " ID")
end

local function RefreshSoundSelector()
	if not ui then
		return
	end

	ui.soundModeButton:SetText(ui.currentSoundMode == "CUSTOM" and "Source: Custom file" or "Source: Alert list")
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
	settingsPanel.channelButton:SetText("Sound channel: " .. (db.channel or "Master"))
	settingsPanel.mappingCount:SetText("Saved rules: " .. CountRules())

	local spellText = "Last spell: none yet"
	if lastSpell.id then
		spellText = "Last spell: " .. (lastSpell.name or "Unknown") .. " (" .. lastSpell.id .. ")"
	end

	local auraText = "Last buff: none yet"
	if lastAura.id then
		auraText = "Last buff: " .. (lastAura.name or "Unknown") .. " (" .. lastAura.id .. ")"
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
	ui.channelButton:SetText("Channel: " .. (db.channel or "Master"))
	UpdateRuleButtons()
	RefreshSoundSelector()

	if lastSpell.id then
		ui.lastSpellText:SetText("Last spell: " .. (lastSpell.name or "Unknown") .. " (" .. lastSpell.id .. ") via " .. (lastSpell.trigger or "?"))
	else
		ui.lastSpellText:SetText("Last spell: none yet")
	end

	if lastAura.id then
		ui.lastAuraText:SetText("Last buff: " .. (lastAura.name or "Unknown") .. " (" .. lastAura.id .. ") via " .. (lastAura.trigger or "?"))
	else
		ui.lastAuraText:SetText("Last buff: none yet")
	end

	local keys = SortedRuleKeys()
	local totalPages = math.max(1, math.ceil(#keys / ROWS_PER_PAGE))
	if page > totalPages then
		page = totalPages
	end
	if page < 1 then
		page = 1
	end

	ui.pageText:SetText("Page " .. page .. " / " .. totalPages)
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

	Print("Mapped " .. RuleTypeLabel(ruleType) .. " " .. id .. " to " .. FormatSoundLabel(sound) .. ".")
	RefreshUI()
	RefreshSettingsPanel()
	return true
end

local function RemoveRule(key)
	if key and DB().rules[key] then
		DB().rules[key] = nil
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
	row.bg:SetColorTexture(0, 0, 0, 0)

	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(0.18, 0.24, 0.3, 0.55)

	row.preview = CreateFrame("Button", nil, row)
	row.preview:SetSize(18, 18)
	row.preview:SetPoint("LEFT", 4, 0)

	row.preview.bg = row.preview:CreateTexture(nil, "BACKGROUND")
	row.preview.bg:SetAllPoints()
	row.preview.bg:SetColorTexture(0.08, 0.08, 0.09, 0.95)

	row.preview.highlight = row.preview:CreateTexture(nil, "HIGHLIGHT")
	row.preview.highlight:SetAllPoints()
	row.preview.highlight:SetColorTexture(0.24, 0.32, 0.38, 0.55)

	row.preview.icon = row.preview:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	row.preview.icon:SetPoint("CENTER", 1, 0)
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

	dropdown.bg = dropdown:CreateTexture(nil, "BACKGROUND")
	dropdown.bg:SetAllPoints()
	dropdown.bg:SetColorTexture(0.035, 0.035, 0.04, 0.96)

	dropdown.leftBorder = dropdown:CreateTexture(nil, "BORDER")
	dropdown.leftBorder:SetPoint("TOPLEFT")
	dropdown.leftBorder:SetPoint("BOTTOMLEFT")
	dropdown.leftBorder:SetWidth(1)
	dropdown.leftBorder:SetColorTexture(0.34, 0.34, 0.38, 1)

	dropdown.rightBorder = dropdown:CreateTexture(nil, "BORDER")
	dropdown.rightBorder:SetPoint("TOPRIGHT")
	dropdown.rightBorder:SetPoint("BOTTOMRIGHT")
	dropdown.rightBorder:SetWidth(1)
	dropdown.rightBorder:SetColorTexture(0.34, 0.34, 0.38, 1)

	dropdown.topBorder = dropdown:CreateTexture(nil, "BORDER")
	dropdown.topBorder:SetPoint("TOPLEFT")
	dropdown.topBorder:SetPoint("TOPRIGHT")
	dropdown.topBorder:SetHeight(1)
	dropdown.topBorder:SetColorTexture(0.34, 0.34, 0.38, 1)

	dropdown.bottomBorder = dropdown:CreateTexture(nil, "BORDER")
	dropdown.bottomBorder:SetPoint("BOTTOMLEFT")
	dropdown.bottomBorder:SetPoint("BOTTOMRIGHT")
	dropdown.bottomBorder:SetHeight(1)
	dropdown.bottomBorder:SetColorTexture(0.34, 0.34, 0.38, 1)

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

local function CreateUI()
	if ui then
		return ui
	end

	local frame = CreateFrame("Frame", "GameSoundChangerOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(920, 610)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
	frame.title:SetText("GameSoundChanger")

	ui = frame
	ui.currentRuleType = "SPELL"
	ui.currentTrigger = "SUCCEEDED"
	ui.currentSoundMode = "BUILTIN"
	ui.currentSound = GetDefaultSound()
	ui.soundDropdownPage = 1

	ui.enabled = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	ui.enabled:SetPoint("TOPLEFT", 16, -34)
	ui.enabled.Text:SetText("Enabled")
	ui.enabled:SetScript("OnClick", function(self)
		DB().enabled = self:GetChecked() and true or false
		RefreshUI()
		RefreshSettingsPanel()
	end)

	ui.channelButton = CreateButton(frame, "Channel: Master", 130)
	ui.channelButton:SetPoint("LEFT", ui.enabled, "RIGHT", 95, 0)
	ui.channelButton:SetScript("OnClick", function()
		local db = DB()
		db.channel = NextValue(CHANNELS, db.channel or "Master")
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

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 184, -166)
	hint:SetWidth(690)
	hint:SetJustifyH("LEFT")
	hint:SetText("Alert list sounds come from LibSharedMedia, the same source used by ElvUI chat alerts. Custom files still go in Interface\\AddOns\\GameSoundChanger\\Sounds.")

	local header = CreateLabel(frame, "Rules", 100)
	header:SetPoint("TOPLEFT", 20, -202)

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
			row.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
		else
			row.bg:SetColorTexture(0.05, 0.05, 0.05, 0.25)
		end

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

	panel.enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	panel.enabled:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
	panel.enabled.Text:SetText("Enable custom sounds")
	panel.enabled:SetScript("OnClick", function(self)
		DB().enabled = self:GetChecked() and true or false
		RefreshUI()
		RefreshSettingsPanel()
	end)

	panel.channelButton = CreateButton(panel, "Sound channel: Master", 180)
	panel.channelButton:SetPoint("TOPLEFT", panel.enabled, "BOTTOMLEFT", 4, -10)
	panel.channelButton:SetScript("OnClick", function()
		local db = DB()
		db.channel = NextValue(CHANNELS, db.channel or "Master")
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
		Print("Enabled.")
		RefreshUI()
		RefreshSettingsPanel()
	elseif command == "off" then
		DB().enabled = false
		Print("Disabled.")
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
			Print("Muted sound file ID " .. fileID .. ".")
		else
			Print("Enter a numeric sound file ID.")
		end
	elseif command == "unmute" then
		local fileID = tonumber(rest)
		if fileID and UnmuteSoundFile then
			DB().mutedSoundFileIDs[fileID] = nil
			UnmuteSoundFile(fileID)
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

local function HandleCombatLogEvent()
	if not CombatLogGetCurrentEventInfo then
		return
	end

	local _, subevent, _, _, _, _, _, destGUID, _, _, _, spellID, spellName, _, auraType = CombatLogGetCurrentEventInfo()
	if auraType ~= "BUFF" then
		return
	end
	if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_AURA_REFRESH" then
		return
	end
	if destGUID ~= UnitGUID("player") then
		return
	end

	spellID = tonumber(spellID)
	if not spellID then
		return
	end

	local trigger = subevent == "SPELL_AURA_REFRESH" and "REFRESH" or "APPLIED"
	lastAura.id = spellID
	lastAura.name = spellName or GetSpellName(spellID)
	lastAura.trigger = trigger

	if ui then
		RefreshUI()
	end
	RefreshSettingsPanel()

	local rule = DB().rules[RuleKey("AURA", spellID)]
	if DB().enabled and rule and TriggerMatches(rule.trigger, trigger) then
		PlaySelectedSound(rule.sound)
	end
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
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		HandleCombatLogEvent()
	end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("UNIT_SPELLCAST_START")
addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
addon:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

SLASH_GAMESOUNDCHANGER1 = "/gsc"
SLASH_GAMESOUNDCHANGER2 = "/gamesoundchanger"
SlashCmdList.GAMESOUNDCHANGER = HandleSlash
