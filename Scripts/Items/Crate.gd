extends StaticBody2D
class_name Crate

# --- Variáveis de Configuração ---
@export var loot_data: LootTableData
@export var hits_to_break: int = 3 # Quantas vezes precisa de ser atingido

# --- Preloads das Cenas de Itens ---
const ITEM_SCENE = preload("res://Scenes/Items/Item.tscn")
const CODE_FRAGMENT_SCENE = preload("res://Scenes/Upgrades/CodeFragment.tscn")

# --- Referências ---
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

var is_broken: bool = false

func _ready():
	# Debug inicial
	print("Crate: inicializado com hits_to_break =", hits_to_break)

	# Garante que a hitbox está ativa
	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("disabled", false)
	
	# Se o Player ataca por grupos, garante que está no grupo correto
	add_to_group("enemy")

# Esta função será chamada pelo sistema de ataque do Player
func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO):
	if is_broken:
		print("Crate: já quebrado, dano ignorado.")
		return

	hits_to_break -= amount
	print("Crate: tomou dano =", amount, "| Hits restantes =", hits_to_break)

	# Animação de piscar a branco
	_flash_white()
	
	if hits_to_break <= 0:
		break_crate()

func break_crate() -> void:
	if is_broken:
		print("Crate: break_crate chamado, mas já está quebrado.")
		return
	is_broken = true
	
	print("Crate: CAIXOTE QUEBRADO!")

	# Desativa a hitbox para não poder ser atingido novamente
	hitbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# O loot aparece imediatamente
	_spawn_loot()
	
	# Inicia a animação de fade-out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	
	# Quando o fade-out terminar, destrói o caixote
	await tween.finished
	queue_free()

func _spawn_loot():
	if not loot_data:
		print("Crate: sem loot_data, nenhum item será gerado.")
		return

	var item_to_spawn = null
	
	if loot_data.contains_unique_code_fragment:
		var unique_fragment = LootManager.get_unique_code_fragment()
		if unique_fragment:
			item_to_spawn = CODE_FRAGMENT_SCENE.instantiate()
			item_to_spawn.fragment_data = unique_fragment
			print("Crate: gerou fragmento único:", unique_fragment.name)
		else:
			print("Crate: tentou gerar fragmento único, mas nenhum disponível.")
	else:
		for drop in loot_data.loot_drops:
			var random_chance = randf_range(0, 100)
			if random_chance < drop.chance_percent:
				if drop.item_data is ItemData:
					item_to_spawn = ITEM_SCENE.instantiate()
					item_to_spawn.item_data = drop.item_data
					print("Crate: gerou item:", drop.item_data.name)
				break

	if is_instance_valid(item_to_spawn):
		_spawn_item_with_animation(item_to_spawn)
	else:
		print("Crate: nenhum item foi spawnado.")

func _spawn_item_with_animation(item_instance):
	get_parent().add_child(item_instance)
	var spawn_pos = global_position
	item_instance.global_position = spawn_pos
	item_instance.scale = Vector2.ZERO
	var jump_target = spawn_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(item_instance, "global_position", jump_target, 0.4)
	tween.tween_property(item_instance, "scale", Vector2(1.0, 1.0), 0.4)
	if item_instance.has_method("activate_collect_delay"):
		tween.chain().tween_callback(item_instance.activate_collect_delay.bind(1.0))
		print("Crate: item ativado para coleta com delay.")

# Função para a animação de piscar
func _flash_white():
	var tween = create_tween()
	tween.tween_property(sprite_2d, "self_modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite_2d, "self_modulate", Color(1,1,1,0), 0.05) # Volta ao normal (transparente)
