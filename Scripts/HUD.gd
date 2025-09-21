extends CanvasLayer

@onready var health_bar = $ProgressBar
@onready var damage_flash = $DamageFlash # NOVO: Referência ao ColorRect
@onready var skill_q_cooldown_overlay = $SkillBarContainer/SkillSlotQ/SkillQ_CooldownOverlay # NOVO: Referência ao overlay
@onready var skill_q_icon = $SkillBarContainer/SkillSlotQ/SkillQ_Icon # NOVO: Referência ao TextureRect do ícone
@onready var skill_e_icon = $SkillBarContainer/SkillSlotE/SkillE_Icon # NOVO
@onready var skill_e_cooldown_overlay = $SkillBarContainer/SkillSlotE/SkillE_CooldownOverlay # NOVO
# Esta função define os valores iniciais da barra
func set_max_health(max_value):
	health_bar.max_value = max_value
	health_bar.value = max_value

# Esta função atualiza a barra sempre que o sinal for recebido
func update_health(new_value):
	health_bar.value = new_value

# NOVO: Função para piscar a tela
func flash_screen():
	# Certifica-se de que o nó existe e está pronto
	if not is_instance_valid(damage_flash):
		return

	# Para ter certeza que o flash aparece acima de tudo na HUD
	damage_flash.z_index = 100 # Um valor alto para sobrepor outros elementos da HUD

	# Cria um Tween para animar a transparência do flash
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR) # Transição linear para um flash rápido
	tween.set_ease(Tween.EASE_OUT)     # Efeito de saída suave

	# Anima a opacidade de 0 (invisível) para 0.7 (quase opaco) em 0.05 segundos
	tween.tween_property(damage_flash, "modulate:a", 0.2, 0.04)
	# Anima a opacidade de volta para 0 (invisível) em 0.15 segundos
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.15)

	tween.tween_callback(func(): damage_flash.z_index = 0) # Reseta z_index após o flash
	

func start_skill_q_cooldown_visual(duration):
	if not is_instance_valid(skill_q_cooldown_overlay) or not is_instance_valid(skill_q_icon):
		return

	skill_q_cooldown_overlay.value = 1.0 
	skill_q_cooldown_overlay.max_value = 1.0 
	skill_q_cooldown_overlay.visible = true

	# NOVO: Escurece o ícone base da habilidade
	skill_q_icon.modulate = Color(0.5, 0.5, 0.5, 1.0) # Cinza escuro ou cor translúcida

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(skill_q_cooldown_overlay, "value", 0.0, duration)

	# NOVO: Quando o cooldown termina, esconde a barra E clareia o ícone
	tween.chain().tween_callback(func(): 
		skill_q_cooldown_overlay.visible = false
		skill_q_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Volta à cor normal (branco)
	) 
	
func start_skill_e_cooldown_visual(duration):
	if not is_instance_valid(skill_e_cooldown_overlay) or not is_instance_valid(skill_e_icon):
		return

	skill_e_cooldown_overlay.value = 1.0 
	skill_e_cooldown_overlay.max_value = 1.0 
	skill_e_cooldown_overlay.visible = true

	skill_e_icon.modulate = Color(0.5, 0.5, 0.5, 1.0) # Escurece o ícone

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(skill_e_cooldown_overlay, "value", 0.0, duration)

	tween.chain().tween_callback(func(): 
		skill_e_cooldown_overlay.visible = false
		skill_e_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) # Clareia o ícone
	)
