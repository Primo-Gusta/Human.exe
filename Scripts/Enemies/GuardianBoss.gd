extends CharacterBody2D
class_name GuardianBoss

# --- SINAIS ---
signal boss_defeated

# --- CONFIGURAÇÃO ---
@export_group("Phase 1 Stats")
@export var phase_1_max_health: int = 3 # Vida que precisa ser zerada para iniciar a Fase 2
@export_group("Corruption Stats")
@export var max_corruption_health: int = 3 # Os 3 pontos de corrupção
@export_group("Stats")
@export var move_speed: float = 90.0
@export var dash_speed: float = 400.0
@export_group("AI Behaviour")
@export var attack_range: float = 50.0 # Distância para iniciar um ataque corpo a corpo
@export var dash_range: float = 200.0 # Distância para considerar usar o dash
@export var dash_cooldown: float = 3.0 # Segundos entre cada dash

# --- ESTADOS DA IA ---
enum State {
	IDLE,      # Ocioso, decidindo o que fazer
	CHASING,   # Perseguindo o jogador
	ATTACKING, # Executando um ataque
	STUNNED,   # Atordoado e vulnerável
	TRANSITION, # Mudando de fase
	TIRED # Cansadao, exposto
}
var current_state = State.IDLE
var current_phase = 1

# --- VARIÁVEIS DE ESTADO ---
var health: int # Usada apenas para a Fase 1
var corruption_health: int # Usada para as Fases 2 e 3
var player: CharacterBody2D = null
var can_dash: bool = true
var can_attack: bool = true # NOVA variável para controlar o cooldown
var minions_to_defeat: int = 0 # NOVO: Contador para os inimigos da Fase 2
var last_minion_position: Vector2 = Vector2.ZERO # NOVO: Para guardar a posição
var player_is_in_interaction_area: bool = false # NOVA variável
var phase_3_attack_sequence_count: int = 0
const PHASE_3_ATTACKS_PER_CYCLE = 3 # Fará 3 ataques antes de ficar cansado
var phase_3_hits_to_stun: int = 0 # NOVO: Contador de acertos para quebrar a postura
const PHASE_3_REQUIRED_HITS = 3 # NOVO: Quantos acertos são necessários
var disabled_attacks: Array[String] = [] # NOVO: Guarda os nomes dos ataques/posições desativados
@export_group("Phase 3 Movement")
@export var phase_3_dash_duration: float = 0.4 # Duração do dash em segundos


# NOVO: Dicionário para guardar os dados dos nossos puzzles
var puzzles = {
	"security_routine_1": {
		"lines": [
			"FUNCTION grant_access(user_request):",
			"\tIF validate_request(user_request) == TRUE:",
			"\t\tRETURN core.access_granted",
			"\tELSE:",
			"\t\tDENY access AND PURGE(request)",
			"\tENDIF",
			"ENDFUNC"
		],
		"solution": [
			"FUNCTION grant_access(user_request):",
			"\tIF validate_request(user_request) == TRUE:",
			"\t\tRETURN core.access_granted",
			"\tELSE:",
			"\t\tDENY access AND PURGE(request)",
			"\tENDIF",
			"ENDFUNC"
		]
	}
}

# --- REFERÊNCIAS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_points: Node2D = $AttackPoints
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer # Adicionaremos este timer na cena
@onready var melee_hurtbox_shape: CollisionShape2D = $MeleeHurtbox/CollisionShape2D
@onready var projectile_spawn_point: Marker2D = $AttackPoints/ProjectileSpawnPoint
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer # NOVA referência
@onready var interaction_area_shape: CollisionShape2D = $InteractionArea/CollisionShape2D # NOVA referência
@export_group("Phase 3 Positions")
@export var phase_3_positions: Array[Marker2D]

# --- PRELOADS ---
const AreaAttackWaveScene = preload("res://Scenes/Enemies/AreaAttackWave.tscn")
const BossProjectileScene = preload("res://Scenes/Enemies/BossProjectile.tscn")
const CodePatchScene = preload("res://Scenes/Items/CodePatch.tscn") # Adicione o caminho correto para sua cena
const EnemyScene = preload("res://Scenes/Enemies/Enemy.tscn") # Usaremos o inimigo esqueleto como lacaio
const BinaryWaveScene = preload("res://Scenes/Enemies/BinaryWave.tscn")
const CodeMinigameScene = preload("res://Scenes/UI/CodeMinigame.tscn") # Ajuste o caminho se necessário

func _ready():
	health = phase_1_max_health
	corruption_health = max_corruption_health
	# Adiciona o boss ao grupo "enemies" para que as habilidades do jogador o atinjam
	add_to_group("enemies")
	# NOVO: Conecta o sinal da hurtbox para detectar quando ela atinge o jogador
	$MeleeHurtbox.body_entered.connect(_on_melee_hurtbox_body_entered)
	# NOVO: Conecta o sinal de fim de animação para saber quando o ataque terminou
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	# NOVO: Conecta os sinais da nova área de interação
	$InteractionArea.body_entered.connect(_on_interaction_area_body_entered)
	$InteractionArea.body_exited.connect(_on_interaction_area_body_exited)
	
func _physics_process(delta):
	# Se o boss ainda não encontrou o jogador, ele continua procurando.
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		# Se não encontrar, espera o próximo frame.
		if not is_instance_valid(player):
			return

	# Máquina de Estados (State Machine)
	match current_state:
		State.IDLE:
			_state_idle()
		State.CHASING:
			_state_chasing(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.STUNNED:
			_state_stunned(delta)
		State.TRANSITION:
			_state_transition(delta)
		State.TIRED:
			_state_tired(delta)

	if current_state == State.STUNNED and player_is_in_interaction_area:
		if Input.is_action_just_pressed("interact"):
			if is_instance_valid(player) and player.has_code_patch:
				_apply_core_damage()
			else:
				print("Boss: O jogador tentou interagir, mas não tem o Code Patch.")
				# Tocar um som de "falha"

func _state_idle():
	# Para o boss enquanto ele decide o que fazer.
	velocity = Vector2.ZERO
	move_and_slide()
	
	# Se o boss não puder atacar (está em cooldown), ele não faz nada
	# e continuará verificando a cada frame até poder.
	if not can_attack:
		return

	var distance_to_player = player.global_position.distance_to(global_position)
	
	# Se o jogador estiver muito longe, a única opção é perseguir.
	if distance_to_player > attack_range:
		current_state = State.CHASING
		return

	# Se o jogador estiver perto, escolhe aleatoriamente um dos 3 ataques.
	var attack_choice = randi_range(0, 2) # Sorteia um número: 0, 1 ou 2
	
	match attack_choice:
		0:
			print("Decisão da IA: Ataque corpo a corpo!")
			_execute_melee_attack()
		1:
			print("Decisão da IA: Ataque em área!")
			_execute_area_attack()
		2:
			print("Decisão da IA: Ataque à distância!")
			_execute_ranged_attack()
	# Inicia o cooldown com um tempo de espera aleatório
	can_attack = false
	var random_cooldown = randf_range(1.5, 3.0) # Sorteia um número entre 1.5 e 3.0
	attack_cooldown_timer.wait_time = random_cooldown
	attack_cooldown_timer.start()
	print("Boss em cooldown por ", random_cooldown, " segundos.")

func _state_chasing(delta):
	# Se o jogador se aproximar o suficiente, para de perseguir e entra no estado IDLE para decidir o próximo ataque.
	if player.global_position.distance_to(global_position) <= attack_range:
		current_state = State.IDLE
		velocity = Vector2.ZERO # Para de se mover
		move_and_slide()
		return

	# Lógica do Dash
	var distance_to_player = player.global_position.distance_to(global_position)
	if distance_to_player > dash_range and can_dash:
		_execute_dash()
		return # Sai da função enquanto estiver no dash

	# Movimento Normal de Perseguição
	var direction = global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	
	# Vira o sprite para a direção do jogador enquanto persegue
	if velocity.x < 0:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false

	move_and_slide()

# --- NOVAS FUNÇÕES ---
func _execute_dash():
	print("Boss usou o Dash!")
	can_dash = false
	current_state = State.ATTACKING # Considera o dash um "ataque" para não ser interrompido
	dash_cooldown_timer.start()
	
	var direction = global_position.direction_to(player.global_position)
	
	# Usamos um tween para o movimento suave do dash
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	# Anima a posição do boss na direção do jogador
	tween.tween_property(self, "global_position", global_position + direction * dash_range, dash_speed / 1000.0)
	
	# Quando o tween terminar, volta ao estado de perseguição
	tween.finished.connect(func(): current_state = State.CHASING)

func _on_dash_cooldown_timer_timeout():
	can_dash = true

func _state_attacking(delta):
	# Enquanto estiver atacando, o boss não faz nada (a animação está no controle)
	velocity = Vector2.ZERO
	move_and_slide()

# MELEE
func _execute_melee_attack():
	current_state = State.ATTACKING
	# Vira o sprite para a direção do jogador
	if player.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
	
	# Toca a animação de ataque (use o nome da sua animação)
	animated_sprite.play("attack_melee") # IMPORTANTE: Use o nome real da sua animação de ataque
	
	# Ativa a hurtbox por um curto período.
	# Usamos um timer rápido para isso.
	melee_hurtbox_shape.disabled = false
	await get_tree().create_timer(0.5).timeout # A hurtbox ficará ativa por 0.5 segundos
	melee_hurtbox_shape.disabled = true

# ATAQUE EM ÁREA
# MODIFIQUE esta função para ser assíncrona
# MODIFIQUE esta função para controlar o estado do início ao fim
func _execute_area_attack() -> void:
	print("Boss usou o Ataque em Área Sequencial!")
	current_state = State.ATTACKING
	animated_sprite.play("attack_area")
	
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self): return
	
	# --- A SEQUÊNCIA ---
	spawn_attack_wave(100.0, Color.BLACK)
	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(self): return

	spawn_attack_wave(200.0, Color.YELLOW)
	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(self): return

	spawn_attack_wave(300.0, Color.RED)
	# Espera a última onda terminar também
	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(self): return
	
	# --- SUA LÓGICA DE 'IF' AQUI ---
	# Verifica em qual fase o boss está para decidir o que fazer a seguir
	if current_phase == 3:
		# Se estiver na Fase 3, continua o ciclo de ataques frenéticos
		_decide_phase_3_action()
	else:
		# Se estiver na Fase 1, volta para o estado IDLE para uma nova decisão
		current_state = State.IDLE
		print("Sequência de ataque em área (Fase 1) CONCLUÍDA. Voltando para IDLE.")

# MODIFIQUE esta função auxiliar
func spawn_attack_wave(radius: float, color: Color):
	var wave = AreaAttackWaveScene.instantiate()
	var spawn_position = global_position # O ataque agora se origina do centro do boss
	
	get_parent().add_child(wave)
	wave.global_position = spawn_position
	
	# Chama a nova função 'activate' com os parâmetros do seu plano
	wave.activate(radius, color, 1.0, 0.3)

# RANGED ATTACK
# Adicione a nova função para o ataque à distância
func _execute_ranged_attack():
	print("Boss usou o Ataque à Distância!")
	current_state = State.ATTACKING
	animated_sprite.play("attack_ranged") # Nome de animação sugerido
	
	# Vira na direção do jogador antes de atirar
	if player.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
		
	# Espera um pouco para o jogador reagir à animação
	await get_tree().create_timer(0.4).timeout
	
	if not is_instance_valid(self): return # Checa se o boss não morreu enquanto esperava
	
	# Cria a instância do projétil
	var projectile = BossProjectileScene.instantiate()
	# Define a direção do projétil
	projectile.direction = global_position.direction_to(player.global_position)
	# Adiciona o projétil à cena principal
	# AGORA: Adiciona o projétil como um filho do PAI do boss (a cena da arena)
	get_parent().add_child(projectile)
	
	projectile.global_position = projectile_spawn_point.global_position

func _on_animation_finished():
	if animated_sprite.animation == "attack_area":
		return

	# Se a animação foi de qualquer outro ataque, volta ao estado IDLE.
	if current_state == State.ATTACKING:
		current_state = State.IDLE
		
func _on_attack_cooldown_timer_timeout():
	can_attack = true
	print("Boss Cooldown terminou. Pronto para atacar.")
# Chamado quando a MeleeHurtbox colide com algo
func _on_melee_hurtbox_body_entered(body):
	# Verifica se o corpo é o jogador
	if body.is_in_group("player"):
		print("Boss atingiu o jogador com um ataque corpo a corpo!")
		# Causa dano ao jogador (vamos assumir 10 de dano por enquanto)
		var knockback_direction = global_position.direction_to(body.global_position)
		body.take_damage(3, knockback_direction)
		# Desativa a hurtbox imediatamente para não causar dano múltiplo
		melee_hurtbox_shape.set_deferred("disabled", true)

func _state_stunned(delta):
	# Enquanto estiver atordoado, o boss fica completamente parado, esperando a interação do jogador.
	velocity = Vector2.ZERO
	move_and_slide()
	# A lógica de interação será adicionada no Passo 3.

func _state_transition(delta):
	# O boss fica parado e invulnerável durante a transição.
	velocity = Vector2.ZERO
	move_and_slide()
	# Nenhuma lógica adicional é necessária aqui, pois a função que INICIA a transição fará todo o trabalho.
	
func take_damage(amount, knockback_direction = Vector2.ZERO):
	# Se o boss já foi derrotado, não faz nada.
	if corruption_health <= 0: return

	# A única situação em que o boss pode ser ferido na Fase 3 é no estado TIRED.
	if current_phase == 3:
		if current_state == State.TIRED:
			phase_3_hits_to_stun += 1
			print("Boss atingido enquanto cansado! Acertos: %d / %d" % [phase_3_hits_to_stun, PHASE_3_REQUIRED_HITS])
			
			if phase_3_hits_to_stun >= PHASE_3_REQUIRED_HITS:
				_expose_core()
		# Se não estiver TIRED, ele é invulnerável na Fase 3.
		return

	# Lógica de Dano para a FASE 1
	if current_phase == 1:
		health -= amount
		print("Vida do Guardião (Fase 1): ", health)
		
		if health <= 0:
			current_phase = 2
			_cancel_all_actions()
			call_deferred("_start_phase_2_transition")
		return
	# Em qualquer outro estado (transição, stun, etc.), o boss é invulnerável
	print("Boss está invulnerável neste momento.")

func _die():
	print("Guardião Derrotado!")
	emit_signal("boss_defeated")
	queue_free()
	
func _cancel_all_actions():
	print("Cancelando todas as ações do boss...")
	
	# 1. Mata todos os Tweens ativos no boss
	# O Godot 4 gerencia Tweens de forma mais inteligente. O ideal é parar e matar.
	# Se tivermos um tween de dash, por exemplo:
	# if dash_tween and dash_tween.is_running():
	#     dash_tween.kill()

	# 2. Para todos os Timers filhos
	for child in get_children():
		if child is Timer:
			child.stop()
	
	# 3. Remove todas as ondas de ataque da tela
	# Adicionamos as ondas ao grupo "attack_waves" para facilitar a busca
	get_tree().call_group("attack_waves", "queue_free")

# --- FASE 2 ---

func _start_phase_2_transition():
	print("Guardião iniciando transição para a Fase 2!")
	current_state = State.TRANSITION
	
	# Opcional: mover o boss para o centro da arena
	# var tween = create_tween()
	# tween.tween_property(self, "global_position", get_viewport_rect().size / 2, 1.0)
	# await tween.finished
	
	# Invoca a horda de inimigos
	var num_minions = 3 # Quantos inimigos invocar
	minions_to_defeat = num_minions
	
	for i in range(num_minions):
		var minion = EnemyScene.instantiate()
		
		# Calcula uma posição de spawn em círculo ao redor do boss
		var spawn_angle = (2 * PI / num_minions) * i
		var spawn_offset = Vector2(cos(spawn_angle), sin(spawn_angle)) * 150 # 150 pixels de distância
		var spawn_position = global_position + spawn_offset
		
		get_parent().add_child(minion)
		minion.global_position = spawn_position
		
		# --- ALTERAÇÃO AQUI ---
		# Usamos .bind() para passar a referência do 'minion' como um argumento extra
		# quando o sinal 'enemy_died' for emitido.
		minion.enemy_died.connect(_on_minion_died.bind(minion))
		
		print("Lacaio invocado em: ", spawn_position)

func _on_minion_died(minion_node):
	# Se o nó do lacaai que morreu ainda for válido, guardamos sua posição.
	if is_instance_valid(minion_node):
		last_minion_position = minion_node.global_position
	
	minions_to_defeat -= 1
	print("Lacaio derrotado! Restam: ", minions_to_defeat)
	
	if minions_to_defeat <= 0:
		print("Todos os lacaios derrotados! Dropando o Code Patch.")
		_spawn_code_patch()
		
		# Boss fica atordoado e ATIVA a área de interação
		current_state = State.STUNNED
		interaction_area_shape.disabled = false 
		print("Boss está ATORDOADO. Área de interação ATIVA.")

func _spawn_code_patch():
	var patch = CodePatchScene.instantiate()
	get_parent().add_child(patch)
	
	# --- ALTERAÇÃO AQUI ---
	# Usa a posição guardada em vez da posição do boss
	patch.global_position = last_minion_position 
	
	if is_instance_valid(player):
		patch.item_collected.connect(player._on_item_collected)
	else:
		push_warning("Boss tentou spawnar Code Patch mas não tinha referência do jogador!")
		
# --- FASE 3 ---

func _apply_core_damage():
	print("Code Patch inserido! Dano de Corrupção aplicado!")
	
	if is_instance_valid(player):
		player.consume_code_patch()
	
	interaction_area_shape.set_deferred("disabled", true)
	player_is_in_interaction_area = false
	
	corruption_health -= 1
	print("Vida de Corrupção restante: ", corruption_health)

	# --- LÓGICA DE DESATIVAÇÃO DE ATAQUES ---
	match corruption_health:
		2: # Se a vida de corrupção agora é 2 (primeiro acerto)
			disabled_attacks.append("TopPosition")
			print("SISTEMA: Ataque da posição superior DESATIVADO.")
		1: # Se a vida de corrupção agora é 1 (segundo acerto)
			disabled_attacks.append("BottomPosition")
			print("SISTEMA: Ataque da posição inferior DESATIVADO.")
			
	if corruption_health <= 0:
		_die()
	else:
		# Se ainda não foi derrotado, ele se recupera e reinicia o ciclo da Fase 3
		current_phase = 3 # Garante que continue na fase 3
		current_state = State.IDLE # Volta a um estado seguro
		
		# Reinicia o ciclo de ataques
		phase_3_attack_sequence_count = 0 
		can_attack = true
		attack_cooldown_timer.stop()
		
		# Opcional: Tocar uma animação de "se recuperando" antes de voltar a atacar
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self):
			_decide_phase_3_action()


	# Futuramente: Tocar uma animação de "power up", etc.

func _execute_positional_dash():
	# --- LÓGICA DE ESCOLHA APRIMORADA ---
	# 1. Filtra a lista de posições, mantendo apenas as que NÃO estão na lista de desativados.
	var available_positions = []
	for marker in phase_3_positions:
		if not marker.name in disabled_attacks:
			available_positions.append(marker)

	if available_positions.is_empty():
		push_warning("Nenhuma posição de ataque disponível, mas o boss não foi derrotado.")
		_start_tired_state() # Fallback seguro
		return

	# 2. Escolhe um alvo aleatório da lista de posições DISPONÍVEIS
	var target_marker = available_positions.pick_random()
	var target_position = target_marker.global_position
	
	# O Tween para o dash continua o mesmo...
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", target_position, phase_3_dash_duration)
	await tween.finished
	if not is_instance_valid(self): return

	print("Boss chegou ao destino do dash via Tween: ", target_marker.name)
	
	phase_3_attack_sequence_count += 1
	_execute_positional_attack()

func _decide_phase_3_action():
	if phase_3_attack_sequence_count >= PHASE_3_ATTACKS_PER_CYCLE:
		print("Fim do ciclo de ataques. Boss está CANSADO.")
		_start_tired_state() # Chama a nova função para iniciar o estado
	else:
		current_state = State.ATTACKING
		_execute_positional_dash()

# Preencha a função _execute_positional_attack
func _execute_positional_attack():
	# Descobre em qual marcador o boss está mais próximo
	var closest_marker_name = ""
	var min_distance = INF
	for marker in phase_3_positions:
		var distance = global_position.distance_to(marker.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_marker_name = marker.name

	print("Boss está atacando de: ", closest_marker_name)

	# Usa o nome do marcador para decidir o ataque
	var wave_instance = null # Para guardar a referência da onda

	match closest_marker_name:
		"TopPosition":
			wave_instance = spawn_binary_wave("top")
		"BottomPosition":
			wave_instance = spawn_binary_wave("bottom")
		"CenterPosition":
			_execute_area_attack()
			return
		_:
			_execute_area_attack()
			return


	# Se uma onda binária foi criada, ESPERA ela terminar
	if is_instance_valid(wave_instance):
		await wave_instance.wave_finished
	
	# Só então decide a próxima ação
	if is_instance_valid(self):
		_decide_phase_3_action()

# Crie esta nova função auxiliar para spawnar a onda
func spawn_binary_wave(spawn_location: String) -> Area2D:
	var viewport_rect = get_viewport_rect()
	var screen_width = viewport_rect.size.x
	var screen_height_third = viewport_rect.size.y / 3

	var wave = BinaryWaveScene.instantiate()
	get_parent().add_child(wave)
	
	var spawn_y = 0.0
	if spawn_location == "top":
		spawn_y = viewport_rect.position.y
	elif spawn_location == "bottom":
		spawn_y = viewport_rect.position.y + (screen_height_third * 2)
	
	# Posiciona o ponto de início da onda fora da tela, à esquerda
	wave.global_position = Vector2(viewport_rect.position.x - screen_width, spawn_y)
	
	wave.setup_wave(screen_width, screen_height_third, 2.0)

	return wave

# CRIE a nova função _start_tired_state
func _start_tired_state():
	current_state = State.TIRED
	phase_3_hits_to_stun = 0 # Reseta o contador de acertos
	
	# Toca uma animação de "cansado"
	# animated_sprite.play("tired")
	
	# Inicia um timer para a duração do estado cansado
	get_tree().create_timer(5.0).timeout.connect(func():
		# Se o tempo acabar e o boss não foi atordoado, ele reinicia o ciclo
		if current_state == State.TIRED:
			print("Tempo de cansaço esgotado. Reiniciando ciclo de ataques.")
			phase_3_attack_sequence_count = 0 # Reseta o ciclo de ataques
			_decide_phase_3_action()
	)

# CRIE a nova função de estado _state_tired
func _state_tired(delta):
	# Enquanto estiver cansado, o boss fica parado.
	velocity = Vector2.ZERO
	move_and_slide()
	
func _expose_core():
	current_state = State.STUNNED
	print("Núcleo exposto. Iniciando mini-game de depuração.")
	
	# NÃO ativamos mais a InteractionArea aqui, o mini-game substitui isso.
	# interaction_area_shape.disabled = false
	
	# Toca a animação de "núcleo exposto" ou "atordoado"
	# animated_sprite.play("core_exposed")
	
	# --- NOVA LÓGICA DE INTEGRAÇÃO ---
	# 1. Cria uma instância da cena do mini-game
	var minigame = CodeMinigameScene.instantiate()
	
	# 2. Adiciona à árvore de cena para que seja visível
	get_tree().root.add_child(minigame)
	
	# 3. Conecta o sinal de sucesso do mini-game à nossa função de dano de corrupção
	minigame.puzzle_solved.connect(_apply_core_damage)
	
	# 4. Inicia o puzzle, passando os dados do nosso primeiro puzzle
	minigame.start_puzzle(puzzles["security_routine_1"])

# Funções para os sinais da InteractionArea
func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player_is_in_interaction_area = true
		print("Jogador entrou na área de interação do Boss.")
		# hud.show_interaction_prompt(true) # Ex: mostrar "Pressione [F]"

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player_is_in_interaction_area = false
		print("Jogador saiu da área de interação do Boss.")
		# hud.show_interaction_prompt(false)
