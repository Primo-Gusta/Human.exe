extends Skill
class_name AttackPulseSkill

# --- NÓS DA CENA ---
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var pulse_visual: Sprite2D = $PulseVisual

# --- STATS DA HABILIDADE ---
# Estes valores serão preenchidos a partir do SkillData
var mana_cost: int = 5
var damage: int = 1
var skill_range: float = 60.0
var cooldown_time: float = 2.0

var can_use: bool = true

func _ready():
	# Conecta o sinal do timer à função que reseta o cooldown
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	# (Futuramente, vamos popular os stats acima a partir do self.skill_data)

# Esta função SOBRESCREVE a função "_execute" do nosso "contrato" Skill.gd
func _execute():
	# 1. Verifica as condições de uso
	if not can_use or not is_instance_valid(player) or player.mana < mana_cost:
		if is_instance_valid(player) and player.mana < mana_cost:
			print("Mana insuficiente para o Pulso de Ataque!")
		return

	# 2. Prepara a habilidade
	can_use = false
	player.use_mana(mana_cost)
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.start()
	player.skill_q_cooldown_started.emit(cooldown_time) # Avisa a HUD

	print("Executando Pulso de Ataque (versão componente)!")

	# 3. Executa a lógica de dano
	var enemies_in_range = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if player.global_position.distance_to(enemy.global_position) <= skill_range:
			enemies_in_range.append(enemy)

	for enemy in enemies_in_range:
		var knockback_direction = (enemy.global_position - player.global_position).normalized()
		enemy.take_damage(damage, knockback_direction)

	# 4. Executa o efeito visual
	play_visual_effect()

func play_visual_effect():
	# Pega o nó visual e o torna um filho temporário do mundo para que ele não se mova com o jogador
	var visual = pulse_visual
	var original_parent = visual.get_parent()
	visual.reparent(get_tree().current_scene)
	visual.global_position = player.global_position # Define a posição inicial

	visual.modulate = Color(0, 1, 1, 0.7)
	visual.scale = Vector2(0.1, 0.1)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(skill_range / 15.0, skill_range / 15.0), 0.2)
	tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	# Quando o tween terminar, retorna o nó visual para seu pai original e reseta
	tween.finished.connect(func():
		visual.reparent(original_parent)
		visual.scale = Vector2(0.1, 0.1)
	)

func _on_cooldown_finished():
	can_use = true
