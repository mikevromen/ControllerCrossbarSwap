local _, CCS = ...

-- Our crossbar, laid out like Blizzard's GamepadMainActionBarFrame (see Style.lua for the art). The active bar is
-- "expanded" (bigger buttons, focus background) and the others are "collapsed". Size and position of the secure
-- buttons change in the restricted LAYOUT snippet so it also works in combat; textures follow via OnVisibleBarChanged.
local Bars = {}

local LEVEL_INACTIVE = 2
local LEVEL_ACTIVE = 10

-- Blizzard's reserved top-bar face buttons (slots 5-8). Their keys fall through to Blizzard; we only draw them.
local RESERVED = {
	[5] = { name = "Interact" },
	[6] = { name = "Inspect" },
	[7] = { name = "Back", atlas = "128-redbutton-exit", inset = -6 },
	[8] = { name = "Jump", atlas = "gamepad-ability-icon-jump" },
}

-- Ring order of the bar positions; matches the RT tap cycle in Bindings.lua (LT walks it backwards).
local RING = { "top", "right", "bottom", "left" }
local RING_INDEX = { top = 0, right = 1, bottom = 2, left = 3 }

local ROTATE_ANIM_DURATION = 0.22

-- Restricted environment, self = header. Positions, resizes and re-anchors bars and buttons.
-- * Expanded bar: the visible one (held modifier wins over the latched bar).
-- * With "rotate" on, bars shift around the ring so the latched bar sits in the top (main) slot.
local LAYOUT = [=[
	local latched = self:GetAttribute("active-bar") or "top"
	local bar = self:GetAttribute("mod-bar")
	if not bar or bar == "none" then
		bar = latched
	end

	local main = self:GetFrameRef("main")
	local rotate = self:GetAttribute("rotate")
	local latchedIndex = self:GetAttribute("ring-index-" .. latched)
	-- Set by ApplyLayer: Blizzard's LB / RB targeting bar is showing in the main slot, so ours steps out of view.
	local targeting = self:GetAttribute("blizz-targeting")

	for b = 1, 4 do
		local name = self:GetAttribute("bar-name-" .. b)
		local focus = name == bar and "expanded" or "collapsed"
		local barFrame = self:GetFrameRef("bar-" .. name)

		local slot = self:GetAttribute("ring-index-" .. name)
		if rotate then
			slot = (slot - latchedIndex) % 4
		end
		local slotName = self:GetAttribute("ring-name-" .. slot)

		-- Inactive bars can be scaled down. Anchor offsets scale with the frame, so divide to keep the slot centre.
		local scale = 1
		if focus == "collapsed" then
			scale = self:GetAttribute("inactive-scale") or 1
		end
		barFrame:SetScale(scale)
		barFrame:ClearAllPoints()
		barFrame:SetPoint("CENTER", main, "CENTER",
			self:GetAttribute("slot-x-" .. slotName) / scale, self:GetAttribute("slot-y-" .. slotName) / scale)

		barFrame:SetWidth(self:GetAttribute("bar-width-" .. focus))
		barFrame:SetHeight(self:GetAttribute("bar-height-" .. focus))
		barFrame:SetFrameLevel(self:GetAttribute("bar-level-" .. focus))
		barFrame:SetAlpha((targeting and slotName == "top") and 0 or 1)

		for i = 1, 8 do
			local button = self:GetFrameRef("button-" .. name .. "-" .. i)
			if button then
				local size = self:GetAttribute("size-" .. focus .. "-" .. i)
				button:SetWidth(size)
				button:SetHeight(size)
				button:ClearAllPoints()
				button:SetPoint("CENTER", barFrame, "CENTER",
					self:GetAttribute("x-" .. focus .. "-" .. i), self:GetAttribute("y-" .. focus .. "-" .. i))
			end
		end
	end

	self:CallMethod("OnVisibleBarChanged", bar)
]=]

local function MakeInteractIconUpdater(texture)
	local function Update()
		for _, unit in ipairs({ "softinteract", "target" }) do
			if (UnitExists(unit) or UnitIsGameObject(unit)) and SetUnitCursorTexture(texture, unit, nil, nil, false) then
				return
			end
		end
		texture:SetTexture(C_Spell.GetSpellTexture(6603)) -- Auto Attack, same fallback as Blizzard
	end
	return function() RunNextFrame(Update) end
end

function Bars:CreateActionButton(group, bar, index)
	local Style = CCS.Style
	local button = CreateFrame("CheckButton", "CCS_Button_" .. bar .. index, group, "ActionBarButtonTemplate")
	button:SetAttribute("showgrid", 1)
	button:SetAttribute("useOnKeyDown", true)
	button:SetAttribute("action", CCS.Slots:GetActionSlot(bar, index))
	Style:ApplyButtonArt(button, index)
	button.SlotArt:Show() -- BaseActionButtonMixin hides it for buttons without a .bar
	return button
end

-- Display-only copy of one of Blizzard's reserved top-bar buttons (Interact / Inspect / Back / Jump).
function Bars:CreateReservedButton(group, index)
	local info = RESERVED[index]
	local button = CreateFrame("CheckButton", nil, group, "ActionButtonTemplate")
	button:EnableMouse(false)
	CCS.Style:ApplyButtonArt(button, index)
	button.SlotArt:Hide()
	button.icon:Hide()

	-- Black masked backdrop plus the action icon (MainActionBarFrame.lua SetupNonBindable*).
	local backdrop = button:CreateTexture(nil, "BACKGROUND", nil, 0)
	backdrop:SetColorTexture(0, 0, 0, 1)
	backdrop:SetAllPoints()
	backdrop:AddMaskTexture(button.ccsMask)

	local icon = button:CreateTexture(nil, "BACKGROUND", nil, 1)
	icon:AddMaskTexture(button.ccsMask)
	local inset = info.inset or 0
	icon:SetPoint("TOPLEFT", inset, -inset)
	icon:SetPoint("BOTTOMRIGHT", -inset, inset)
	button.SpecialActionIcon = icon

	if info.atlas then
		icon:SetAtlas(info.atlas)
	elseif info.name == "Inspect" then
		local function Update()
			icon:SetAtlas(UnitExists("target") and "crosshair_inspect_32" or "crosshair_unableinspect_32")
		end
		CCS.On("PLAYER_TARGET_CHANGED", Update)
		Update()
	elseif info.name == "Interact" then
		local update = MakeInteractIconUpdater(icon)
		for _, event in ipairs({ "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
			CCS.On(event, update)
		end
		update()
	end
	return button
end

function Bars:CreateGroup(bar)
	local Style = CCS.Style
	local group = CreateFrame("Frame", "CCS_Bar_" .. bar, self.frame, "SecureFrameTemplate")
	group:SetFrameStrata("LOW")
	group:SetSize(unpack(Style.BAR_SIZE.collapsed))
	local anchor = Style.BAR_ANCHORS[bar]
	group:SetPoint("CENTER", self.frame, "CENTER", anchor[1], anchor[2])

	group.BackgroundFocus = group:CreateTexture(nil, "BACKGROUND")
	group.BackgroundFocus:SetAtlas("gamepad-actionbar-focus-bg-section")
	group.BackgroundFocus:SetAlpha(0.375)
	group.BackgroundFocus:SetSize(512, 160)
	group.BackgroundFocus:SetPoint("CENTER")
	group.BackgroundFocus:Hide()

	-- Rotation glide: the secure layout snaps the bar to its new slot, then this plays in reverse from the old slot.
	-- Animations only offset rendering, so playing them on a protected frame is allowed in combat.
	group.rotateAnim = group:CreateAnimationGroup()
	group.rotateTranslation = group.rotateAnim:CreateAnimation("Translation")
	group.rotateTranslation:SetDuration(ROTATE_ANIM_DURATION)
	group.rotateTranslation:SetSmoothing("IN_OUT")

	group.buttons = {}
	for index = 1, #CCS.Controller.SLOT_KEYS do
		local button
		if CCS.Slots:IsReserved(bar, index) then
			button = self:CreateReservedButton(group, index)
		else
			button = self:CreateActionButton(group, bar, index)
		end
		group.buttons[index] = button
		self.allButtons[#self.allButtons + 1] = button
	end
	return group
end

-- LT / RT / LT+RT prompts under the side and bottom bars (GamepadActionBarPageUnitTemplate ModifierIcons).
function Bars:CreateModifierIcons()
	-- Parented to their bar (not just anchored) so they follow its rotation animation.
	local groups = self.groups
	local left = CreateFrame("Frame", nil, groups.left, "InputIconTextureFrameTemplate")
	left:SetInputKey(GAMEPAD_TRIGGER_LEFT)
	left:SetPoint("CENTER", groups.left, "CENTER", 0, -35)

	local right = CreateFrame("Frame", nil, groups.right, "InputIconTextureFrameTemplate")
	right:SetInputKey(GAMEPAD_TRIGGER_RIGHT)
	right:SetPoint("CENTER", groups.right, "CENTER", 0, -35)

	local both = CreateFrame("Frame", nil, groups.bottom, "InputPromptTwoIconTemplate")
	both:SetPromptInputIconKey(1, GAMEPAD_TRIGGER_LEFT)
	both:SetPromptInputIconKey(2, GAMEPAD_TRIGGER_RIGHT)
	both:SetPoint("CENTER", groups.bottom, "CENTER", 0, -35)

	self.modifierIcons = { left = { left }, right = { right }, bottom = both.InputIcons or {} }
	self.modifierPrompts = { left, right, both }
	for _, frame in ipairs(self.modifierPrompts) do
		frame:SetFrameStrata("MEDIUM")
	end
	self:RefreshModifierPrompts()
end

-- With rotation on, the prompts would travel to positions that no longer match "hold LT / RT", so hide them.
function Bars:RefreshModifierPrompts()
	local show = not CCS.db.rotateBars
	for _, frame in ipairs(self.modifierPrompts) do
		frame:SetShown(show)
	end
end

-- LB/RB targeting art above the top bar (MainActionBarFrame.xml PageUnit layers).
function Bars:CreateShoulderArt()
	local frame = self.frame
	local topX, topY = unpack(CCS.Style.BAR_ANCHORS.top)
	local shoulders = {}
	for _, side in ipairs({ "left", "right" }) do
		local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
		bg:SetAtlas("gamepad-targeting-" .. side .. "-shoulder-bg", true)
		if side == "left" then
			bg:SetPoint("BOTTOMRIGHT", frame, "CENTER", topX - 108, topY + 42)
		else
			bg:SetPoint("BOTTOMLEFT", frame, "CENTER", topX + 108, topY + 42)
		end
		local icon = frame:CreateTexture(nil, "BACKGROUND")
		icon:SetPoint("CENTER", bg)
		local highlight = frame:CreateTexture(nil, "OVERLAY")
		highlight:SetAtlas("gamepad-targeting-" .. side .. "-shoulder-pressed", true)
		highlight:SetPoint("CENTER", bg)
		highlight:Hide()
		shoulders[side] = { icon = icon, highlight = highlight }
	end
	self.shoulders = shoulders
	self:RefreshShoulderIcons()

	-- Public CallbackRegistry API; it dispatches through secureexecuterange, so our callback can't taint Blizzard.
	if GamepadMode and GamepadMode.RegisterTargetModifierChanged then
		GamepadMode.RegisterTargetModifierChanged(self.OnTargetModifierChanged, self)
	end
	if CVarCallbackRegistry then
		CVarCallbackRegistry:RegisterCallback("GamepadSwapTargetModifiers", self.RefreshShoulderIcons, self)
	end
	-- Blizzard swaps its shoulder icons while a targeting bar is up (SetShoulderIcons in TargetActionBars/*.lua).
	-- HookScript adds to Blizzard's handlers without replacing them.
	for _, targetingBar in ipairs(CCS.Blizzard:GetTargetingBars()) do
		targetingBar:HookScript("OnShow", function() self:RefreshShoulderIcons() end)
		targetingBar:HookScript("OnHide", function() self:RefreshShoulderIcons() end)
	end
end

function Bars:RefreshShoulderIcons()
	local SHORTCUTS = "gamepad-targeting-shortcuts"
	local left, right = "gamepad-targeting-friendly", "gamepad-targeting-hostile"
	if C_CVar.GetCVarBool("GamepadSwapTargetModifiers") then
		left, right = right, left
	end

	-- Same as Blizzard: while a targeting bar is up, the other shoulder (now opening shortcuts) shows that icon.
	local shown = CCS.db.targetingBars and CCS.Blizzard:GetShownTargetingBarKey()
	if shown == "ShortcutsActionBar" then
		left, right = SHORTCUTS, SHORTCUTS
	elseif shown == "FriendlyTargetingActionBar" then
		if left == "gamepad-targeting-friendly" then right = SHORTCUTS else left = SHORTCUTS end
	elseif shown == "HostileTargetingActionBar" then
		if left == "gamepad-targeting-hostile" then right = SHORTCUTS else left = SHORTCUTS end
	end

	self.shoulders.left.icon:SetAtlas(left, true)
	self.shoulders.right.icon:SetAtlas(right, true)
end

function Bars:OnTargetModifierChanged(flag, down)
	local isLeft = flag == GamepadMode.GetLeftTargetModifierFlag()
	self.shoulders[isLeft and "left" or "right"].highlight:SetShown(down)
end

function Bars:Init()
	local Style = CCS.Style
	-- Explicitly protected so the restricted Layout snippet can anchor bars to it in combat.
	local frame = CreateFrame("Frame", "CCS_BarFrame", UIParent, "SecureFrameTemplate")
	self.frame = frame
	frame:SetSize(unpack(Style.FRAME_SIZE))
	frame:Hide()

	self.allButtons = {}
	self.groups = {}
	for _, bar in ipairs(CCS.Controller.BARS) do
		self.groups[bar] = self:CreateGroup(bar)
	end
	self:CreateModifierIcons()
	self:CreateShoulderArt()
	self:CreateIndicators()

	if InputDeviceIconSetManager and InputDeviceIconSetManager.RegisterActiveInputDeviceIconSetUpdatedCallback then
		InputDeviceIconSetManager:RegisterActiveInputDeviceIconSetUpdatedCallback(function()
			Style:RefreshEmptySlotArt(self.allButtons)
		end, self)
	end
	self:OnVisibleBarChanged("top")
end

-- Called by Bindings:Init once the secure header exists.
function Bars:SetupSecureLayout(header)
	local Style = CCS.Style
	for b, bar in ipairs(CCS.Controller.BARS) do
		local group = self.groups[bar]
		header:SetAttribute("bar-name-" .. b, bar)
		header:SetFrameRef("bar-" .. bar, group)
		for index, button in ipairs(group.buttons) do
			if button:IsProtected() then
				header:SetFrameRef("button-" .. bar .. "-" .. index, button)
			end
		end
	end

	local baseLevel = self.frame:GetFrameLevel()
	for _, focus in pairs(Style.FOCUS) do
		local width, height = unpack(Style.BAR_SIZE[focus])
		header:SetAttribute("bar-width-" .. focus, width)
		header:SetAttribute("bar-height-" .. focus, height)
		header:SetAttribute("bar-level-" .. focus, baseLevel + (focus == Style.FOCUS.EXPANDED and LEVEL_ACTIVE or LEVEL_INACTIVE))
		for index, offset in ipairs(Style.BUTTON_OFFSETS[focus]) do
			header:SetAttribute("size-" .. focus .. "-" .. index, Style:GetButtonSize(index, focus))
			header:SetAttribute("x-" .. focus .. "-" .. index, offset[1])
			header:SetAttribute("y-" .. focus .. "-" .. index, offset[2])
		end
	end
	header:SetFrameRef("main", self.frame)
	for index, slot in ipairs(RING) do
		header:SetAttribute("ring-name-" .. (index - 1), slot)
		header:SetAttribute("ring-index-" .. slot, index - 1)
		local anchor = Style.BAR_ANCHORS[slot]
		header:SetAttribute("slot-x-" .. slot, anchor[1])
		header:SetAttribute("slot-y-" .. slot, anchor[2])
	end
	header:SetAttribute("rotate", CCS.db.rotateBars or nil)
	header:SetAttribute("inactive-scale", self:GetInactiveScale())
	header:SetAttribute("Layout", LAYOUT)
	self.header = header

	-- Must exist before the state driver is registered: registering runs the Layout snippet immediately.
	function header:OnVisibleBarChanged(bar)
		Bars:OnVisibleBarChanged(bar)
	end

	-- Held triggers are real SHIFT/CTRL modifiers, so a state driver tracks them securely (in combat too).
	header:SetAttribute("_onstate-modbar", [=[
		self:SetAttribute("mod-bar", newstate)
		self:RunAttribute("Layout")
	]=])
	RegisterStateDriver(header, "modbar", "[mod:ctrl,mod:shift] bottom; [mod:shift] left; [mod:ctrl] right; none")
end

-- Size of the inactive (collapsed) bars, selectable in the options window (db.inactiveBarSize).
Bars.INACTIVE_SIZES = {
	{ key = "normal", label = "Normal", scale = 1 },
	{ key = "small", label = "Small", scale = 0.85 },
	{ key = "smaller", label = "Smaller", scale = 0.7 },
}

function Bars:GetInactiveScale()
	for _, size in ipairs(self.INACTIVE_SIZES) do
		if size.key == CCS.db.inactiveBarSize then
			return size.scale
		end
	end
	return 1
end

-- Out of combat only (called from the options window).
function Bars:ApplyInactiveScale()
	if InCombatLockdown() or not self.header then
		return
	end
	self.header:SetAttribute("inactive-scale", self:GetInactiveScale())
	self.header:Execute([[ self:RunAttribute("Layout") ]])
end

-- Out of combat only (called from the options window): toggle bar rotation and re-run the layout.
function Bars:SetRotate(enabled)
	if InCombatLockdown() or not self.header then
		return
	end
	self.header:SetAttribute("rotate", enabled or nil)
	self.header:Execute([[ self:RunAttribute("Layout") ]])
	self:RefreshModifierPrompts()
end

-- Mirrors the slot math of the restricted Layout snippet (read-only, for animations).
function Bars:GetSlotForBar(bar)
	local header = self.header
	if not header or not header:GetAttribute("rotate") then
		return bar
	end
	local latched = header:GetAttribute("active-bar") or "top"
	return RING[(RING_INDEX[bar] - RING_INDEX[latched]) % 4 + 1]
end

function Bars:AnimateRotation()
	self.lastSlots = self.lastSlots or {}
	local anchors = CCS.Style.BAR_ANCHORS
	for bar, group in pairs(self.groups) do
		local slot = self:GetSlotForBar(bar)
		local previous = self.lastSlots[bar]
		if previous and previous ~= slot and CCS.db.animateRotation then
			local from, to = anchors[previous], anchors[slot]
			-- Translation offsets are in the bar's own (possibly scaled) units.
			local scale = group:GetScale()
			group.rotateAnim:Stop()
			group.rotateTranslation:SetOffset((from[1] - to[1]) / scale, (from[2] - to[2]) / scale)
			group.rotateAnim:Play(true) -- reversed: starts at the old slot, ends at the real (new) position
		end
		self.lastSlots[bar] = slot
	end
end

-- Bar icons: one per bar in Blizzard's IdentifierIcon slot (GamepadActionBarTemplate uses it to mark special bars
-- like the possess bar): centred above the bar, 30 px collapsed / 35 px expanded at +38 / +48.
-- Each is a child of its bar, so it travels with it when bars rotate (including the glide).
-- Chosen per bar in the options window (BAR_ICON_SETTINGS). Atlases are ones the Forever client's own UI uses
-- (numbered page badges 1-3: PageUnit.lua); the raid markers are classic texture files.
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
Bars.INDICATOR_ICONS = {
	{ key = "none", label = "None" },
	{ key = "star", label = "Gold star", atlas = "auctionhouse-icon-favorite" },
	{ key = "page", label = "Number 1", atlas = "gamepad-actionbar-numericalpage-1-selected" },
	{ key = "page2", label = "Number 2", atlas = "gamepad-actionbar-numericalpage-2-selected" },
	{ key = "page3", label = "Number 3", atlas = "gamepad-actionbar-numericalpage-3-selected" },
	{ key = "raidStar", label = "Raid marker: star", file = RAID_ICON .. "1" },
	{ key = "raidCircle", label = "Raid marker: circle", file = RAID_ICON .. "2" },
	{ key = "raidDiamond", label = "Raid marker: diamond", file = RAID_ICON .. "3" },
	{ key = "raidTriangle", label = "Raid marker: triangle", file = RAID_ICON .. "4" },
	{ key = "raidMoon", label = "Raid marker: moon", file = RAID_ICON .. "5" },
	{ key = "raidSquare", label = "Raid marker: square", file = RAID_ICON .. "6" },
	{ key = "raidCross", label = "Raid marker: cross", file = RAID_ICON .. "7" },
	{ key = "raidSkull", label = "Raid marker: skull", file = RAID_ICON .. "8" },
	-- Crossed swords: the PvP countdown "go" art (FrameXML Timer.lua). Sword: a classic item icon (square art).
	{ key = "swords", label = "Crossed swords", atlas = "countdown-swords" },
	{ key = "sword", label = "Sword", file = "Interface\\Icons\\INV_Sword_04" },
	{ key = "check", label = "Checkmark", atlas = "Adventures-Checkmark" },
	{ key = "crest", label = "Gold crest", atlas = "Artifacts-CrestRune-Gold" },
}

-- Bar -> CCS.db key of its icon. The default bar keeps its pre-1.0.1 key so saved choices carry over.
Bars.BAR_ICON_SETTINGS = {
	top = "defaultBarIcon",
	left = "barIconLeft",
	right = "barIconRight",
	bottom = "barIconBottom",
}

-- Returns the icon entry for a key, or nil for "none" and unknown keys.
function Bars:GetIndicatorIcon(key)
	for _, icon in ipairs(self.INDICATOR_ICONS) do
		if icon.key == key then
			return (icon.atlas or icon.file) and icon or nil
		end
	end
	return nil
end

-- Applies an icon entry to a texture (also used by the options preview). "none" clears it.
function Bars:SetIndicatorTexture(texture, key)
	local icon = self:GetIndicatorIcon(key)
	if not icon then
		texture:SetTexture(nil)
	elseif icon.atlas then
		texture:SetAtlas(icon.atlas)
	else
		texture:SetTexture(icon.file)
	end
end

local INDICATOR_LAYOUT = {
	collapsed = { size = 30, y = 38 },
	expanded = { size = 35, y = 48 },
}

function Bars:CreateIndicators()
	self.indicators = {}
	for bar, group in pairs(self.groups) do
		local indicator = CreateFrame("Frame", nil, group)
		indicator:SetFrameLevel(group:GetFrameLevel() + 5)

		indicator.Icon = indicator:CreateTexture(nil, "ARTWORK")
		indicator.Icon:SetAllPoints()
		indicator:Hide()

		indicator.fadeIn = indicator:CreateAnimationGroup()
		local alpha = indicator.fadeIn:CreateAnimation("Alpha")
		alpha:SetFromAlpha(0)
		alpha:SetToAlpha(1)
		alpha:SetDuration(0.2)

		self.indicators[bar] = indicator
		self:LayoutIndicator(bar, CCS.Style.FOCUS.COLLAPSED)
	end
end

-- Not protected, so this is fine in combat (called from OnVisibleBarChanged).
function Bars:LayoutIndicator(bar, focus)
	local layout = INDICATOR_LAYOUT[focus]
	local indicator = self.indicators[bar]
	indicator:SetSize(layout.size, layout.size)
	indicator:ClearAllPoints()
	indicator:SetPoint("CENTER", self.groups[bar], "CENTER", 0, layout.y)
end

-- Option "Show bar icons" (db.showDefaultBarIndicator, its pre-1.0.1 key) plus one icon choice per bar.
function Bars:RefreshIndicator()
	if not self.indicators then
		return
	end
	for bar, indicator in pairs(self.indicators) do
		local key = CCS.db[self.BAR_ICON_SETTINGS[bar]]
		self:SetIndicatorTexture(indicator.Icon, key)
		local show = CCS.db.showDefaultBarIndicator and self:GetIndicatorIcon(key) ~= nil
		if show and not indicator:IsShown() then
			indicator:Show()
			indicator.fadeIn:Play()
		elseif not show and indicator:IsShown() then
			indicator.fadeIn:Stop()
			indicator:Hide()
		end
	end
end

-- Insecure visuals after the secure layout ran. Reserved display buttons aren't protected, so we place them here.
function Bars:OnVisibleBarChanged(visibleBar)
	local Style = CCS.Style
	self.visibleBar = visibleBar
	self:AnimateRotation()
	self:RefreshIndicator()
	for bar, group in pairs(self.groups) do
		local focus = bar == visibleBar and Style.FOCUS.EXPANDED or Style.FOCUS.COLLAPSED
		group.BackgroundFocus:SetShown(focus == Style.FOCUS.EXPANDED)
		if self.indicators then
			self:LayoutIndicator(bar, focus)
		end

		for index, button in ipairs(group.buttons) do
			if not button:IsProtected() then
				local size = Style:GetButtonSize(index, focus)
				local offset = Style.BUTTON_OFFSETS[focus][index]
				button:SetSize(size, size)
				button:ClearAllPoints()
				button:SetPoint("CENTER", group, "CENTER", offset[1], offset[2])
			end
			Style:ApplyFocus(button, focus)
		end

		for _, icon in ipairs(self.modifierIcons[bar] or {}) do
			if focus == Style.FOCUS.EXPANDED then icon:SetFocused() else icon:SetPressable() end
		end
	end
end

-- Called from the restricted SyncPage snippet after our buttons switched to another Blizzard bar page.
-- The action buttons refresh themselves (OnAttributeChanged); we only show which page is up. Page 1 shows no badge.
function Bars:OnPageChanged(page)
	self.page = page
	if not self.pageBadge then
		-- Above the main (top) slot, which stays put when bars rotate. Offset clears the expanded bar's icon.
		local badge = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		badge:SetPoint("BOTTOM", self.frame, "CENTER", 0, CCS.Style.BAR_ANCHORS.top[2] + 72)
		self.pageBadge = badge
	end
	self.pageBadge:SetText("Page " .. page)
	self.pageBadge:SetShown(page > 1)
end

function Bars:AttachToBlizzardPosition()
	local frame, blizzard = self.frame, _G.GamepadMainActionBarFrame
	frame:ClearAllPoints()
	if blizzard and CCS.db.followBlizzardPosition then
		-- Follows the Edit Mode position and scale of Blizzard's crossbar.
		frame:SetPoint("CENTER", blizzard, "CENTER")
		frame:SetScale(blizzard:GetScale() * CCS.db.scale)
	else
		local point = CCS.db.point
		frame:SetPoint(point[1], _G[point[2]] or UIParent, point[3], point[4], point[5])
		frame:SetScale(CCS.db.scale)
	end
end

function Bars:Enable()
	self:AttachToBlizzardPosition()
	self.frame:Show()
end

function Bars:Disable()
	self.frame:Hide()
end

CCS.RegisterModule("Bars", Bars)
