local _, CCS = ...

local Slots = {}

-- Mirrors GamepadActionBarBindingUtil.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID, re-implemented
-- so our values never come from (or flow back into) Blizzard's gamepad code.
local BAR_OFFSET = { top = 0, left = 8, right = 16, bottom = 24 }
local SLOTS_PER_PAGE = 32
local FIRST_RESERVED = 5
local NUM_RESERVED = 4

function Slots:GetPageUnitSlotID(bar, index)
	return BAR_OFFSET[bar] + index
end

function Slots:IsReserved(bar, index)
	local id = self:GetPageUnitSlotID(bar, index)
	return id >= FIRST_RESERVED and id < FIRST_RESERVED + NUM_RESERVED
end

-- Returns the action slot for a bar button on a page, or nil for Blizzard's reserved top-bar face buttons.
function Slots:GetActionSlot(bar, index, page)
	page = page or 1
	if self:IsReserved(bar, index) then
		return nil
	end

	local id = self:GetPageUnitSlotID(bar, index)
	local first = C_GamepadUI.GetFirstGamepadActionStorageSlotIndex()
	local slot = first + SLOTS_PER_PAGE * (page - 1) + (id - 1) - NUM_RESERVED * (page - 1)
	if id >= FIRST_RESERVED then
		slot = slot - NUM_RESERVED
	end
	return slot
end

CCS.RegisterModule("Slots", Slots)
