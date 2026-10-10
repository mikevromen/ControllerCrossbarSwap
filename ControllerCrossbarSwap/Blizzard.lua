local _, CCS = ...

-- Everything that touches Blizzard's gamepad UI lives here. Rules: read-only access and hooksecurefunc
-- only; never assign into Blizzard's tables (see DESIGN.md, "Never taint Blizzard's gamepad code").
local Blizzard = {}

local MODIFIER_CVARS = {
	GamePadEmulateShift = "PADLTRIGGER",
	GamePadEmulateCtrl = "PADRTRIGGER",
}

function Blizzard:ApplyModifierCVars()
	if not CCS.db.manageModifiers then
		return
	end
	CCS.db.savedModifiers = CCS.db.savedModifiers or {}
	for cvar, value in pairs(MODIFIER_CVARS) do
		if CCS.db.savedModifiers[cvar] == nil then
			CCS.db.savedModifiers[cvar] = GetCVar(cvar)
		end
		SetCVar(cvar, value)
	end
end

function Blizzard:RestoreModifierCVars()
	local saved = CCS.db.savedModifiers
	if not saved then
		return
	end
	for cvar, value in pairs(saved) do
		SetCVar(cvar, value)
	end
	CCS.db.savedModifiers = nil
end

-- GamepadMainActionBarFrame is protected (secure children), so it can't be hidden in combat; alpha is enough.
function Blizzard:SetBlizzardBarFaded(faded)
	local bar = _G.GamepadMainActionBarFrame
	if bar then
		bar:SetAlpha(faded and 0 or 1)
	end
end

-- Blizzard pushes binding sets when a UI panel, chat or the radial takes gamepad focus. While any non-core
-- set is active we step aside so their D-pad/face navigation keeps working.
-- The gamepad action bar edit frame is special: it calls SetOverrideAllowLeftRightModifiers(true), which makes
-- IsOnlyCoreBindingSetActive() report "gameplay" while it reads raw D-pad/face/LT/RT input itself.
function Blizzard:IsBlizzardUIFocused()
	-- Our own options window drives the controller itself while open.
	if CCS.Options and CCS.Options:IsOpen() then
		return true
	end

	local editFrame = _G.GamepadActionBarEditFrame
	if editFrame and editFrame:IsShown() then
		return true
	end
	if GamepadMode and GamepadMode.GetOverrideAllowLeftRightModifiers and GamepadMode.GetOverrideAllowLeftRightModifiers() then
		return true
	end

	local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
	return manager ~= nil and not manager:IsOnlyCoreBindingSetActive()
end

-- Deferred to the next frame and coalesced. Blizzard often removes and re-adds binding sets within one call
-- stack (focus changes, list refreshes); reacting synchronously made us rebind mid-transition, and our rebinding
-- fires UPDATE_BINDINGS synchronously, which can feed back into Blizzard UI refreshes and loop.
function Blizzard:RefreshFocus()
	-- Debug switch (/ccs focus off): ignore Blizzard UI focus entirely (bindings stay active), to bisect freezes.
	if CCS.db.focusWatch == false then
		if CCS.active then
			CCS.Bindings:SetSuspended(CCS.Options:IsOpen())
		end
		return
	end
	if self.focusRefreshPending then
		return
	end
	self.focusRefreshPending = true
	C_Timer.After(0, function()
		self.focusRefreshPending = false
		if CCS.active then
			CCS.Bindings:SetSuspended(self:IsBlizzardUIFocused())
		end
	end)
end

function Blizzard:Init()
	local manager = GamepadSharedUtility and GamepadSharedUtility.InputBindingManager
	if manager then
		local refresh = function() self:RefreshFocus() end
		for _, method in ipairs({ "AddBindingSet", "RemoveSet", "ClearBindings", "AssumeCoreBindingsAreUsable" }) do
			hooksecurefunc(manager, method, refresh)
		end
	end

	-- HookScript adds a handler without replacing Blizzard's, so it doesn't taint the edit frame.
	local editFrame = _G.GamepadActionBarEditFrame
	if editFrame then
		editFrame:HookScript("OnShow", function() self:RefreshFocus() end)
		editFrame:HookScript("OnHide", function() self:RefreshFocus() end)
	end
	-- Combat may have blocked a suspend/resume; re-evaluate once it ends.
	CCS.On("PLAYER_REGEN_ENABLED", function() self:RefreshFocus() end)
end

function Blizzard:Enable()
	self:ApplyModifierCVars()
	self:SetBlizzardBarFaded(CCS.db.hideBlizzardBar)
	self:RefreshFocus()
end

function Blizzard:Disable()
	self:RestoreModifierCVars()
	self:SetBlizzardBarFaded(false)
end

CCS.RegisterModule("Blizzard", Blizzard)
