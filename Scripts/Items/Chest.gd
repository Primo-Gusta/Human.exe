extends Area2D
class_name Chest

## Arraste o seu recurso LootTableData.tres para este campo no Inspetor.
@export var loot_data: LootTableData

# Preloads das cenas de itens que podem ser geradas
const ITEM_SCENE = preload("res://Scenes/Items/Item.tscn")
const CODE_FRAGMENT_SCENE = preload("res://Scenes/Upgrades/CodeFragment.tscn")

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player_in_area: Node2D = null
var is_opened: bool = false

func _ready():
	# Conecta os sinais da própria Area2D para saber quando o jogador está perto.
	self.body_entered.connect(_on_body_entered)
	self.body_exited.connect(_on_body_exited)

func _unhandled_input(event):
	# Se o jogador está na área, o baú não foi aberto e a tecla de interação foi pressionada...
	if player_in_area and not is_opened and event.is_action_pressed("interact"):
		open_chest()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = body
		# Opcional: mostrar um feedback visual de que o baú é interativo (ex: um balão com "F")

func _on_body_exited(body):
	if body == player_in_area:
		player_in_area = null
		# Opcional: esconder o feedback visual

func open_chest():
	if not loot_data:
		print("AVISO: Baú '", self.name, "' não tem uma LootTableData definida.")
		return
	
	is_opened = true
	print("Baú aberto!")
	
	# Feedback visual de que o baú foi aberto (fica semi-transparente)
	sprite_2d.modulate.a = 0.3
	
	# Desativa a colisão para não poder interagir novamente
	collision_shape.set_deferred("disabled", true)
	
	# Gera os itens da tabela de loot
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
			
			# Adiciona o item à cena do mundo (como irmão do baú)
			get_parent().add_child(item_instance)
			
			# Lógica para fazer o item "pular" para fora do baú
			var spawn_pos = global_position
			var jump_target = spawn_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			
			item_instance.global_position = spawn_pos
			
			var tween = create_tween()
			tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(item_instance, "global_position", jump_target, 0.4)
