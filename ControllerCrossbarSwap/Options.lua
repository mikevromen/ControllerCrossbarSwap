local _, CCS = ...

-- Options live in our own Blizzard-styled window (/ccs options). Two Forever gamepad-UI issues shape this:
-- 1. Native Options > AddOns pages freeze the client when backing out with B while the page has any focusable
--    control (bisected 2026-10-09), so the native page only has a mouse-only button (ignored by gamepad navigation).
-- 2. ShowUIPanel from addon code makes Blizzard's gamepad FrameControlsManager run inside our tainted call stack
--    and triggers ADDON_ACTION_BLOCKED. So the window is shown with a plain Show() and handles the controller
--    itself: while open it owns priority override bindings (D-pad, A, B) and our bar bindings are suspended.
--    For the same reason choices use a stepper row instead of a Blizzard dropdown (its Menu system is hooked by
--    the gamepad FrameControlsManager).
local Options = {}

local TITLE = "Controller Crossbar Swap"

-- Rows of the window, bound to CCS.db[key]. "enabledBy" greys a row out while that setting is off.
local ROWS = {
	{
		type = "checkbox",
		key = "resetBarAfterCombat",
		label = "Revert to default bar after combat",
		tooltip = "When combat ends, switch back to the default bar if another bar was selected by tapping LT or RT.",
	},
	{
		type = "checkbox",
		key = "rotateBars",
		label = "Rotate bars into the main position",
		tooltip = "Tapping LT or RT rotates all bars so the selected bar always moves into the main (top centre) position. Holding a trigger still uses that bar in place. The LT / RT prompts under the bars are hidden while this is on.",
		onChange = function(value) CCS.Bars:SetRotate(value) end,
	},
	{
		type = "checkbox",
		key = "animateRotation",
		label = "Animate bar rotation",
		tooltip = "Bars glide to their new position when they rotate, instead of jumping.",
		enabledBy = "rotateBars",
		indent = 24,
	},
	{
		type = "checkbox",
		key = "showDefaultBarIndicator",
		label = "Highlight the default bar",
		tooltip = "Shows an icon above the default bar (the one you return to after combat), so you can always see where it is, also when bars rotate.",
		onChange = function() CCS.Bars:RefreshIndicator() end,
	},
	{
		type = "choice",
		key = "defaultBarIcon",
		label = "Default bar icon",
		tooltip = "Icon shown above the default bar. Use left/right (or A) to change it.",
		choices = CCS.Bars.INDICATOR_ICONS,
		setPreview = function(texture, key) CCS.Bars:SetIndicatorTexture(texture, key) end,
		enabledBy = "showDefaultBarIndicator",
		indent = 24,
		onChange = function() CCS.Bars:RefreshIndicator() end,
	},
	{
		type = "choice",
		key = "inactiveBarSize",
		label = "Size of inactive bars",
		tooltip = "Shrinks the bars that are not active, so the active bar stands out more. The active bar always stays full size.",
		choices = CCS.Bars.INACTIVE_SIZES,
		onChange = function() CCS.Bars:ApplyInactiveScale() end,
	},
}

local PANEL_WIDTH = 420
local ROW_HEIGHT = 32

local function ShowTooltip(row)
	local info = row.info
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(GameTooltip, info.label)
	GameTooltip_AddNormalLine(GameTooltip, info.tooltip, true)
	GameTooltip:Show()
end

local function IsRowEnabled(row)
	return not row.info.enabledBy or CCS.db[row.info.enabledBy]
end

local function NotifyChange(info)
	if info.onChange then
		info.onChange(CCS.db[info.key])
	end
	Options:RefreshRows()
end

---------------------------------------------------------------------------------------------------------------------
-- Checkbox row
---------------------------------------------------------------------------------------------------------------------
local CheckboxRow = {}

function CheckboxRow:Refresh()
	self:SetChecked(CCS.db[self.info.key])
	self:SetEnabled(IsRowEnabled(self))
end

function CheckboxRow:SetSelected(selected)
	if selected then self:LockHighlight() else self:UnlockHighlight() end
end

function CheckboxRow:Activate()
	if self:IsEnabled() then
		self:Click()
	end
end

function CheckboxRow:Step()
	self:Activate()
end

function Options:CreateCheckboxRow(parent, info)
	local row = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	Mixin(row, CheckboxRow)
	local label = row.Text or row.text
	label:SetFontObject("GameFontHighlight")
	label:SetText(info.label)
	row.info = info

	row:SetScript("OnClick", function(self)
		CCS.db[info.key] = self:GetChecked() and true or false
		PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		NotifyChange(info)
	end)
	row:SetScript("OnEnter", ShowTooltip)
	row:SetScript("OnLeave", GameTooltip_Hide)
	return row
end

---------------------------------------------------------------------------------------------------------------------
-- Choice row: label, then Blizzard stepper arrows around an icon preview and its name
---------------------------------------------------------------------------------------------------------------------
local ChoiceRow = {}

function ChoiceRow:GetIndex()
	for index, choice in ipairs(self.info.choices) do
		if choice.key == CCS.db[self.info.key] then
			return index
		end
	end
	return 1
end

function ChoiceRow:Refresh()
	local choice = self.info.choices[self:GetIndex()]
	if self.info.setPreview then
		self.info.setPreview(self.Preview, choice.key)
	end
	self.Preview:SetShown(self.info.setPreview ~= nil)
	self.Value:SetText(choice.label)

	local enabled = IsRowEnabled(self)
	self:SetAlpha(enabled and 1 or 0.5)
	self.Decrement:SetEnabled(enabled)
	self.Increment:SetEnabled(enabled)
end

function ChoiceRow:SetSelected(selected)
	self.Highlight:SetShown(selected)
end

function ChoiceRow:Step(delta)
	if not IsRowEnabled(self) then
		return
	end
	local choices = self.info.choices
	local index = (self:GetIndex() - 1 + delta) % #choices + 1
	CCS.db[self.info.key] = choices[index].key
	PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
	NotifyChange(self.info)
end

function ChoiceRow:Activate()
	self:Step(1)
end

function Options:CreateChoiceRow(parent, info)
	local row = CreateFrame("Frame", nil, parent)
	Mixin(row, ChoiceRow)
	row.info = info
	row:SetSize(PANEL_WIDTH - 40 - (info.indent or 0), ROW_HEIGHT - 4)
	row:EnableMouse(true)
	row:SetScript("OnEnter", ShowTooltip)
	row:SetScript("OnLeave", GameTooltip_Hide)

	row.Highlight = row:CreateTexture(nil, "BACKGROUND")
	row.Highlight:SetAllPoints()
	row.Highlight:SetColorTexture(1, 0.82, 0, 0.12)
	row.Highlight:Hide()

	row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.Label:SetPoint("LEFT", 6, 0)
	row.Label:SetText(info.label)

	row.Increment = CreateFrame("Button", nil, row, "SteppersIncrementButtonTemplate")
	row.Increment:SetPoint("RIGHT", -4, 0)
	row.Increment:SetScript("OnClick", function() row:Step(1) end)

	row.Value = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Value:SetPoint("RIGHT", row.Increment, "LEFT", -6, 0)
	row.Value:SetWidth(140)
	row.Value:SetJustifyH("CENTER")

	row.Preview = row:CreateTexture(nil, "ARTWORK")
	row.Preview:SetSize(22, 22)
	row.Preview:SetPoint("RIGHT", row.Value, "LEFT", -4, 0)

	row.Decrement = CreateFrame("Button", nil, row, "SteppersDecrementButtonTemplate")
	row.Decrement:SetPoint("RIGHT", row.Preview, "LEFT", -6, 0)
	row.Decrement:SetScript("OnClick", function() row:Step(-1) end)
	return row
end

---------------------------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------------------------

-- Plain (insecure) buttons the controller keys are bound to while the window is open.
function Options:CreateNavButton(name, onClick)
	local button = CreateFrame("Button", name, self.frame)
	button:SetScript("OnClick", onClick)
	return button:GetName()
end

function Options:CreatePanel()
	local frame = CreateFrame("Frame", "CCS_OptionsFrame", UIParent, "ButtonFrameTemplate")
	self.frame = frame
	ButtonFrameTemplate_HidePortrait(frame)
	ButtonFrameTemplate_HideButtonBar(frame)
	frame:SetTitle(TITLE)
	frame:SetSize(PANEL_WIDTH, 90 + #ROWS * ROW_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:Hide()
	-- The template's close button would route through HideUIPanel; keep it a plain hide.
	frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)

	self.rows = {}
	for index, info in ipairs(ROWS) do
		local row
		if info.type == "choice" then
			row = self:CreateChoiceRow(frame.Inset, info)
		else
			row = self:CreateCheckboxRow(frame.Inset, info)
		end
		row:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 12 + (info.indent or 0), -10 - (index - 1) * ROW_HEIGHT)
		self.rows[index] = row
	end

	self.navBindings = {
		PADDUP = self:CreateNavButton("CCS_OptionsNavUp", function() self:MoveSelection(-1) end),
		PADDDOWN = self:CreateNavButton("CCS_OptionsNavDown", function() self:MoveSelection(1) end),
		PADDLEFT = self:CreateNavButton("CCS_OptionsNavLeft", function() self:StepSelection(-1) end),
		PADDRIGHT = self:CreateNavButton("CCS_OptionsNavRight", function() self:StepSelection(1) end),
		PAD1 = self:CreateNavButton("CCS_OptionsNavAccept", function() self:ActivateSelection() end),
		PAD2 = self:CreateNavButton("CCS_OptionsNavBack", function() frame:Hide() end),
		ESCAPE = "CCS_OptionsNavBack",
	}

	frame:SetScript("OnShow", function() self:OnShow() end)
	frame:SetScript("OnHide", function() self:OnHide() end)

	-- Override bindings can't change in combat, so never stay open into combat.
	CCS.On("PLAYER_REGEN_DISABLED", function()
		if frame:IsShown() then
			frame:Hide()
		end
	end)
end

function Options:RefreshRows()
	for _, row in ipairs(self.rows) do
		row:Refresh()
	end
	-- Keep the tooltip on the selected row (refreshes can change its enabled state).
	local selected = self.rows[self.selected or 0]
	if selected and GameTooltip:IsOwned(selected) then
		ShowTooltip(selected)
	end
end

function Options:OnShow()
	self:RefreshRows()

	-- Our bar bindings would win over these on the D-pad, so step them aside while the window is open.
	CCS.Bindings:SetSuspended(true)
	for key, buttonName in pairs(self.navBindings) do
		SetOverrideBindingClick(self.frame, true, key, buttonName)
	end
	self:SelectIndex(1)
end

function Options:OnHide()
	GameTooltip_Hide()
	self:SelectIndex(nil)
	ClearOverrideBindings(self.frame)
	-- Resume our bindings unless a Blizzard UI still has focus.
	CCS.Blizzard:RefreshFocus()
end

function Options:SelectIndex(index)
	local previous = self.rows[self.selected or 0]
	if previous then
		previous:SetSelected(false)
	end
	self.selected = index
	local current = self.rows[index or 0]
	if current then
		current:SetSelected(true)
		ShowTooltip(current)
	end
end

function Options:MoveSelection(delta)
	local count = #self.rows
	if count == 0 then
		return
	end
	self:SelectIndex(((self.selected or 1) - 1 + delta) % count + 1)
end

function Options:StepSelection(delta)
	local row = self.rows[self.selected or 0]
	if row and row.info.type == "choice" then
		row:Step(delta)
	end
end

function Options:ActivateSelection()
	local row = self.rows[self.selected or 0]
	if row then
		row:Activate()
	end
end

function Options:IsOpen()
	return self.frame and self.frame:IsShown()
end

-- Native Options > AddOns page: a canvas with a hint and an "Open options window" button.
-- The button is marked ignored for gamepad SmartNavigation, so the page has no controller-focusable control
-- (backing out with B from a page with one freezes the client, see top of file). Instead, while the page is shown,
-- it owns an override binding on Y (GAMEPAD_FACE_TOP) that clicks the button. On this page SmartNavigation only uses
-- A, B and the D-pad, and Y is Blizzard's "open" button on dropdowns/selectors, so it fits.
local NATIVE_PAGE_KEY = GAMEPAD_FACE_TOP or "PAD4"

function Options:CreateNativePage()
	local page = CreateFrame("Frame")

	local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(TITLE)

	local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	hint:SetJustifyH("LEFT")
	hint:SetText("Settings are in their own window, which also works with a controller.\nOpen it with the button below, or type /ccs options.")

	local button = CreateFrame("Button", "CCS_NativeOpenButton", page, "UIPanelButtonTemplate")
	button:SetSize(220, 26)
	button:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
	button:SetText("Open options window")
	button:SetScript("OnClick", function() self:Open() end)
	if SmartNavigation_MarkFrameIgnored then
		SmartNavigation_MarkFrameIgnored(button) -- sets a flag on our own button only
	end

	-- Controller prompt next to the button (gamepad mode only).
	local prompt = CreateFrame("Frame", nil, page, "InputIconTextureFrameTemplate")
	prompt:SetInputKey(NATIVE_PAGE_KEY)
	prompt:SetSize(24, 24)
	prompt:SetPoint("LEFT", button, "RIGHT", 8, 0)

	page:SetScript("OnShow", function()
		local gamepad = CCS.IsGamepadUI()
		prompt:SetShown(gamepad)
		if gamepad and not InCombatLockdown() then
			SetOverrideBindingClick(page, true, NATIVE_PAGE_KEY, button:GetName())
		end
	end)
	page:SetScript("OnHide", function()
		CCS.RunOutOfCombat("Options:NativePageBinding", function()
			if not page:IsShown() then
				ClearOverrideBindings(page)
			end
		end)
	end)

	local category = Settings.RegisterCanvasLayoutCategory(page, TITLE)
	Settings.RegisterAddOnCategory(category)
	self.category = category
end

function Options:Init()
	self:CreatePanel()
	self:CreateNativePage()
end

-- Opening from the native page is fine: our window is DIALOG strata, above the Settings panel (HIGH).
function Options:Open()
	if self.frame:IsShown() then
		self.frame:Hide()
	elseif InCombatLockdown() then
		CCS.Print("Options can't be opened in combat.")
	else
		self.frame:Show()
	end
end

CCS.RegisterModule("Options", Options)
