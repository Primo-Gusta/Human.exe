extends Skill
class_name AttackPulseSkill

# --- NÓS DA CENA ---
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var pulse_visual: AnimatedSprite2D = $PulseVFX

# --- STATS DA HABILIDADE ---
# Estes valores serão preenchidos a partir do SkillData
var mana_cost: int 
var damage: int 
var skill_range: float
var cooldown_time: float
var can_use: bool = true

var resonance_pulse_unlocked: bool = false
var marked_enemies: Array = [] # Lista de inimigos marcados
var explosion_damage: int = 2
var explosion_radius: float = 60.0

func _ready():
	# Conecta o sinal do timer à função que reseta o cooldown
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	# (Futuramente, vamos popular os stats acima a partir do self.skill_data)

# Esta função SOBRESCREVE a função "_execute" do nosso "contrato" Skill.gd
func _execute():
	if not can_use or not is_instance_valid(player) or player.mana < mana_cost:
		if is_instance_valid(player) and player.mana < mana_cost:
			print("Mana insuficiente para o Pulso de Ataque!")
		return

	can_use = false
	player.use_mana(mana_cost)
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.start()
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
		# --- NOVA LÓGICA DE MARCAÇÃO ---
		if resonance_pulse_unlocked and not enemy in marked_enemies:
			_mark_enemy(enemy)
	# 4. Executa o efeito visual
	play_visual_effect()

func play_visual_effect():
	# Pega o nó visual e torna-o um filho temporário do mundo
	var visual = pulse_visual
	var original_parent = visual.get_parent()
	visual.reparent(get_tree().current_scene)
	visual.global_position = player.global_position

	# Define a escala do AnimatedSprite2D para corresponder ao raio da habilidade
	# O '30.0' é um número mágico que depende do tamanho do seu sprite. Ajuste-o
	# até que a explosão tenha o mesmo tamanho da área de dano.
	visual.scale = Vector2(skill_range / 30.0, skill_range / 30.0)
	
	# Toca a animação e espera que ela termine
	visual.play("pulse")
	await visual.animation_finished
	
	# Quando a animação terminar, retorna o nó visual para o seu pai original
	if is_instance_valid(visual) and is_instance_valid(original_parent):
		visual.reparent(original_parent)

func _on_cooldown_finished():
	can_use = true
	
# Esta função é chamada automaticamente quando a variável 'skill_data' é definida
func set_skill_data(new_data: SkillData):
	skill_data = new_data
	if not skill_data: return
	
	# Popula os stats da habilidade com os valores base do Resource
	self.mana_cost = skill_data.mana_cost
	self.cooldown_time = skill_data.cooldown_time
	self.damage = skill_data.base_damage
	self.skill_range = skill_data.base_range
	
	# Aplica upgrades que o jogador já possa ter desbloqueado
	if is_instance_valid(player):
		for upgrade_id in player.unlocked_upgrade_ids:
			_apply_upgrade(upgrade_id)
			
func _mark_enemy(enemy_node):
	marked_enemies.append(enemy_node)
	
	# Efeito visual de marca no inimigo (implementaremos depois)
	
	# Conecta-se ao sinal do hitbox do jogador, se ainda não estiver conectado
	var hitbox = player.get_node("Hitbox")
	if is_instance_valid(hitbox) and not hitbox.body_entered.is_connected(_on_player_hitbox_entered):
		hitbox.body_entered.connect(_on_player_hitbox_entered)
		
	# Cria um timer para remover a marca após 5 segundos
	var mark_timer = get_tree().create_timer(5.0)
	mark_timer.timeout.connect(func():
		if is_instance_valid(enemy_node) and enemy_node in marked_enemies:
			_unmark_enemy(enemy_node)
	)

# Crie esta nova função, que é chamada quando o hitbox do jogador acerta algo
func _on_player_hitbox_entered(body):
	# Se o corpo atingido for um dos nossos inimigos marcados...
	if body in marked_enemies:
		print("Marca de Ressonância detonada em: ", body.name)
		_detonate_mark(body)
		
		# Remove a marca para não detonar de novo
		_unmark_enemy(body)

# Crie a lógica de detonação
func _detonate_mark(marked_enemy):
	# Efeito visual da explosão
	
	# Encontra outros inimigos à volta do alvo
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy.global_position.distance_to(marked_enemy.global_position) <= explosion_radius:
			# Evita causar dano duplo ao inimigo que já foi atingido pelo ataque básico
			if enemy != marked_enemy: 
				var knockback_dir = (enemy.global_position - marked_enemy.global_position).normalized()
				enemy.take_damage(explosion_damage, knockback_dir)

# Crie uma função para limpar as marcas
func _unmark_enemy(enemy_node):
	if enemy_node in marked_enemies:
		marked_enemies.erase(enemy_node)
		# Remover o efeito visual da marca
	
	# Se não houver mais inimigos marcados, desliga a "escuta" do sinal
	if marked_enemies.is_empty():
		var hitbox = player.get_node("Hitbox")
		if is_instance_valid(hitbox) and hitbox.body_entered.is_connected(_on_player_hitbox_entered):
			hitbox.body_entered.disconnect(_on_player_hitbox_entered)

# Altere a sua função de upgrade
func _apply_upgrade(upgrade_id: String):
	match upgrade_id:
		"pulse_damage_1":
			damage += 1
		# --- ADIÇÃO AQUI ---
		"pulse_resonance_2": # Use o ID que definirmos para o upgrade
			resonance_pulse_unlocked = true
			print("Upgrade 'Ressonância de Pulso' ativado!")
