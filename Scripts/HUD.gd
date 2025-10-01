extends CanvasLayer

var player: Node
@onready var health_bar_fill: NinePatchRect = $HealthBarContainer/HealthBarFill
@onready var mana_bar_fill: NinePatchRect = $ManaBarContainer/ManaBarFill
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


var max_health_bar_width: float = 0.0 # Para guardar a largura máxima
var max_mana_bar_width: float = 0.0 # NOVA variável para a mana
# Adicione estas variáveis no topo do script


func _ready():
	# Espera um frame para que os tamanhos da UI sejam calculados
	await get_tree().process_frame
	# Guarda a largura inicial da barra de preenchimento, que é a sua largura máxima
	if is_instance_valid(health_bar_fill):
		max_health_bar_width = health_bar_fill.size.x
		
	# NOVO: Guarda a largura máxima da barra de mana
	if is_instance_valid(mana_bar_fill):
		max_mana_bar_width = mana_bar_fill.size.x
# SUBSTITUA a sua função 'update_equipped_skills' inteira por esta:
func update_equipped_skills(equipped_q: Skill, equipped_e: Skill):
	# Atualiza o Slot Q
	if is_instance_valid(equipped_q):
		# Acessa os dados (.tres) que estão DENTRO da instância da skill
		var skill_data_q = equipped_q.skill_data
		skill_q_icon.texture = skill_data_q.icon
		skill_q_cost_label.text = str(skill_data_q.mana_cost)
		skill_q_icon.visible = true
		skill_q_cost_label.visible = true
	else: # Se não houver skill, esconde tudo
		skill_q_icon.visible = false
		skill_q_cost_label.visible = false

	# Atualiza o Slot E
	if is_instance_valid(equipped_e):
		# Acessa os dados (.tres) que estão DENTRO da instância da skill
		var skill_data_e = equipped_e.skill_data
		skill_e_icon.texture = skill_data_e.icon
		skill_e_cost_label.text = str(skill_data_e.mana_cost)
		skill_e_icon.visible = true
		skill_e_cost_label.visible = true
	else: # Se não houver skill, esconde tudo
		skill_e_icon.visible = false
		skill_e_cost_label.visible = false


func update_health(new_value: float, max_value: float):
	if max_health_bar_width == 0: # Protecção para o caso de _ready ainda não ter corrido
		return
		
	# Calcula a percentagem de vida
	var health_percent = 0.0
	if max_value > 0:
		health_percent = new_value / max_value
	
	# Ajusta a largura do NinePatchRect de preenchimento
	health_bar_fill.size.x = max_health_bar_width * health_percent



# NOVA função para actualizar a mana
func update_mana(new_value: float, max_value: float):
	if max_mana_bar_width == 0: return

	var mana_percent = 0.0
	if max_value > 0:
		mana_percent = new_value / max_value
	
	mana_bar_fill.size.x = max_mana_bar_width * mana_percent
	
	# Agora a verificação é mais segura
	if is_instance_valid(player) and is_instance_valid(player.equipped_skill_q):
		var has_mana_for_q = new_value >= player.equipped_skill_q.mana_cost
		skill_q_icon.modulate.a = 1.0 if has_mana_for_q else 0.5
		skill_q_cost_label.modulate.a = 1.0 if has_mana_for_q else 0.5
	
	if is_instance_valid(player) and is_instance_valid(player.equipped_skill_e):
		var has_mana_for_e = new_value >= player.equipped_skill_e.mana_cost
		skill_e_icon.modulate.a = 1.0 if has_mana_for_e else 0.5
		skill_e_cost_label.modulate.a = 1.0 if has_mana_for_e else 0.5

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
	
# --- NOVA FUNÇÃO DE COOLDOWN UNIFICADA ---
# Esta função será conectada ao sinal 'skill_used' do Player.
func start_cooldown_visual(slot: String, duration: float):
	var icon: TextureRect
	var overlay: TextureProgressBar
	
	# Decide quais nós da UI afetar com base no slot
	match slot:
		"q":
			icon = skill_q_icon
			overlay = skill_q_cooldown_overlay
		"e":
			icon = skill_e_icon
			overlay = skill_e_cooldown_overlay
		_:
			return # Sai da função se o slot for desconhecido

	if not is_instance_valid(overlay) or not is_instance_valid(icon):
		return

	overlay.value = 1.0
	overlay.max_value = 1.0
	overlay.visible = true
	icon.modulate = Color(0.5, 0.5, 0.5, 1.0) # Escurece o ícone

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(overlay, "value", 0.0, duration)
	tween.chain().tween_callback(func():
		overlay.visible = false
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Volta à cor normal
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
