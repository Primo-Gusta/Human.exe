extends StaticBody2D
class_name Crate

# --- Variáveis de Configuração ---
@export var loot_data: LootTableData
@export var hits_to_break: int = 3 # Quantas vezes precisa ser atingido

# --- Preloads das Cenas ---
const ITEM_SCENE = preload("res://Scenes/Items/Item.tscn")
const CODE_FRAGMENT_SCENE = preload("res://Scenes/Upgrades/CodeFragment.tscn")

# --- Referências ---
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var player_in_area: Node2D = null

# --- Estado ---
var is_broken: bool = false

func _ready():
	add_to_group("loots")  # Grupo de loot/caixas

	# Configura camada e máscara
	collision_layer = 1
	collision_mask = 1

	print("Crate iniciado | Camada:", collision_layer, "| Máscara:", collision_mask)
	print("Grupos:", get_groups())

# --- Lógica de Dano ---
func take_damage(amount: int, knockback_direction: Vector2 = Vector2.ZERO):
	if is_broken:
		return

	hits_to_break -= amount
	print("Crate recebeu dano: ", amount, " | Hits restantes: ", hits_to_break)

	_flash_white()

	if hits_to_break <= 0:
		call_deferred("break_crate")  # Evita o erro de flush de física

# --- Quebra da caixa ---
func break_crate() -> void:
	if is_broken:
		return
	is_broken = true

	print("Crate quebrado! Spawnando loot...")

	_spawn_loot()

	# Desativa colisão de forma segura
	collision_shape.set_deferred("disabled", true)

	# Efeito de fade
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

# --- Sistema de Loot ---
func _spawn_loot():
	if not loot_data:
		print("⚠️ AVISO: Crate não tem LootTableData definido!")
		return

	var item_to_spawn: Node = null

	if loot_data.contains_unique_code_fragment:
		var unique_fragment = LootManager.get_unique_code_fragment()
		if unique_fragment:
			item_to_spawn = CODE_FRAGMENT_SCENE.instantiate()
			item_to_spawn.fragment_data = unique_fragment
	else:
		for drop in loot_data.loot_drops:
			var random_chance = randf_range(0, 100)
			if random_chance < drop.chance_percent:
				var item_data = drop.item_data

				if item_data.item_name == "Backup":
					if is_instance_valid(player_in_area) and player_in_area.inventory.has("Backup de Integridade"):
						print("Baú tentou dropar 'Backup de Integridade', mas o jogador já o possui. Pulando...")
						continue 

				item_to_spawn = ITEM_SCENE.instantiate()
				item_to_spawn.item_data = item_data
				break

	if is_instance_valid(item_to_spawn):
		call_deferred("_spawn_item_with_animation", item_to_spawn)
		print("Loot spawnado:", item_to_spawn)

func _spawn_item_with_animation(item_instance: Node):
	get_parent().add_child(item_instance)
	item_instance.global_position = global_position
	item_instance.scale = Vector2.ZERO

	var jump_target = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(item_instance, "global_position", jump_target, 0.4)
	tween.tween_property(item_instance, "scale", Vector2(1.0, 1.0), 0.4)

	if item_instance.has_method("activate_collect_delay"):
		tween.chain().tween_callback(item_instance.activate_collect_delay.bind(1.0))

# --- Efeito visual de dano ---
func _flash_white():
	var tween = create_tween()
	tween.tween_property(sprite_2d, "self_modulate", Color.WHITE, 0.05)
	tween.tween_property(sprite_2d, "self_modulate", Color(1, 1, 1, 1), 0.05)
