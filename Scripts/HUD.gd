extends CanvasLayer

var player: Node

@onready var health_bar_fill: NinePatchRect = $HealthBarContainer/HealthBarFill
@onready var mana_bar_fill: NinePatchRect = $ManaBarContainer/ManaBarFill
@onready var damage_flash = $DamageFlash
@onready var skill_q_cooldown_overlay = $SkillBarContainer/SkillSlotQ/SkillQ_CooldownOverlay
@onready var skill_q_icon = $SkillBarContainer/SkillSlotQ/SkillQ_Icon
@onready var skill_q_cost_label = $SkillBarContainer/SkillSlotQ/CostLabel
@onready var skill_e_icon = $SkillBarContainer/SkillSlotE/SkillE_Icon
@onready var skill_e_cooldown_overlay = $SkillBarContainer/SkillSlotE/SkillE_CooldownOverlay
@onready var skill_e_cost_label = $SkillBarContainer/SkillSlotE/CostLabel

@onready var active_item_slot = $ActiveItemSlot
@onready var active_item_icon = $ActiveItemSlot/ItemIcon
@onready var active_item_quantity = $ActiveItemSlot/QuantityLabel

var max_health_bar_width: float = 0.0
var max_mana_bar_width: float = 0.0

func _ready():
	await get_tree().process_frame
	if is_instance_valid(health_bar_fill):
		max_health_bar_width = health_bar_fill.size.x
	if is_instance_valid(mana_bar_fill):
		max_mana_bar_width = mana_bar_fill.size.x

# Atualiza habilidades equipadas
func update_equipped_skills(equipped_q: Skill, equipped_e: Skill):
	if is_instance_valid(equipped_q):
		var skill_data_q = equipped_q.skill_data
		skill_q_icon.texture = skill_data_q.icon
		skill_q_cost_label.text = str(skill_data_q.mana_cost)
		skill_q_icon.visible = true
		skill_q_cost_label.visible = true
	else:
		skill_q_icon.visible = false
		skill_q_cost_label.visible = false

	if is_instance_valid(equipped_e):
		var skill_data_e = equipped_e.skill_data
		skill_e_icon.texture = skill_data_e.icon
		skill_e_cost_label.text = str(skill_data_e.mana_cost)
		skill_e_icon.visible = true
		skill_e_cost_label.visible = true
	else:
		skill_e_icon.visible = false
		skill_e_cost_label.visible = false

# Atualiza vida
func update_health(new_value: float, max_value: float):
	if max_health_bar_width == 0: return
	var health_percent = new_value / max_value if max_value > 0 else 0.0
	health_bar_fill.size.x = max_health_bar_width * health_percent

# Atualiza mana
func update_mana(new_value: float, max_value: float):
	if max_mana_bar_width == 0: return
	var mana_percent = new_value / max_value if max_value > 0 else 0.0
	mana_bar_fill.size.x = max_mana_bar_width * mana_percent

	if is_instance_valid(player) and is_instance_valid(player.equipped_skill_q):
		var has_mana_for_q = new_value >= player.equipped_skill_q.mana_cost
		skill_q_icon.modulate.a = 1.0 if has_mana_for_q else 0.5
		skill_q_cost_label.modulate.a = 1.0 if has_mana_for_q else 0.5

	if is_instance_valid(player) and is_instance_valid(player.equipped_skill_e):
		var has_mana_for_e = new_value >= player.equipped_skill_e.mana_cost
		skill_e_icon.modulate.a = 1.0 if has_mana_for_e else 0.5
		skill_e_cost_label.modulate.a = 1.0 if has_mana_for_e else 0.5

# Feedback visual
func flash_screen():
	if not is_instance_valid(damage_flash): return
	damage_flash.z_index = 100
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_flash, "modulate:a", 0.2, 0.04)
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): damage_flash.z_index = 0)

# Cooldown visual
func start_cooldown_visual(slot: String, duration: float):
	var icon: TextureRect
	var overlay: TextureProgressBar

	match slot:
		"q":
			icon = skill_q_icon
			overlay = skill_q_cooldown_overlay
		"e":
			icon = skill_e_icon
			overlay = skill_e_cooldown_overlay
		_:
			return

	if not is_instance_valid(overlay) or not is_instance_valid(icon):
		return

	overlay.value = 1.0
	overlay.max_value = 1.0
	overlay.visible = true
	icon.modulate = Color(0.5, 0.5, 0.5, 1.0)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(overlay, "value", 0.0, duration)
	tween.chain().tween_callback(func():
		overlay.visible = false
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)

# Atualiza slot de item ativo
# ⚠️ Agora os parâmetros estão na ordem correta e usamos 'inventory' como no World
func update_active_item_display(inventory: Dictionary, current_active_item: ItemData):
	if not current_active_item:
		active_item_slot.visible = false
		return

	active_item_slot.visible = true
	active_item_icon.texture = current_active_item.item_icon

	if inventory.has(current_active_item):
		var quantity = inventory[current_active_item]["quantity"]
		active_item_quantity.text = str(quantity)
		active_item_quantity.visible = current_active_item.is_stackable
	else:
		active_item_slot.visible = false
