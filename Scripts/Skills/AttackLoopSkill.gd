extends Skill
class_name AttackLoopSkill

# --- NÓS DA CENA ---
@onready var cooldown_timer: Timer = $CooldownTimer

# --- PRELOADS ---
const RicochetProjectileScene = preload("res://Scenes/Projectiles/RicochetProjectile.tscn")

# --- STATS DA HABILIDADE ---
var mana_cost: int = 8
var damage: int = 1
var max_bounces: int = 2
var cooldown_time: float = 3.0

var can_use: bool = true

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	# (Futuramente, vamos popular os stats acima a partir do self.skill_data)

# Esta função SOBRESCREVE a função "_execute" do nosso "contrato" Skill.gd
func _execute():
	# 1. Verifica as condições de uso
	if not can_use or not is_instance_valid(player) or player.mana < mana_cost:
		if is_instance_valid(player) and player.mana < mana_cost:
			print("Mana insuficiente para o Loop de Dano!")
		return

	# 2. Prepara a habilidade
	can_use = false
	player.use_mana(mana_cost)
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.start()
	player.skill_e_cooldown_started.emit(cooldown_time) # Avisa a HUD

	print("Executando Loop de Dano (versão componente)!")

	# 3. Executa a lógica de instanciar o projétil
	var projectile_instance = RicochetProjectileScene.instantiate()
	# Adiciona o projétil à cena principal para que ele não seja filho do jogador
	get_tree().current_scene.add_child(projectile_instance)
	
	# Configura o projétil
	projectile_instance.global_position = player.global_position
	projectile_instance.setup_projectile(player.last_direction, damage, max_bounces)

func _on_cooldown_finished():
	can_use = true
