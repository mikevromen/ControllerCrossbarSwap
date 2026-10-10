local _, CCS = ...

-- Recreates the look of Blizzard's gamepad crossbar (Blizzard_GamepadActionBars: ActionBarButton.lua,
-- ActionBarStyles.lua, ActionBarTemplates.xml) on our own buttons. We copy values instead of inheriting
-- GamepadActionBarButtonTemplate because its TriggerSecureClick reads Lua fields before the secure click,
-- which would be tainted on our buttons and block casting in combat.
local Style = {}

Style.FOCUS = { COLLAPSED = "collapsed", EXPANDED = "expanded" }

-- Bar sizes per focus state (leftSquareRightCircleStyleInfo).
Style.BAR_SIZE = {
	collapsed = { 208, 68 },
	expanded = { 266, 86 },
}

-- Button centre offsets relative to the bar centre, indexed by our slot order
-- (1-4 = D-pad left/up/right/down, 5-8 = face left/top/right/bottom).
Style.BUTTON_OFFSETS = {
	collapsed = {
		{ -92, 0 }, { -58, 17 }, { -24, 0 }, { -58, -17 },
		{ 25, 0 }, { 55, 18 }, { 85, 0 }, { 55, -18 },
	},
	expanded = {
		{ -119, 0 }, { -75, 23 }, { -31, 0 }, { -75, -23 },
		{ 32, 0 }, { 70, 23 }, { 108, 0 }, { 70, -23 },
	},
}

-- Page unit layout (GamepadActionBarPageUnitTemplate): bar centres relative to the frame centre.
Style.FRAME_SIZE = { 656, 202 }
Style.BAR_ANCHORS = {
	top = { 0, 58 },
	bottom = { 0, -58 },
	left = { -195, 0 },
	right = { 195, 0 },
}

local SHADOW_DISTANCE = { collapsed = 4, expanded = 13 }
local CHECKED_DISTANCE = 4

local SHAPES = {
	square = {
		size = { collapsed = 32, expanded = 40 },
		mask = "SquareMask",
		shadow = "gamepad-actionbar-squareslot-dropshadow",
		shadowFocus = "gamepad-actionbar-focus-bg-square",
		normal = "gamepad-actionbar-squareslot-border-normal",
		pushed = "gamepad-actionbar-squareslot-border-pressed",
		highlight = "gamepad-actionbar-squareslot-border-hover",
		checked = "gamepad-actionbar-squareslot-border-selected",
		spellHighlight = "gamepad-actionbar-squareslot-border-hover",
		border = "UI-HUD-ActionBar-IconFrame-Border",
		reticleBase = "gamepad-actionbar-squareslot-aoetarget",
		reticleMask = "gamepad-actionbar-squareslot-aoetarget-mask",
		interruptBase = "gamepad-actionbar-squareslot-interrupt",
		interruptMask = "gamepad-actionbar-squareslot-interrupt_mask",
		interruptBaseOffset = 1,
		interruptMaskOffset = 4,
		autoCastCorners = "gamepad-actionbar-squareslot-petautocastcorners",
		autoCastMask = "gamepad-actionbar-squareslot-petautocast-mask",
		autoCastCornersOffset = 4,
		castInnerGlow = "gamepad-actionbar-squareslot-casting",
		channelInnerGlow = "gamepad-actionbar-squareslot-channel",
		castFillMask = "UI-HUD-ActionBar-IconFrame-Mask",
		castEndMask = "gamepad-actionbar-squareslot-castend-mask",
		-- { innerGlow, castFill, castFillMask, endMask } size offsets
		castOffsets = { collapsed = { -4, -4, 10, 11 }, expanded = { -6, -6, 10, 17 } },
	},
	circle = {
		size = { collapsed = 30, expanded = 38 },
		mask = "CircleMask",
		shadow = "gamepad-actionbar-circleslot-dropshadow",
		shadowFocus = "gamepad-actionbar-focus-bg-circ",
		normal = "gamepad-actionbar-circleslot-border-normal",
		pushed = "gamepad-actionbar-circleslot-border-pressed",
		highlight = "gamepad-actionbar-circleslot-border-hover",
		checked = "gamepad-actionbar-circleslot-border-selected",
		spellHighlight = "gamepad-actionbar-circleslot-border-hover",
		border = "gamepad-actionbar-circleslot-iconframe-border",
		reticleBase = "gamepad-actionbar-circleslot-aoetarget",
		reticleMask = "gamepad-actionbar-circleslot-aoetarget-mask",
		interruptBase = "gamepad-actionbar-circleslot-interrupt",
		interruptMask = "gamepad-actionbar-circleslot-interrupt-mask",
		interruptBaseOffset = 3,
		interruptMaskOffset = 3,
		autoCastCorners = "gamepad-actionbar-circleslot-petautocastcorners",
		autoCastMask = "gamepad-actionbar-circleslot-petautocast-mask",
		autoCastCornersOffset = 3,
		castInnerGlow = "gamepad-actionbar-circleslot-casting",
		channelInnerGlow = "gamepad-actionbar-circleslot-channel",
		castFillMask = "CircleMask",
		castEndMask = "gamepad-actionbar-circleslot-castend-mask",
		castOffsets = { collapsed = { -6, -6, -6, 2 }, expanded = { -8, -8, -6, 3 } },
		swipe = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	},
}

-- Empty-slot glyph art per input device icon set (InputDeviceIconSetManager), indexed by slot.
local DPAD_EMPTY = {
	"gamepad-actionbar-squareslot-generic-dpadleft-normal",
	"gamepad-actionbar-squareslot-generic-dpadup-normal",
	"gamepad-actionbar-squareslot-generic-dpadright-normal",
	"gamepad-actionbar-squareslot-generic-dpaddown-normal",
}
local FACE_EMPTY = {
	Generic = { "x", "y", "b", "a" },
	Letters = { "x", "y", "b", "a" },
	Reverse = { "y", "x", "a", "b" },
	Shapes = { "square", "triangle", "circle", "cross" },
}

function Style:GetShapeForSlot(index)
	return index <= 4 and "square" or "circle"
end

function Style:GetButtonSize(index, focus)
	return SHAPES[self:GetShapeForSlot(index)].size[focus]
end

function Style:GetEmptySlotAtlas(index)
	if index <= 4 then
		return DPAD_EMPTY[index]
	end
	local iconSet = InputDeviceIconSetManager and InputDeviceIconSetManager:GetActiveInputDeviceIconSet() or "Generic"
	local glyph = (FACE_EMPTY[iconSet] or FACE_EMPTY.Generic)[index - 4]
	local family = iconSet == "Shapes" and "ps" or "xbox"
	return ("gamepad-actionbar-circleslot-%s-%s-normal"):format(family, glyph)
end

-- Blizzard's XML masks use CLAMPTOBLACKADDITIVE wrapping, so anything drawn outside the mask bounds (like the
-- oversized Back icon) is clipped. Atlases can't set a wrap mode from Lua, so circles use the equivalent mask file.
local CIRCLE_MASK_FILE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function CreateMask(button, atlas)
	local mask = button:CreateMaskTexture()
	if atlas == "CircleMask" then
		mask:SetTexture(CIRCLE_MASK_FILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	else
		mask:SetAtlas(atlas)
	end
	mask:SetPoint("TOPLEFT", 3, -3)
	mask:SetPoint("BOTTOMRIGHT", -3, 3)
	return mask
end

local function UpdateCastAnim(button)
	local shape = SHAPES[button.ccsShape]
	local offsets = shape.castOffsets[button.ccsFocus or "collapsed"]
	local frame = button.SpellCastAnimFrame
	if not frame then
		return
	end
	local width, height = button:GetSize()
	local fill, burst = frame.Fill, frame.EndBurst
	local fromRight = button.ccsCastFromRight

	fill.InnerGlowTexture:SetPoint("CENTER", button)
	fill.InnerGlowTexture:SetSize(width + offsets[1], height + offsets[1])

	local fillOffset = fromRight and width or -width
	fill.CastFill:SetPoint("CENTER", button, fillOffset, 0)
	fill.CastingAnim.CastFillTranslation:SetOffset(-fillOffset, 0)
	fill.CastFill:SetSize(width + offsets[2], height + offsets[2])

	fill.FillMask:SetPoint("CENTER", button)
	fill.FillMask:SetSize(width + offsets[3], height + offsets[3])

	burst.EndMask:SetPoint("CENTER", button)
	burst.EndMask:SetSize(width + offsets[4], height + offsets[4])
end

-- Replaces BaseActionButton's cast animation atlases with the gamepad shape variants.
local function SetupCastAnimAtlases(button, isChannelCast)
	local shape = SHAPES[button.ccsShape]
	local fill, burst = button.SpellCastAnimFrame.Fill, button.SpellCastAnimFrame.EndBurst
	fill.FillMask:SetAtlas(shape.castFillMask)
	burst.EndMask:SetAtlas(shape.castEndMask)
	if isChannelCast then
		fill.InnerGlowTexture:SetAtlas(shape.channelInnerGlow, true)
		fill.CastFill:SetAtlas("gamepad-hud-actionbar-channel-fill")
		burst.GlowRing:SetAtlas("gamepad-hud-actionbar-channel-complete-glow")
	else
		fill.InnerGlowTexture:SetAtlas(shape.castInnerGlow, true)
		fill.CastFill:SetAtlas("gamepad-hud-actionbar-cast-fill")
		burst.GlowRing:SetAtlas("gamepad-hud-actionbar-casting-complete-glow")
	end
	button.ccsCastFromRight = isChannelCast
	UpdateCastAnim(button)
end

local function AnchorInset(region, offset)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", offset, -offset)
	region:SetPoint("BOTTOMRIGHT", -offset, offset)
end

-- One-time setup of a button created from ActionButtonTemplate/ActionBarButtonTemplate (GamepadActionBarButtonMixin:OnLoad,
-- UpdateButtonArtAnchoring and SetShapeTo<Shape>).
function Style:ApplyButtonArt(button, index)
	local shapeKey = self:GetShapeForSlot(index)
	local shape = SHAPES[shapeKey]
	button.ccsShape = shapeKey
	button.ccsIndex = index

	button.SlotBackground:Hide()
	if button.CooldownFlash then button.CooldownFlash:SetAlpha(0) end
	if button.HotKey then button.HotKey:SetAlpha(0) end

	-- Shape mask replaces the generic icon mask.
	button.IconMask:Hide()
	button.ccsMask = CreateMask(button, shape.mask)
	button.icon:AddMaskTexture(button.ccsMask)
	button.Flash:AddMaskTexture(button.ccsMask)

	button.ccsShadow = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	button.ccsShadow:SetAtlas(shape.shadow)
	button.ccsShadowFocus = button:CreateTexture(nil, "BACKGROUND", nil, -1)
	button.ccsShadowFocus:SetAtlas(shape.shadowFocus)
	button.ccsShadowFocus:Hide()

	for _, region in ipairs({ button.Flash, button.Border, button.NewActionTexture, button.SpellHighlightTexture,
		button.NormalTexture, button.PushedTexture, button.HighlightTexture, button.CheckedTexture, button.AutoCastOverlay }) do
		if region then
			region:ClearAllPoints()
			region:SetAllPoints(button)
		end
	end

	button:SetNormalAtlas(shape.normal)
	button:SetPushedAtlas(shape.pushed)
	button.HighlightTexture:SetAtlas(shape.highlight)
	button:SetCheckedTexture(shape.checked)
	button.SpellHighlightTexture:SetAtlas(shape.spellHighlight)
	button.Border:SetAtlas(shape.border)
	if shape.swipe then
		button.cooldown:SetSwipeTexture(shape.swipe)
	end
	button.SlotArt:SetAtlas(self:GetEmptySlotAtlas(index))

	local reticle = button.TargetReticleAnimFrame
	if reticle then
		reticle:ClearAllPoints()
		reticle:SetAllPoints()
		reticle.Base:ClearAllPoints()
		reticle.Base:SetAllPoints()
		reticle.Base:SetAtlas(shape.reticleBase)
		reticle.Highlight:SetAtlas("gamepad-actionbar-targeting-overlayglow")
		AnchorInset(reticle.Highlight, -7)
		reticle.Mask:SetAtlas(shape.reticleMask)
		AnchorInset(reticle.Mask, -5)
	end

	local interrupt = button.InterruptDisplay
	if interrupt then
		interrupt.Base.Base:SetAtlas(shape.interruptBase)
		interrupt.Base.Base:ClearAllPoints()
		interrupt.Base.Base:SetAllPoints()
		AnchorInset(interrupt.Base, shape.interruptBaseOffset)
		interrupt.Highlight:ClearAllPoints()
		interrupt.Highlight:SetAllPoints()
		interrupt.Highlight.Mask:SetAtlas(shape.interruptMask)
		AnchorInset(interrupt.Highlight.Mask, -shape.interruptMaskOffset)
		interrupt.Highlight.HighlightTexture:SetAtlas("gamepad-actionbar-interrupt-overlayglow")
	end

	local autoCast = button.AutoCastOverlay
	if autoCast and autoCast.Corners then
		autoCast.Corners:SetAtlas(shape.autoCastCorners)
		AnchorInset(autoCast.Corners, shape.autoCastCornersOffset)
		autoCast.Mask:SetAtlas(shape.autoCastMask)
		autoCast.Shine:SetAtlas("gamepad-actionbar-petautocast-ants")
		autoCast.Shine:ClearAllPoints()
		autoCast.Shine:SetAllPoints()
	end

	if button.SpellCastAnimFrame then
		button.SpellCastAnimFrame.SetupAnimAtlases = function(_, isChannelCast) SetupCastAnimAtlases(button, isChannelCast) end
	end
end

-- Visual part of collapse/expand (shadows, checked border, animation anchors). The size and position of secure
-- buttons is set by the restricted layout snippet in Bars.lua; this only touches textures, which is allowed in combat.
function Style:ApplyFocus(button, focus)
	button.ccsFocus = focus
	local expanded = focus == Style.FOCUS.EXPANDED
	local distance = SHADOW_DISTANCE[focus]

	button.ccsShadow:SetShown(not expanded)
	button.ccsShadowFocus:SetShown(expanded)
	AnchorInset(expanded and button.ccsShadowFocus or button.ccsShadow, -distance)

	if expanded then
		AnchorInset(button.CheckedTexture, -CHECKED_DISTANCE)
	else
		button.CheckedTexture:ClearAllPoints()
		button.CheckedTexture:SetAllPoints(button)
	end

	local interrupt = button.InterruptDisplay
	if interrupt then
		local height = button:GetHeight()
		interrupt.Highlight.HighlightTexture:SetPoint("CENTER", 0, height)
		interrupt.Highlight.AnimIn.Translation:SetOffset(0, -(height * 2.5))
	end
	if button.AutoCastOverlay and button.AutoCastOverlay.Mask then
		AnchorInset(button.AutoCastOverlay.Mask, expanded and -4 or -2)
	end
	UpdateCastAnim(button)
end

-- Refresh empty-slot glyphs when the controller icon set changes (e.g. Xbox <-> PlayStation).
function Style:RefreshEmptySlotArt(buttons)
	for _, button in ipairs(buttons) do
		if button.ccsIndex then
			button.SlotArt:SetAtlas(self:GetEmptySlotAtlas(button.ccsIndex))
		end
	end
end

CCS.RegisterModule("Style", Style)
