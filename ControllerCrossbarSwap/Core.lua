local addonName, CCS = ...
_G.ControllerCrossbarSwap = CCS -- exposed for /run debugging; never read by Blizzard code (a short global like CCS could collide)

CCS.name = addonName
CCS.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

local DEFAULTS = {
	latch = true,             -- tap LT/RT to latch a bar
	resetBarAfterCombat = false, -- switch the latched bar back to the default bar when combat ends
	rotateBars = false,       -- rotate bar positions so the latched bar sits in the main (top) slot
	animateRotation = true,   -- glide bars to their new slot when rotating
	showDefaultBarIndicator = true, -- icon above the default bar (follows it when rotating)
	defaultBarIcon = "star",  -- key into Bars.INDICATOR_ICONS
	inactiveBarSize = "normal", -- key into Bars.INACTIVE_SIZES (scale of the not-active bars)
	hideBlizzardBar = true,   -- fade out Blizzard's crossbar (it is protected, so alpha only)
	manageModifiers = true,   -- set GamePadEmulateShift/Ctrl to LT/RT while active
	focusWatch = true,        -- clear our bindings while Blizzard UI has gamepad focus (/ccs focus to toggle)
	followBlizzardPosition = true, -- anchor to Blizzard's crossbar (its Edit Mode position and scale)
	scale = 1,                    -- multiplier on top of that scale
	point = { "BOTTOM", "UIParent", "BOTTOM", 0, 90 }, -- used when not following Blizzard's position
}

CCS.DEFAULTS = DEFAULTS

local function ApplyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			db[k] = type(v) == "table" and CopyTable(v) or v
		end
	end
	return db
end

function CCS.Print(...)
	print("|cff33ff99CCS|r", ...)
end

-- Work that touches protected frames or bindings waits until combat ends.
local afterCombat = {}
function CCS.RunOutOfCombat(key, fn)
	if InCombatLockdown() then
		afterCombat[key] = fn
	else
		fn()
	end
end

-- Modules register handlers here; Core owns the single event frame.
local eventFrame = CreateFrame("Frame")
local handlers = {}
function CCS.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		eventFrame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_REGEN_ENABLED" then
		for key, fn in pairs(afterCombat) do
			afterCombat[key] = nil
			fn()
		end
	end
	for _, fn in ipairs(handlers[event] or {}) do
		fn(event, ...)
	end
end)
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

function CCS.IsGamepadUI()
	return C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

-- Enable/disable follows Blizzard's interface style. Modules implement Enable/Disable.
CCS.modules = {}
function CCS.RegisterModule(name, module)
	CCS.modules[#CCS.modules + 1] = module
	module.name = name
	CCS[name] = module
end

local function SetActive(active)
	if CCS.active == active then
		return
	end
	CCS.RunOutOfCombat("SetActive", function()
		CCS.active = active
		for _, module in ipairs(CCS.modules) do
			local fn = active and module.Enable or module.Disable
			if fn then fn(module) end
		end
	end)
end

CCS.On("PLAYER_LOGIN", function()
	-- Migration from the addon's old name (WoWF Controller Extended). SavedVariables files are keyed by addon folder,
	-- so WFCE_DB only loads if the old WoWFControllerExtended.lua file was copied to ControllerCrossbarSwap.lua.
	if CCS_DB == nil and type(WFCE_DB) == "table" then
		CCS_DB = WFCE_DB
	end
	WFCE_DB = nil

	CCS.db = ApplyDefaults(CCS_DB or {}, DEFAULTS)
	CCS.db.optionsPage = nil -- removed debug setting (2026-10-09 freeze investigation)
	CCS_DB = CCS.db
	CCS.charDB = CCS_CharDB or {}
	CCS_CharDB = CCS.charDB

	for _, module in ipairs(CCS.modules) do
		if module.Init then module:Init() end
	end

	-- InputUtil runs these through secureexecuterange, so our code can't taint Blizzard's other subscribers.
	InputUtil.RegisterForInterfaceTransitions(CCS)
	InputUtil.RegisterGamepadInit(CCS, function() SetActive(true) end)
	InputUtil.RegisterGamepadUninit(CCS, function() SetActive(false) end)
end)
