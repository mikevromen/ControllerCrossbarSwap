local _, CCS = ...

-- Experimental pet / possess bar (option db.petBar, default off).
-- Blizzard's gamepad UI shows its possess bar in place of one of its bars (cvar GamepadPossessBarOverride; default:
-- the top bar of special page 4). Pet actions aren't action slots, so our action buttons can't just switch slots as
-- for pages and stances. Instead every bar gets 8 hidden secure pet buttons (type "pet", Blizzard's gamepad pet IDs),
-- each anchored on top of the matching action button so they follow the secure layout and rotation.
-- Bindings' restricted ApplyLayer shows them and points the keys at them while a watcher on Blizzard's possess bar
-- is visible, i.e. exactly when Blizzard would show the pet bar on the current page. With the option off nothing
-- here is shown or bound.
-- The top bar's face buttons are Blizzard's reserved slots: there Blizzard's own bindings already press its possess
-- bar (its active bar), so we only draw those pet actions on the reserved display buttons (Bars:OnPetBarChanged).
local PetBar = {}

local PET_EVENTS = {
	"PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE", "PET_UI_UPDATE",
	"PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_FARSIGHT_FOCUS_CHANGED", "PLAYER_TARGET_CHANGED",
	"UNIT_PET", "UNIT_FLAGS", "UNIT_AURA",
}

function PetBar:GetFirstID()
	return C_GamepadUI.GetFirstGamepadPetActionStorageSlotIndex and C_GamepadUI.GetFirstGamepadPetActionStorageSlotIndex() or 1
end

-- Visual state of one pet button, after PetActionButtonMixin:UpdateButtonState (PetActionBar.lua). Insecure, but it
-- only touches textures, the cooldown and checked state, which is allowed in combat.
local function UpdatePetVisual(button, id)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(id)
	local icon = button.icon
	if texture then
		icon:SetTexture(isToken and _G[texture] or texture)
		if GetPetActionSlotUsable(id) then
			icon:SetVertexColor(1, 1, 1)
		else
			icon:SetVertexColor(0.4, 0.4, 0.4)
		end
		icon:Show()
	else
		icon:Hide()
	end
	button:SetChecked(isActive and true or false)
	if button.AutoCastOverlay then
		button.AutoCastOverlay:SetShown(autoCastAllowed and true or false)
		if button.AutoCastOverlay.ShowAutoCastEnabled then
			button.AutoCastOverlay:ShowAutoCastEnabled(autoCastEnabled)
		end
	end
	if button.cooldown then
		CooldownFrame_Set(button.cooldown, GetPetActionCooldown(id))
	end
	button.ccsPetName = isToken and _G[name] or name
end

function PetBar:CreateButton(bar, index, actionButton)
	local id = self:GetFirstID() + index - 1
	local button = CreateFrame("CheckButton", "CCS_PetButton_" .. bar .. index, actionButton:GetParent(),
		"SecureActionButtonTemplate, ActionButtonTemplate")
	button:SetAttribute("type", "pet")
	button:SetAttribute("action", id)
	button:SetAttribute("useOnKeyDown", true)
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetAllPoints(actionButton)
	button:SetFrameLevel(actionButton:GetFrameLevel() + 2)
	button.ccsPetID = id
	CCS.Style:ApplyButtonArt(button, index)
	if button.SlotArt then
		button.SlotArt:Show()
	end
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if not GameTooltip:SetPetAction(self.ccsPetID) and self.ccsPetName then
			GameTooltip:SetText(self.ccsPetName)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:HookScript("OnShow", function(self) UpdatePetVisual(self, self.ccsPetID) end)
	button:Hide()
	return button
end

function PetBar:Init()
	self.buttons = {}
	for _, bar in ipairs(CCS.Controller.BARS) do
		local group = CCS.Bars.groups[bar]
		self.buttons[bar] = {}
		for index, actionButton in ipairs(group.buttons) do
			-- Only over our secure action buttons; the top bar's reserved face slots stay Blizzard's.
			if actionButton:IsProtected() then
				self.buttons[bar][index] = self:CreateButton(bar, index, actionButton)
			end
		end
	end

	local function Refresh()
		self:Refresh()
	end
	for _, event in ipairs(PET_EVENTS) do
		CCS.On(event, Refresh)
	end
end

-- Updates the visuals of the shown pet bar (and the reserved top-face display, see Bars:OnPetBarChanged).
function PetBar:Refresh()
	local bar = self.shownBar
	if not bar then
		return
	end
	for _, button in pairs(self.buttons[bar]) do
		UpdatePetVisual(button, button.ccsPetID)
	end
	if bar == "top" then
		CCS.Bars:RefreshReservedOverride()
	end
end

-- Called from restricted code (CallMethod) after ApplyLayer showed or hid the pet buttons of a bar ("" = none).
function PetBar:OnShownBarChanged(bar)
	self.shownBar = bar ~= "" and bar or nil
	CCS.Bars:OnPetBarChanged(self.shownBar, self:GetFirstID())
	self:Refresh()
end

-- Expand / collapse art, from Bars:OnVisibleBarChanged.
function PetBar:ApplyFocus(bar, focus)
	for _, button in pairs(self.buttons and self.buttons[bar] or {}) do
		CCS.Style:ApplyFocus(button, focus)
	end
end

CCS.RegisterModule("PetBar", PetBar)
