extends StaticBody2D
class_name Chest

@export var loot_data: LootTableData

const ITEM_SCENE = preload("res://Scenes/Items/Item.tscn")
const CODE_FRAGMENT_SCENE = preload("res://Scenes/Upgrades/CodeFragment.tscn")

@onready var sprite_2d: Sprite2D = $Sprite2D
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

func open_chest():
	if not loot_data:
		print("AVISO: Baú '", self.name, "' não tem uma LootTableData definida.")
		return
	
	is_opened = true
	print("Baú aberto!")
	sprite_2d.modulate.a = 0.3
	
	# Desativa APENAS a área de interação. O corpo físico continua ativo.
	interaction_collision_shape.set_deferred("disabled", true)
	
	spawn_loot()

func spawn_loot():
	# Percorre cada "slot" de loot definido no nosso recurso
	for drop in loot_data.loot_drops:
		# Rola um "dado" de 0 a 100
		var random_chance = randf_range(0, 100)
		
		# Se o resultado for menor que a chance definida, o item é gerado
		if random_chance < drop.chance_percent:
			var item_instance
			# Verifica qual o tipo de item para instanciar a cena correta
			if drop.item_data is CodeFragmentData:
				item_instance = CODE_FRAGMENT_SCENE.instantiate()
				item_instance.fragment_data = drop.item_data
			elif drop.item_data is ItemData:
				item_instance = ITEM_SCENE.instantiate()
				item_instance.item_data = drop.item_data
			else:
				continue # Pula se o tipo de item for desconhecido
			
			get_parent().add_child(item_instance)
			
			# Define a posição e a escala INICIAL do item
			var spawn_pos = global_position
			item_instance.global_position = spawn_pos
			item_instance.scale = Vector2(0.1, 0.1) # <<-- NOVA LINHA AQUI

			# Define o alvo do "pulo"
			var jump_target = spawn_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			
			# Cria a animação Tween
			var tween = create_tween()
			tween.set_parallel(true) # <<-- IMPORTANTE: Faz as animações rodarem ao mesmo tempo
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			
			# Anima a POSIÇÃO para o alvo do pulo
			tween.tween_property(item_instance, "global_position", jump_target, 0.4)
			# Anima a ESCALA de 0.1 para o tamanho normal (1.0)
			tween.tween_property(item_instance, "scale", Vector2(0.1, 0.1), 0.4) # <<-- NOVA LINHA AQUI
			
			# Inicia o atraso de coleta após o pulo
			if item_instance.has_method("activate_collect_delay"):
				item_instance.activate_collect_delay(2.0)
