-- Снаряжение из магазина + зелье (в одном файле: в KV у всех одинаковый ScriptFile)
LinkLuaModifier("modifier_rpg_item", "modifiers/modifier_rpg_item", LUA_MODIFIER_MOTION_NONE)

item_rpg_weapon = class({})
item_rpg_armor  = class({})
item_rpg_ring   = class({})
item_rpg_potion = class({})

for _, cls in pairs({ item_rpg_weapon, item_rpg_armor, item_rpg_ring }) do
	function cls:GetIntrinsicModifierName() return "modifier_rpg_item" end
end

-- Зелье: лечит 40% здоровья и 25% маны
function item_rpg_potion:OnSpellStart()
	local caster = self:GetCaster()
	caster:Heal(caster:GetMaxHealth() * 0.4, caster)
	caster:GiveMana(caster:GetMaxMana() * 0.25)
	-- Explicitly decrement charges: item_lua does not reliably consume ItemInitialCharges
	-- across custom games when SpendCharge is invoked from OnSpellStart.
	local charges = self:GetCurrentCharges()
	if charges > 1 then
		self:SetCurrentCharges(charges - 1)
	else
		self:SetCurrentCharges(0)
		UTIL_Remove(self)
	end
end
