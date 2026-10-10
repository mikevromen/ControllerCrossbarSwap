local _, CCS = ...

local Controller = {}

-- Bar slot order matches Blizzard's gamepad bars (see ActionBindingUtil.lua):
--      02          06
--   01    03    05    07
--      04          08
Controller.SLOT_KEYS = {
	"PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN",
	"PAD3", "PAD4", "PAD2", "PAD1",
}

-- Bars and the modifier prefix that selects them while a trigger is held.
Controller.BARS = { "top", "left", "right", "bottom" }
Controller.BAR_MODIFIERS = {
	top = "",
	left = "SHIFT-",
	right = "CTRL-",
	bottom = "CTRL-SHIFT-",
}

Controller.TRIGGER_LEFT = "PADLTRIGGER"
Controller.TRIGGER_RIGHT = "PADRTRIGGER"

local PROFILES = {
	xbox = {
		name = "Xbox",
		labels = {
			PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y",
			PADDUP = "Up", PADDDOWN = "Down", PADDLEFT = "Left", PADDRIGHT = "Right",
			PADLSHOULDER = "LB", PADRSHOULDER = "RB", PADLTRIGGER = "LT", PADRTRIGGER = "RT",
			PADLSTICK = "LS", PADRSTICK = "RS", PADBACK = "View", PADFORWARD = "Menu",
			PADPADDLE1 = "P1", PADPADDLE2 = "P2", PADPADDLE3 = "P3", PADPADDLE4 = "P4",
		},
	},
}

function Controller:GetProfile()
	return PROFILES[CCS.db and CCS.db.controller or "xbox"] or PROFILES.xbox
end

function Controller:GetLabel(key)
	return self:GetProfile().labels[key] or key
end

CCS.RegisterModule("Controller", Controller)
