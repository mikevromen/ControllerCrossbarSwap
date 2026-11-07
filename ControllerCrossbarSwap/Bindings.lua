local _, CCS = ...

local Bindings = {}

local MODIFIER_PREFIXES = { "", "SHIFT-", "CTRL-", "CTRL-SHIFT-" }

-- Tapping a trigger steps the latched bar through a cycle; LT walks it in the opposite direction.
-- RT: top -> right -> bottom -> left -> top    LT: top -> left -> bottom -> right -> top
local CYCLE = {
	right = { top = "right", right = "bottom", bottom = "left", left = "top" },
	left = { top = "left", left = "bottom", bottom = "right", right = "top" },
}

-- Runs in the restricted environment (self = header handle). Rebinds the bare D-pad/face keys to the
-- latched bar; on the top bar only the D-pad is bound and its face buttons fall through to Blizzard.
-- While Blizzard shows an LB / RB targeting bar, all bare keys fall through, so Blizzard's GAMEPADACTIONBUTTON
-- bindings press that bar (party / raid targeting, markers, pages, bags ...). "blizz-targeting" tells Layout.
local APPLY_LAYER = [=[
	local bar = self:GetAttribute("active-bar") or "top"

	local targeting = nil
	if self:GetAttribute("targeting-bars") then
		for w = 1, self:GetAttribute("targeting-watch-count") or 0 do
			local watch = self:GetFrameRef("targeting-watch-" .. w)
			if watch and watch:IsVisible() then
				targeting = true
			end
		end
	end
	self:SetAttribute("blizz-targeting", targeting)

	if self:GetAttribute("enabled") and not self:GetAttribute("suspended") then
		for i = 1, 8 do
			local key = self:GetAttribute("key-" .. i)
			local target = not targeting and self:GetAttribute("button-" .. bar .. "-" .. i)
			if target then
				self:SetBindingClick(true, key, target)
			else
				self:ClearBinding(key)
			end
		end
	end

	self:RunAttribute("Layout")
]=]

-- Pre-click wrapper for the LT/RT latch buttons (self = latch button, owner = header).
-- Restricted code can't build tables, so the cycle lives in "cycle-<side>-<bar>" attributes.
local LATCH_ON_CLICK = [=[
	local current = owner:GetAttribute("active-bar") or "top"
	local nextBar = owner:GetAttribute("cycle-" .. self:GetAttribute("side") .. "-" .. current) or "top"
	owner:SetAttribute("active-bar", nextBar)
	owner:RunAttribute("ApplyLayer")
	return false
]=]

-- _onshow / _onhide of a targeting-bar watcher (self = watcher handle). Blizzard switches its targeting bars from
-- Lua callbacks; ours would run insecurely and can't rebind in combat. A protected child frame's visibility follows
-- its parent, though, so these run securely whenever Blizzard shows or hides the bar, in combat too.
local TARGETING_WATCH_CHANGED = [=[
	self:GetFrameRef("header"):RunAttribute("ApplyLayer")
]=]

function Bindings:Init()
	local Controller = CCS.Controller
	-- State template: Bars registers a modifier state driver on this header for the expand/collapse layout.
	local header = CreateFrame("Frame", "CCS_Header", UIParent, "SecureHandlerStateTemplate")
	self.header = header

	for i, key in ipairs(Controller.SLOT_KEYS) do
		header:SetAttribute("key-" .. i, key)
		for _, bar in ipairs(Controller.BARS) do
			local button = _G["CCS_Button_" .. bar .. i]
			header:SetAttribute("button-" .. bar .. "-" .. i, button and button:GetName() or nil)
		end
	end
	header:SetAttribute("ApplyLayer", APPLY_LAYER)

	for side, steps in pairs(CYCLE) do
		for from, to in pairs(steps) do
			header:SetAttribute("cycle-" .. side .. "-" .. from, to)
		end
	end

	-- One watcher per Blizzard targeting bar, parented to it (created out of combat, never touched afterwards).
	local watchCount = 0
	for _, targetingBar in ipairs(CCS.Blizzard:GetTargetingBars()) do
		watchCount = watchCount + 1
		local watch = CreateFrame("Frame", "CCS_TargetingWatch" .. watchCount, targetingBar, "SecureHandlerShowHideTemplate")
		watch:SetFrameRef("header", header)
		watch:SetAttribute("_onshow", TARGETING_WATCH_CHANGED)
		watch:SetAttribute("_onhide", TARGETING_WATCH_CHANGED)
		header:SetFrameRef("targeting-watch-" .. watchCount, watch)
	end
	header:SetAttribute("targeting-watch-count", watchCount)
	header:SetAttribute("targeting-bars", CCS.db.targetingBars or nil)

	CCS.Bars:SetupSecureLayout(header)

	CCS.On("PLAYER_REGEN_ENABLED", function()
		if CCS.db.resetBarAfterCombat then
			self:ReturnToDefaultBar()
		end
	end)

	self.latchButtons = {}
	for _, side in ipairs({ "left", "right" }) do
		local button = CreateFrame("Button", "CCS_Latch_" .. side, header, "SecureActionButtonTemplate")
		button:SetAttribute("side", side)
		button:RegisterForClicks("AnyDown")
		header:WrapScript(button, "OnClick", LATCH_ON_CLICK)
		self.latchButtons[side] = button
	end
end

-- Static bindings: held triggers act as SHIFT/CTRL, so modified keys map straight to their bar.
function Bindings:ApplyStatic()
	local Controller, header = CCS.Controller, self.header
	ClearOverrideBindings(header)
	if self.suspended then
		return
	end

	for i, key in ipairs(Controller.SLOT_KEYS) do
		for _, bar in ipairs(Controller.BARS) do
			local prefix = Controller.BAR_MODIFIERS[bar]
			local button = _G["CCS_Button_" .. bar .. i]
			if prefix ~= "" and button then
				SetOverrideBindingClick(header, true, prefix .. key, button:GetName())
			end
		end
	end

	if CCS.db.latch then
		-- Bind every modifier combination so a tap still registers while the other trigger is held.
		for _, prefix in ipairs(MODIFIER_PREFIXES) do
			SetOverrideBindingClick(header, true, prefix .. Controller.TRIGGER_LEFT, self.latchButtons.left:GetName())
			SetOverrideBindingClick(header, true, prefix .. Controller.TRIGGER_RIGHT, self.latchButtons.right:GetName())
		end
	end

	-- Bare keys are owned by the restricted snippet so they can change in combat.
	header:Execute([[ self:RunAttribute("ApplyLayer") ]])
end

function Bindings:ResetLatch()
	self.header:SetAttribute("active-bar", "top")
end

-- Out of combat only: return the latch to the default bar and rebind (option "Revert to default bar after combat").
function Bindings:ReturnToDefaultBar()
	if not CCS.active or InCombatLockdown() or self.header:GetAttribute("active-bar") == "top" then
		return
	end
	self.header:Execute([[
		self:SetAttribute("active-bar", "top")
		self:RunAttribute("ApplyLayer")
	]])
end

-- Out of combat only: stop or resume all of our bindings (used when Blizzard UI panels take gamepad focus).
function Bindings:SetSuspended(suspended)
	suspended = suspended and true or false
	CCS.RunOutOfCombat("Bindings:SetSuspended", function()
		if self.suspended == suspended then
			return
		end
		self.suspended = suspended
		self.suspendToggles = (self.suspendToggles or 0) + 1 -- shown in /ccs status, to spot flapping
		self.header:SetAttribute("suspended", suspended or nil)
		if suspended or not CCS.active then
			ClearOverrideBindings(self.header)
		else
			self:ApplyStatic()
		end
	end)
end

-- Out of combat only (options window): toggle the LB / RB targeting bars.
function Bindings:SetTargetingBars(enabled)
	if InCombatLockdown() then
		return
	end
	self.header:SetAttribute("targeting-bars", enabled or nil)
	self.header:Execute([[ self:RunAttribute("ApplyLayer") ]])
	if CCS.active then
		CCS.Blizzard:SetBlizzardBarFaded(CCS.db.hideBlizzardBar)
	end
	CCS.Bars:RefreshShoulderIcons()
end

function Bindings:Enable()
	self:ResetLatch()
	-- The targeting watchers can rerun ApplyLayer at any time; this keeps them from binding while we're disabled.
	self.header:SetAttribute("enabled", true)
	self:ApplyStatic()
end

function Bindings:Disable()
	self:ResetLatch()
	self.header:SetAttribute("enabled", nil)
	ClearOverrideBindings(self.header)
end

CCS.RegisterModule("Bindings", Bindings)
