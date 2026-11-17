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

	self:RunAttribute("SyncPage")

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

	-- Experimental pet bar: the bar Blizzard's possess bar replaces right now (its watcher is visible), or nil.
	local petBar = nil
	if self:GetAttribute("pet-enabled") then
		local petWatch = self:GetFrameRef("pet-watch")
		if petWatch and petWatch:IsVisible() then
			petBar = self:GetAttribute("pet-bar")
		end
	end

	local bound = self:GetAttribute("enabled") and not self:GetAttribute("suspended")
	if bound then
		for i = 1, 8 do
			local key = self:GetAttribute("key-" .. i)
			local target = nil
			if not targeting then
				if bar == petBar then
					target = self:GetAttribute("pet-button-" .. bar .. "-" .. i)
				else
					target = self:GetAttribute("button-" .. bar .. "-" .. i)
				end
			end
			if target then
				self:SetBindingClick(true, key, target)
			else
				self:ClearBinding(key)
			end
		end
	end

	-- Held-trigger keys (SHIFT- / CTRL-) are static bindings; only the pet bar redirects them, and back.
	local modBar = self:GetAttribute("pet-mod-bar")
	local newModBar = (bound and petBar ~= "top") and petBar or nil
	if modBar ~= newModBar then
		if modBar and bound then
			local prefix = self:GetAttribute("prefix-" .. modBar)
			for i = 1, 8 do
				local target = self:GetAttribute("button-" .. modBar .. "-" .. i)
				if target then
					self:SetBindingClick(true, prefix .. self:GetAttribute("key-" .. i), target)
				end
			end
		end
		if newModBar then
			local prefix = self:GetAttribute("prefix-" .. newModBar)
			for i = 1, 8 do
				local target = self:GetAttribute("pet-button-" .. newModBar .. "-" .. i)
				if target then
					self:SetBindingClick(true, prefix .. self:GetAttribute("key-" .. i), target)
				end
			end
		end
		self:SetAttribute("pet-mod-bar", newModBar)
	end

	-- Show the pet buttons over that bar (and hide its action buttons); nothing happens while the option is off.
	if petBar ~= self:GetAttribute("pet-shown") then
		for b = 1, 4 do
			local name = self:GetAttribute("bar-name-" .. b) or "-"
			for i = 1, 8 do
				local petButton = self:GetFrameRef("pet-" .. name .. "-" .. i)
				local actionButton = self:GetFrameRef("button-" .. name .. "-" .. i)
				if petButton then
					if name == petBar then
						petButton:Show()
					else
						petButton:Hide()
					end
				end
				if actionButton then
					actionButton:SetAlpha(name == petBar and 0 or 1)
				end
			end
		end
		self:SetAttribute("pet-shown", petBar)
		self:CallMethod("OnPetBarChanged", petBar or "")
	end

	self:RunAttribute("Layout")
]=]

-- Watcher on Blizzard's possess bar (self = watcher). Does nothing while the experimental pet bar option is off.
local PET_CHANGED = [=[
	local header = self:GetFrameRef("header")
	if header:GetAttribute("pet-enabled") then
		header:RunAttribute("ApplyLayer")
	end
]=]

-- Restricted, self = header. Follows Blizzard's bar page (LB+RB + D-pad left/right, the bar edit frame ...).
-- Blizzard pages in plain Lua and fires no event, but it does SetID(storageSlot) on its own buttons, so the ID of
-- its first top-bar button tells the page. Runs from ApplyLayer, which the shortcuts-bar watcher triggers on
-- release of LB+RB, so this works in combat. On the special page (4) Blizzard keeps the last standard page's IDs.
-- Stance bar: Blizzard shows its stance bar (in place of the bar picked by GamepadStanceBarOverride) only while a
-- stance / form is active and that bar's page is up, and sets its buttons' IDs to the stance's storage slots. A
-- watcher on it plus a [bonusbar] state driver rerun this, so our "stance-bar" bar takes those slots, in combat too.
local SYNC_PAGE = [=[
	local ref = self:GetFrameRef("blizz-page-button")
	if not ref then
		return
	end
	local first = self:GetAttribute("first-slot")
	local stride = self:GetAttribute("page-stride")
	local page = self:GetAttribute("page") or 1
	local id = ref:GetID()
	if id and id >= first then
		local idPage = floor((id - first) / stride) + 1
		if idPage <= self:GetAttribute("page-count") then
			page = idPage
		end
	end

	local stanceBar, stanceFirst = nil, nil
	local watch = self:GetFrameRef("stance-watch")
	local stanceButton = self:GetFrameRef("stance-button")
	if self:GetAttribute("stance-enabled") and watch and watch:IsVisible() and stanceButton then
		stanceFirst = stanceButton:GetID()
		if stanceFirst and stanceFirst > 0 then
			stanceBar = self:GetAttribute("stance-bar")
		end
	end

	-- Restricted code can't build tables, so a string key tells whether anything changed.
	local key = page .. ":" .. (stanceBar or "-") .. ":" .. (stanceBar and stanceFirst or 0)
	if key == self:GetAttribute("sync-key") then
		return
	end
	self:SetAttribute("sync-key", key)

	local pageChanged = page ~= self:GetAttribute("page")
	self:SetAttribute("page", page)
	for b = 1, 4 do
		local name = self:GetAttribute("bar-name-" .. b) or "-"
		for i = 1, 8 do
			local button = self:GetFrameRef("button-" .. name .. "-" .. i)
			local base = self:GetAttribute("action-base-" .. name .. "-" .. i)
			if button and base then
				if name == stanceBar then
					button:SetAttribute("action", stanceFirst + i - 1)
				else
					button:SetAttribute("action", base + stride * (page - 1))
				end
			end
		end
	end
	if pageChanged then
		self:CallMethod("OnPageChanged", page)
	end
	self:CallMethod("OnStanceChanged", stanceBar or "", stanceBar and stanceFirst or 0)
]=]

-- Stance watcher show/hide and the [bonusbar] state driver (self = watcher or header). Only the action slots can
-- change, so SyncPage is enough. With the experimental option off they do nothing; SetStanceBar resyncs on toggle.
local STANCE_CHANGED = [=[
	local header = self:GetFrameRef("header") or self
	if header:GetAttribute("stance-enabled") then
		header:RunAttribute("SyncPage")
	end
]=]

-- Pre-click wrapper for the LT/RT latch buttons (self = latch button, owner = header).
-- Restricted code can't build tables, so the cycle lives in "cycle-<side>-<bar>" attributes.
local LATCH_ON_CLICK = [=[
	local current = owner:GetAttribute("active-bar") or "top"
	local nextBar = owner:GetAttribute("cycle-" .. self:GetAttribute("side") .. "-" .. current) or "top"
	owner:SetAttribute("active-bar", nextBar)
	-- Remembered for the "Last bar used in combat" choice of the combat-bar option. With the experimental
	-- "last-skip-top", the default bar doesn't count: tapping back to it mid-fight (to loot or interact) would
	-- otherwise make the next fight start without a switch.
	if owner:GetAttribute("in-combat") and not (nextBar == "top" and owner:GetAttribute("last-skip-top")) then
		owner:SetAttribute("last-combat-bar", nextBar)
	end
	owner:RunAttribute("ApplyLayer")
	return false
]=]

-- _onstate-combat (self = header), driven by "[combat] on; off". A state driver evaluates macro conditions
-- securely, so the switch happens as combat starts, under lockdown. Option "Bar when combat starts" (db.combatBar):
-- "combat-bar" is a bar name, "last" (the bar last tapped to in combat) or nil (off).
local ON_COMBAT_STATE = [=[
	self:SetAttribute("in-combat", newstate == "on" or nil)
	if newstate ~= "on" then
		return
	end
	local target = self:GetAttribute("combat-bar")
	if target == "last" then
		target = self:GetAttribute("last-combat-bar")
	end
	if target and target ~= (self:GetAttribute("active-bar") or "top") then
		self:SetAttribute("active-bar", target)
		self:RunAttribute("ApplyLayer")
	end
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

	-- Bar pages. Our buttons start on page 1; SyncPage offsets them from these page-1 slots.
	local Slots = CCS.Slots
	header:SetAttribute("SyncPage", SYNC_PAGE)
	header:SetAttribute("first-slot", C_GamepadUI.GetFirstGamepadActionStorageSlotIndex())
	header:SetAttribute("page-stride", Slots:GetPageStride())
	header:SetAttribute("page-count", Slots.NUM_STANDARD_PAGES)
	header:SetAttribute("page", 1)
	for _, bar in ipairs(Controller.BARS) do
		for i = 1, #Controller.SLOT_KEYS do
			header:SetAttribute("action-base-" .. bar .. "-" .. i, Slots:GetActionSlot(bar, i))
		end
	end
	local pageButton = CCS.Blizzard:GetPageReferenceButton()
	if pageButton and pageButton:IsProtected() then
		header:SetFrameRef("blizz-page-button", pageButton)
	end

	-- Stance bar (see SYNC_PAGE). The watcher's visibility follows Blizzard's stance bar wherever Blizzard reparents
	-- it; the state driver below catches stance changes while the bar stays shown.
	local stanceBar = CCS.Blizzard:GetStanceBar()
	local stanceButton = stanceBar and stanceBar.Left and stanceBar.Left.ActionButton1
	if stanceButton and stanceButton:IsProtected() then
		local watch = CreateFrame("Frame", "CCS_StanceWatch", stanceBar, "SecureHandlerShowHideTemplate")
		watch:SetFrameRef("header", header)
		watch:SetAttribute("_onshow", STANCE_CHANGED)
		watch:SetAttribute("_onhide", STANCE_CHANGED)
		header:SetFrameRef("stance-watch", watch)
		header:SetFrameRef("stance-button", stanceButton)
	end
	self:ApplyStanceAttributes(CCS.db.stanceBar) -- SyncPage runs later (layout refs aren't set up yet)
	-- Blizzard's own event for this cvar (ActionBarTemplates.xml overrideCVarChangedEvent).
	CCS.On("GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", function()
		CCS.RunOutOfCombat("Bindings:StanceBar", function() self:SetStanceBar(CCS.db.stanceBar) end)
	end)
	-- Experimental pet bar (PetBar.lua): its buttons, the held-trigger prefixes, and a watcher on Blizzard's possess bar.
	for _, bar in ipairs(Controller.BARS) do
		header:SetAttribute("prefix-" .. bar, Controller.BAR_MODIFIERS[bar])
		for i, petButton in pairs(CCS.PetBar.buttons[bar] or {}) do
			header:SetAttribute("pet-button-" .. bar .. "-" .. i, petButton:GetName())
			header:SetFrameRef("pet-" .. bar .. "-" .. i, petButton)
		end
	end
	local possessBar = CCS.Blizzard:GetPossessBar()
	if possessBar then
		local watch = CreateFrame("Frame", "CCS_PetWatch", possessBar, "SecureHandlerShowHideTemplate")
		watch:SetFrameRef("header", header)
		watch:SetAttribute("_onshow", PET_CHANGED)
		watch:SetAttribute("_onhide", PET_CHANGED)
		header:SetFrameRef("pet-watch", watch)
	end
	self:ApplyPetAttributes(CCS.db.petBar)
	CCS.On("GAMEPAD_POSSESS_BAR_OVERRIDE_CHANGED", function()
		CCS.RunOutOfCombat("Bindings:PetBar", function() self:SetPetBar(CCS.db.petBar) end)
	end)
	function header:OnPetBarChanged(bar)
		CCS.PetBar:OnShownBarChanged(bar)
	end

	-- Must exist before ApplyLayer can run (rule: define header methods before any snippet calls them).
	function header:OnPageChanged(page)
		CCS.Bars:OnPageChanged(page)
	end
	function header:OnStanceChanged(bar, first)
		CCS.Bars:OnStanceChanged(bar, first)
	end
	-- Pages changed some other way than LB+RB (e.g. a key bound to Blizzard's page cycle button) don't trigger a
	-- watcher; catch those out of combat. Deferred a frame so we never act inside Blizzard's call stack.
	local pageUnit = _G.GamepadMainActionBarFrame and _G.GamepadMainActionBarFrame.PageUnit
	if pageUnit and pageUnit.SetCurrentPage then
		hooksecurefunc(pageUnit, "SetCurrentPage", function()
			RunNextFrame(function()
				CCS.RunOutOfCombat("Bindings:SyncPage", function()
					header:Execute([[ self:RunAttribute("SyncPage") ]])
				end)
			end)
		end)
	end

	CCS.Bars:SetupSecureLayout(header)

	CCS.On("PLAYER_REGEN_ENABLED", function()
		-- Read before a revert; kept per character so "last bar used in combat" survives a /reload.
		CCS.charDB.lastCombatBar = header:GetAttribute("last-combat-bar")
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

	-- Last: registering runs the snippet right away, and in combat (a /reload mid-fight) that runs ApplyLayer.
	header:SetAttribute("last-combat-bar", CCS.charDB.lastCombatBar)
	self:SetCombatBar(CCS.db.combatBar)
	header:SetAttribute("_onstate-combat", ON_COMBAT_STATE)
	RegisterStateDriver(header, "combat", "[combat] on; off")

	-- Stance changes while Blizzard's stance bar stays shown (e.g. Battle -> Defensive) only change its button IDs.
	-- The driver re-evaluates after UPDATE_BONUS_ACTIONBAR, i.e. after Blizzard's own handler set the new IDs.
	header:SetAttribute("_onstate-stance", STANCE_CHANGED)
	RegisterStateDriver(header, "stance",
		"[bonusbar:1] 1; [bonusbar:2] 2; [bonusbar:3] 3; [bonusbar:4] 4; [bonusbar:5] 5; 0")
end

-- GamepadStanceBarOverride (Enum.GamepadStanceBarOverride): 1 None, 2-4 page 1 left/right/bottom,
-- 5-8 page 2 top/left/right/bottom, 9-12 page 3 top/left/right/bottom (StanceBar.lua). Our bar names match
-- Blizzard's. The page needs no attribute: Blizzard only shows the stance bar while its page is up.
local STANCE_OVERRIDE_BARS = { "top", "left", "right", "bottom" }

function Bindings:ApplyStanceAttributes(enabled)
	local value = tonumber(GetCVar("GamepadStanceBarOverride"))
	local bar = value and value >= 2 and STANCE_OVERRIDE_BARS[(value - 1) % 4 + 1] or nil
	self.header:SetAttribute("stance-bar", bar)
	self.header:SetAttribute("stance-enabled", (enabled and bar) and true or nil)
end

-- Out of combat only (option + cvar changes): which of our bars follows Blizzard's stance bar, if any.
function Bindings:SetStanceBar(enabled)
	if InCombatLockdown() then
		return
	end
	self:ApplyStanceAttributes(enabled)
	self.header:Execute([[ self:RunAttribute("SyncPage") ]])
end

-- GamepadPossessBarOverride (Enum.GamepadPossessBarOverride): 1 SpecialPageTopBar, then like the stance cvar
-- (PossessBar.lua). As with the stance bar, Blizzard only shows the possess bar while its page is up.
function Bindings:ApplyPetAttributes(enabled)
	local value = tonumber(GetCVar("GamepadPossessBarOverride"))
	local bar = nil
	if value == 1 then
		bar = "top"
	elseif value and value >= 2 then
		bar = STANCE_OVERRIDE_BARS[(value - 1) % 4 + 1]
	end
	self.header:SetAttribute("pet-bar", bar)
	self.header:SetAttribute("pet-enabled", (enabled and bar) and true or nil)
end

-- Out of combat only (option + cvar changes): the experimental pet bar.
function Bindings:SetPetBar(enabled)
	if InCombatLockdown() then
		return
	end
	self:ApplyPetAttributes(enabled)
	self.header:Execute([[ self:RunAttribute("ApplyLayer") ]])
end

-- Out of combat only (options window): "off", "last" or a bar name.
function Bindings:SetCombatBar(value)
	if InCombatLockdown() then
		return
	end
	self.header:SetAttribute("combat-bar", value ~= "off" and value or nil)
	self.header:SetAttribute("last-skip-top", CCS.db.lastCombatBarSkipDefault or nil)
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

	-- Bare keys are owned by the restricted snippet so they can change in combat. The static held-trigger keys
	-- were just reset, so the pet bar's redirect of them (if any) has to be applied again.
	header:SetAttribute("pet-mod-bar", nil)
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
