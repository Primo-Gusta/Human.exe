extends StaticBody2D
class_name Chest

@export var loot_data: LootTableData

const ITEM_SCENE = preload("res://Scenes/Items/Item.tscn")
const CODE_FRAGMENT_SCENE = preload("res://Scenes/Upgrades/CodeFragment.tscn")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $Area2D
@onready var interaction_collision_shape: CollisionShape2D = $Area2D/InteractionShape

var player_in_area: Node2D = null
var is_opened: bool = false

func _ready():
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event):
	if player_in_area and not is_opened and event.is_action_pressed("interact"):
		open_chest()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = body

func _on_body_exited(body):
	if body == player_in_area:
		player_in_area = null

func open_chest() -> void:
	if is_opened: return # Impede que o baú seja aberto várias vezes
	if not loot_data:
		print("AVISO: Baú '", self.name, "' não tem uma LootTableData definida.")
		return
	
	is_opened = true
	print("Baú aberto!")
	
	# Desativa a interacção imediatamente
	interaction_collision_shape.set_deferred("disabled", true)
	
	# 1. Toca a animação de abrir
	animated_sprite.play("open")
	
	# 2. Espera a animação de abrir terminar
	await animated_sprite.animation_finished
	
	# 3. Só depois da animação terminar é que o loot aparece
	spawn_loot()
	
	# 4. Espera um pouco para o jogador ver o baú aberto
	await get_tree().create_timer(0.5).timeout
	
	# 5. Inicia a animação de fade-out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4) # Anima a opacidade de todo o nó do baú
	
	# 6. Quando o fade-out terminar, destrói o baú
	await tween.finished
	queue_free()

# Em Chest.gd

func spawn_loot():
	var item_to_spawn = null # Variável para guardar o item que decidimos dropar

	# --- LÓGICA DE DECISÃO ---
	# 1. Verifica se deve gerar um fragmento único
	if loot_data.contains_unique_code_fragment:
		var unique_fragment: CodeFragmentData = LootManager.get_unique_code_fragment()
		if unique_fragment:
			item_to_spawn = CODE_FRAGMENT_SCENE.instantiate()
			item_to_spawn.fragment_data = unique_fragment
		else:
			print("AVISO: O baú tentou gerar um fragmento único, mas o LootManager não tem mais nenhum disponível.")
	
	# --- LÓGICA DE DROP GARANTIDO PARA ITENS NORMAIS ---
	var has_dropped_an_item = false
	
	# Continua a tentar até que um item seja dropado
	while not has_dropped_an_item:
		# Percorre cada "slot" de loot definido no nosso recurso
		for drop in loot_data.loot_drops:
			var random_chance = randf_range(0, 100)
			
			if random_chance < drop.chance_percent:
				var item_to_dropar: ItemData = drop.item_data

				if item_to_dropar.item_name == "Backup":
					if is_instance_valid(player_in_area) and player_in_area.inventory.has("Backup de Integridade"):
						print("Baú tentou dropar 'Backup de Integridade', mas o jogador já o possui. A pular o drop.")
						continue 
				var item_instance
				if drop.item_data is ItemData:
					item_instance = ITEM_SCENE.instantiate()
					item_instance.item_data = drop.item_data
				else:
					continue

				# Se um item for gerado, chama a função de animação
				if is_instance_valid(item_instance):
					_spawn_item_with_animation(item_instance)
					has_dropped_an_item = true # Define a flag para sair do loop
					break # Sai do loop 'for' para não dropar múltiplos itens
		
		# Se o loop 'for' terminar e nada tiver sido dropado,
		# o 'while' continuará e tentará tudo de novo.
		if not has_dropped_an_item:
			print("Baú não dropou nada na primeira tentativa. A tentar novamente...")

	# --- LÓGICA DE SPAWN (AGORA SEPARADA) ---
	# Se um item foi escolhido para ser dropado, chama a função de animação
	if is_instance_valid(item_to_spawn):
		_spawn_item_with_animation(item_to_spawn)

# --- NOVA FUNÇÃO AUXILIAR ---
# Esta função recebe uma instância de item e apenas se preocupa em animá-la
func _spawn_item_with_animation(item_instance):
	get_parent().add_child(item_instance)
	
	var spawn_pos = global_position
	item_instance.global_position = spawn_pos
	item_instance.scale = Vector2.ZERO # Começa invisível

	var jump_target = spawn_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(item_instance, "global_position", jump_target, 0.4)
	tween.tween_property(item_instance, "scale", Vector2(1.0, 1.0), 0.4)
	
	# Activa o delay para colecta
	if item_instance.has_method("activate_collect_delay"):
		tween.chain().tween_callback(item_instance.activate_collect_delay.bind(1.0)) # Activa após a animação
