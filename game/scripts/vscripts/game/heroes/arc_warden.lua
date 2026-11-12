-- Arc Warden: four custom ability branches and wave-RPG perk definitions.
ArcWarden = ArcWarden or {}

local BUILDS = {
	flux = "Изолировать и уничтожить (Flux)",
	field = "Вынужденный союз (Magnetic Field)",
	wraith = "Ночь призраков (Spark Wraith)",
	tempest = "Эхо двойника (Tempest Double)",
}
local function mythic(id, build, name, desc) return { id=id, tier=5, build=build, max=1, name=name, desc=desc } end
local function legend(id, build, name, desc) return { id=id, tier=4, build=build, requires_build=build, max=1, name=name, desc=desc } end
local function epic(id, build, name, desc) return { id=id, tier=3, build=build, requires_build=build, max=1, name=name, desc=desc } end

local PERKS = {
	-- Flux
	mythic("m_flux_spread", "flux", "Изолировать и уничтожить", "Flux не сбрасывается из-за других врагов и сразу распространяется на противников в радиусе 800 от цели."),
	legend("l_flux_jump", "flux", "Тщетность бытия", "Смерть цели под Flux переносит эффект на трёх ближайших врагов с полной длительностью."),
	legend("l_flux_barrier", "flux", "Лучшая защита", "60% урона Flux превращается в барьер Arc Warden."),
	legend("l_flux_boss_stun", "flux", "Вместо замедления", "Каждый тик Flux оглушает босса на 0,2 с вместо замедления."),
	legend("l_flux_range", "flux", "Масштаб космоса", "Радиус применения Flux увеличен на 800."),
	epic("e_flux_field_cd", "flux", "Страховка", "Смерть врага под Flux сокращает перезарядку Magnetic Field на 0,2 с."),
	epic("e_flux_wraith_amp", "flux", "Дурная метка", "Цели под Flux получают на 20% больше урона Spark Wraith."),
	epic("e_flux_heal", "flux", "Пир во время чумы", "Flux лечит Arc Warden на 1,5% нанесённого урона."),
	epic("e_flux_burst", "flux", "Шок и трепет", "Flux наносит 500 магического урона при наложении."),
	epic("e_flux_int", "flux", "Интеллект во благо", "Flux наносит +200 урона за каждые 50 интеллекта."),
	epic("e_flux_boss_pct", "flux", "И короли падут", "Flux наносит боссам суммарно 5% максимального здоровья."),
	epic("e_flux_cooldown", "flux", "Ускоренное искажение", "Перезарядка Flux сокращена на 30%."),
	epic("e_flux_mana", "flux", "Связь", "Атаки по цели под Flux восстанавливают 2% максимальной маны."),
	-- Magnetic Field
	mythic("m_field_shield", "field", "Вынужденный союз", "Magnetic Field заменяет уклонение щитом: Arc Warden и союзники внутри блокируют 60% физического урона. Заблокированный урон навсегда увеличивает максимальное здоровье Arc Warden. Tempest Double погибает при создании."),
	legend("l_field_reflect", "field", "Зеркало", "Половина заблокированного урона импульсом возвращается чистым уроном врагам в радиусе 600."),
	legend("l_field_gravity", "field", "Гравитация", "Союзники внутри поля невосприимчивы к оглушению, замедлению и перемещению."),
	legend("l_field_compensation", "field", "Компенсация", "Каждая единица заблокированного урона восстанавливает Arc Warden и его двойнику 5% этого значения как здоровье и ману."),
	legend("l_field_density", "field", "Уплотнение материи", "За каждые 250 силы щит Magnetic Field блокирует ещё 10% урона."),
	epic("e_field_guests", "field", "Гостям здесь не рады", "Враги внутри поля теряют 50% брони, сопротивления магии и урона атак (не действует на боссов)."),
	epic("e_field_armor", "field", "Стальной купол", "Союзники внутри поля получают +20 брони."),
	epic("e_field_radius", "field", "Расширение материи", "Радиус Magnetic Field увеличен на 400."),
	epic("e_field_slow", "field", "Заземление", "Враги внутри Magnetic Field замедлены на 40%."),
	epic("e_field_duration", "field", "Стабильная материя", "Длительность Magnetic Field увеличена на 2 с."),
	epic("e_field_mana", "field", "Готов к обороне", "Вход врага в поле восстанавливает 2% максимальной маны Arc Warden."),
	epic("e_field_heal_amp", "field", "Монолитная защита", "Внутри купола Arc Warden получает +30% к исцелению и вампиризму."),
	epic("e_field_echo", "field", "Эхо защиты", "После исчезновения поля союзники получают +10 брони на 3 с."),
	-- Spark Wraith
	mythic("m_wraith_night", "wraith", "Ночь призраков", "Spark Wraith создаёт сразу девять духов."),
	legend("l_wraith_echo", "wraith", "Неупокоенная душа", "После попадания дух перескакивает на ближайшего врага ещё до двух раз."),
	legend("l_wraith_grave", "wraith", "Утащить в могилу", "Попадание замедляет цель на 75% на 6 с, накладывает оцепенение на 2 с и наносит урон от интеллекта."),
	legend("l_wraith_ghost", "wraith", "Призрачная искра", "Дух наносит дополнительный периодический урон в размере 50% своего урона плюс урон от интеллекта."),
	legend("l_wraith_axiom", "wraith", "Аксиома: перманент", "Arc Warden и его двойник получают +20 интеллекта каждую минуту."),
	epic("e_wraith_radius", "wraith", "От смерти не уйти", "Радиус обнаружения Spark Wraith увеличен на 700."),
	epic("e_wraith_int", "wraith", "Вечная жизнь", "Spark Wraith наносит дополнительный урон в размере 40% интеллекта."),
	epic("e_wraith_mana", "wraith", "Дементор", "С шансом 15% попадание восстанавливает ману в размере нанесённого урона, до полного запаса."),
	epic("e_wraith_age", "wraith", "Очередной прожитый век", "Урон Spark Wraith растёт на 10% каждые 5 минут."),
	epic("e_wraith_inferno", "wraith", "Инферно", "Дух поджигает цель, замедляет на 30% и наносит 3% максимального здоровья за 5 с."),
	epic("e_wraith_legion", "wraith", "Имя нам Легион", "С шансом 25% создаётся дополнительный Spark Wraith."),
	epic("e_wraith_health", "wraith", "Твоё здоровье", "Попадание восстанавливает 2% здоровья Arc Warden."),
	epic("e_wraith_speed", "wraith", "Вселенская мудрость", "+50 к скорости передвижения."),
	-- Tempest Double
	mythic("m_tempest_identity", "tempest", "Диссоциативное расстройство идентичности", "Tempest Double становится постоянным полноценным и управляемым героем с отдельным инвентарём; предметы в его рюкзаке действуют. Arc Warden и двойник теряют Flux, Magnetic Field и Spark Wraith."),
	legend("l_tempest_thunder", "tempest", "Гром и молния", "Атаки бьют по области 300; с шансом 45% выпускают молнию с магическим уроном от ловкости Arc Warden, а с шансом 15% оглушают на 0,5 с."),
	legend("l_tempest_autonomy", "tempest", "Автономность", "Клон получает от предметов в 1,5 раза больше атрибутов."),
	legend("l_tempest_ghost", "tempest", "Вечная самость", "Перед гибелью двойник становится призраком на 5 с, затем умирает."),
	legend("l_tempest_multishot", "tempest", "Массовое уничтожение", "Атаки Arc Warden поражают до трёх целей в радиусе 1200; двойник не промахивается."),
	epic("e_tempest_speed", "tempest", "Стремительность", "Tempest Double постоянно передвигается со скоростью 550."),
	epic("e_tempest_shard", "tempest", "Третий осколок конфликта", "Каждую минуту после выбора перка Arc Warden получает +5 ко всем атрибутам, двойник — +10."),
	epic("e_tempest_boss", "tempest", "Коллекционер черепов", "Убийство босса даёт Arc Warden +50 урона, +25 скорости атаки и +500 здоровья; двойник получает в 1,5 раза больше."),
	epic("e_tempest_friendly", "tempest", "Сопутствующий ущерб", "Двойник может атаковать союзников; каждая такая атака даёт +25 урона и скорости атаки на 10 с, до 10 стаков."),
	epic("e_tempest_intro", "tempest", "Пафосный дебют", "Появление двойника создаёт взрыв с базовым уроном, увеличенным на 50% за каждую единицу ловкости Arc Warden."),
	epic("e_tempest_runes", "tempest", "Усиление", "Каждые 2 минуты двойник получает руны Щита, Ускорения, Регенерации и Волшебства на 40 с."),
	epic("e_tempest_heal", "tempest", "Стокгольмский синдром", "Атаки Arc Warden по своему двойнику исцеляют его на 3% максимального здоровья."),
	epic("e_tempest_cooldown", "tempest", "Теория пространства-времени", "Перезарядка Tempest Double уменьшена на 30%."),
	-- Ordinary and rare linear scaling: generic common perks are shared by all heroes.
	{ id="r_flux_damage", tier=2, max=20, name="Усиленный разряд", desc="+80 урона Flux", arc={flux_damage=80} },
	{ id="r_flux_duration", tier=2, max=10, name="Долгая изоляция", desc="+0,4 с к Flux", arc={flux_duration=0.4} },
	{ id="r_field_duration", tier=2, max=10, name="Устойчивый купол", desc="+0,4 с к Magnetic Field", arc={field_duration=0.4} },
	{ id="r_field_radius", tier=2, max=10, name="Широкое поле", desc="+50 к радиусу Magnetic Field", arc={field_radius=50} },
	{ id="r_wraith_damage", tier=2, max=20, name="Сильный дух", desc="+100 урона Spark Wraith", arc={wraith_damage=100} },
	{ id="r_wraith_radius", tier=2, max=10, name="Дальний поиск", desc="+100 к радиусу Spark Wraith", arc={wraith_radius=100} },
	{ id="r_tempest_duration", tier=2, max=10, name="Долгий двойник", desc="+1 с к Tempest Double", arc={tempest_duration=1} },
	{ id="r_arc_stats", tier=2, max=20, name="Магнитный импульс", desc="+15 интеллекта и +5 к силе умений", stats={int=15, spellamp=5} },
}

RPG.HEROES["npc_dota_hero_arc_warden"] = {
	modifier = "modifier_rpg_arc_master",
	builds = BUILDS,
	perks = PERKS,
	on_kill = function(hero, _, victim) ArcWarden:OnKill(hero, victim) end,
}

function ArcWarden:OnKill(hero, victim)
	if not IsServer() or not hero or not victim then return end
	if hero.rpg and (hero.rpg.perk_count.e_flux_field_cd or 0) > 0 and victim:HasModifier("modifier_rpg_arc_flux") then
		local field = hero:FindAbilityByName("rpg_arc_warden_magnetic_field")
		if field then local remaining=field:GetCooldownTimeRemaining(); if remaining>0 then field:EndCooldown(); field:StartCooldown(math.max(0,remaining-0.2)) end end
	end
end
