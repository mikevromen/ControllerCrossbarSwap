local _, CCS = ...

local Debug = {}

local function OnOff(value)
	return value and "|cff00ff00on|r" or "|cffff4040off|r"
end

-- Prints who currently owns each PAD key combination (including override bindings).
function Debug:PrintKeys()
	local Controller = CCS.Controller
	local keys = {}
	for _, key in ipairs(Controller.SLOT_KEYS) do keys[#keys + 1] = key end
	keys[#keys + 1] = Controller.TRIGGER_LEFT
	keys[#keys + 1] = Controller.TRIGGER_RIGHT

	CCS.Print("Key owners (override-aware):")
	for _, prefix in ipairs({ "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }) do
		local parts = {}
		for _, key in ipairs(keys) do
			local action = GetBindingAction(prefix .. key, true)
			action = (action == "" and "-") or action:gsub("^CLICK ", ""):gsub(":LeftButton$", "")
			parts[#parts + 1] = Controller:GetLabel(key) .. "=" .. action
		end
		print((prefix == "" and "none" or prefix) .. ": " .. table.concat(parts, "  "))
	end
end

function Debug:PrintStatus()
	local db, header = CCS.db, CCS.Bindings.header
	CCS.Print(("v%s  active=%s  gamepadUI=%s  blizzardUIFocus=%s  suspended=%s  combat=%s"):format(
		tostring(CCS.version), OnOff(CCS.active), OnOff(CCS.IsGamepadUI()),
		OnOff(CCS.Blizzard:IsBlizzardUIFocused()), OnOff(CCS.Bindings.suspended), OnOff(InCombatLockdown())))
	CCS.Print(("latch=%s  activeBar=%s  hideBlizzardBar=%s  manageModifiers=%s  resetBarAfterCombat=%s  suspendToggles=%d"):format(
		OnOff(db.latch), tostring(header:GetAttribute("active-bar")), OnOff(db.hideBlizzardBar), OnOff(db.manageModifiers),
		OnOff(db.resetBarAfterCombat), CCS.Bindings.suspendToggles or 0))
	CCS.Print(("GamePadEmulateShift=%s  GamePadEmulateCtrl=%s  tapWindow=%sms  firstGamepadSlot=%s"):format(
		GetCVar("GamePadEmulateShift"), GetCVar("GamePadEmulateCtrl"), GetCVar("GamePadEmulateTapWindowMs"),
		tostring(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex())))
end

local TOGGLES = {
	latch = "latch",
	blizzbar = "hideBlizzardBar",
	mods = "manageModifiers",
	focus = "focusWatch", -- debug: step aside for Blizzard UI focus (default on)
}

local function Reapply()
	CCS.RunOutOfCombat("Debug:Reapply", function()
		if not CCS.active then return end
		for _, module in ipairs(CCS.modules) do
			if module.Disable then module:Disable() end
		end
		for _, module in ipairs(CCS.modules) do
			if module.Enable then module:Enable() end
		end
	end)
end

SLASH_CCS1 = "/ccs"
SLASH_CCS2 = "/wfce" -- old name, kept as an alias
SlashCmdList.CCS = function(msg)
	local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
	if cmd == "keys" then
		-- Typing in chat gives chat gamepad focus (our bindings step aside), so allow a delayed capture.
		local delay = tonumber(arg)
		if delay then
			CCS.Print("Capturing key owners in " .. delay .. "s - close chat now.")
			C_Timer.After(delay, function() Debug:PrintKeys() end)
		else
			Debug:PrintKeys()
		end
	elseif TOGGLES[cmd] then
		local field = TOGGLES[cmd]
		if arg == "on" or arg == "off" then
			CCS.db[field] = arg == "on"
		else
			CCS.db[field] = not CCS.db[field]
		end
		CCS.Print(field .. " = " .. OnOff(CCS.db[field]))
		Reapply()
	elseif cmd == "reapply" then
		Reapply()
	elseif cmd == "options" or cmd == "config" then
		CCS.Options:Open()
	elseif cmd == "" or cmd == "status" then
		Debug:PrintStatus()
		CCS.Print("Commands: /ccs options | status | keys [delaySeconds] | latch [on|off] | blizzbar [on|off] | mods [on|off] | focus [on|off] | reapply")
	else
		CCS.Print("Unknown command: " .. cmd)
	end
end

CCS.RegisterModule("Debug", Debug)
