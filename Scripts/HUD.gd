extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var mana_bar = $ManaBar # NOVO: Referência para a barra de mana
@onready var damage_flash = $DamageFlash
@onready var skill_q_cooldown_overlay = $SkillBarContainer/SkillSlotQ/SkillQ_CooldownOverlay
@onready var skill_q_icon = $SkillBarContainer/SkillSlotQ/SkillQ_Icon
@onready var skill_q_cost_label = $SkillBarContainer/SkillSlotQ/CostLabel # NOVO
@onready var skill_e_icon = $SkillBarContainer/SkillSlotE/SkillE_Icon
@onready var skill_e_cooldown_overlay = $SkillBarContainer/SkillSlotE/SkillE_CooldownOverlay
@onready var skill_e_cost_label = $SkillBarContainer/SkillSlotE/CostLabel # NOVO
# Adicione estas referências no topo do script
@onready var active_item_slot = $ActiveItemSlot
@onready var active_item_icon = $ActiveItemSlot/ItemIcon
@onready var active_item_quantity = $ActiveItemSlot/QuantityLabel
# Adicione estas variáveis no topo do script
var skill_q_mana_cost: int = 0
var skill_e_mana_cost: int = 0

# Adicione esta nova função ao script
func set_skill_mana_costs(q_cost: int, e_cost: int):
	skill_q_mana_cost = q_cost
	skill_e_mana_cost = e_cost
	# NOVO: Atualiza o texto dos labels de custo assim que os recebe
	skill_q_cost_label.text = str(q_cost)
	skill_e_cost_label.text = str(e_cost)	

# --- Funções de Vida ---
func set_max_health(max_value):
	health_bar.max_value = max_value
	health_bar.value = max_value

func update_health(new_value):
	health_bar.value = new_value

# --- Funções de Mana (NOVAS) ---
func set_max_mana(max_value):
	mana_bar.max_value = max_value
	mana_bar.value = max_value

func update_mana(new_value):
	mana_bar.value = new_value
	
	var has_mana_for_q = new_value >= skill_q_mana_cost
	skill_q_icon.modulate.a = 1.0 if has_mana_for_q else 0.5
	skill_q_cost_label.modulate.a = 1.0 if has_mana_for_q else 0.5 # NOVO: Modula o custo também
	
	var has_mana_for_e = new_value >= skill_e_mana_cost
	skill_e_icon.modulate.a = 1.0 if has_mana_for_e else 0.5
	skill_e_cost_label.modulate.a = 1.0 if has_mana_for_e else 0.5 # NOVO: Modula o custo também

# --- Funções de Feedback Visual ---
func flash_screen():
	if not is_instance_valid(damage_flash):
		return
	damage_flash.z_index = 100
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_flash, "modulate:a", 0.2, 0.04)
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): damage_flash.z_index = 0)
	
func start_skill_q_cooldown_visual(duration):
	if not is_instance_valid(skill_q_cooldown_overlay) or not is_instance_valid(skill_q_icon):
		return
	skill_q_cooldown_overlay.value = 1.0 
	skill_q_cooldown_overlay.max_value = 1.0 
	skill_q_cooldown_overlay.visible = true
	skill_q_icon.modulate = Color(0.5, 0.5, 0.5, 1.0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(skill_q_cooldown_overlay, "value", 0.0, duration)
	tween.chain().tween_callback(func(): 
		skill_q_cooldown_overlay.visible = false
		skill_q_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	) 
	
func start_skill_e_cooldown_visual(duration):
	if not is_instance_valid(skill_e_cooldown_overlay) or not is_instance_valid(skill_e_icon):
		return
	skill_e_cooldown_overlay.value = 1.0 
	skill_e_cooldown_overlay.max_value = 1.0 
	skill_e_cooldown_overlay.visible = true
	skill_e_icon.modulate = Color(0.5, 0.5, 0.5, 1.0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(skill_e_cooldown_overlay, "value", 0.0, duration)
	tween.chain().tween_callback(func(): 
		skill_e_cooldown_overlay.visible = false
		skill_e_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)
	
# Adicione esta nova função ao final do script
func update_active_item_display(item_data: ItemData, inventory_data: Dictionary):
	# Se não há item ativo, esconde o slot
	if not item_data:
		active_item_slot.visible = false
		return
	
	# Se há um item ativo, mostra o slot e atualiza as informações
	active_item_slot.visible = true
	active_item_icon.texture = item_data.item_icon
	
	# Procura a quantidade atual do item no inventário
	if inventory_data.has(item_data):
		var quantity = inventory_data[item_data]["quantity"]
		active_item_quantity.text = str(quantity)
		active_item_quantity.visible = item_data.is_stackable # Mostra quantidade só se for empilhável
	else:
		# Isso pode acontecer se o item for usado e a quantidade chegar a zero
		active_item_slot.visible = false
