extends StaticBody2D
class_name ChestItem

@export var loot_data: LootTableData

const ITEM_SCENE = preload("res://Scenes/Items/Item.tscn")

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
	if is_opened: return
	if not loot_data:
		print("AVISO: Baú '", self.name, "' sem LootTableData definida.")
		return
	
	is_opened = true
	interaction_collision_shape.set_deferred("disabled", true)
	animated_sprite.play("open")
	await animated_sprite.animation_finished
	
	spawn_loot()

	await get_tree().create_timer(0.5).timeout
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()

func spawn_loot():
	if not loot_data or loot_data.loot_drops.is_empty():
		print("Baú sem drops configurados.")
		return

	var has_dropped = false

	while not has_dropped:
		for drop in loot_data.loot_drops:
			var random_chance = randf_range(0, 100)
			if random_chance < drop.chance_percent:
				if drop.item_data is ItemData:
					var item_instance = ITEM_SCENE.instantiate()
					item_instance.item_data = drop.item_data
					_spawn_item_with_animation(item_instance)
					has_dropped = true
					break
		if not has_dropped:
			print("Tentando novamente gerar drop...")

func _spawn_item_with_animation(item_instance):
	get_parent().add_child(item_instance)
	item_instance.global_position = global_position
	item_instance.scale = Vector2.ZERO

	var jump_target = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	tween.tween_property(item_instance, "global_position", jump_target, 0.4)
	tween.tween_property(item_instance, "scale", Vector2.ONE, 0.4)

	if item_instance.has_method("activate_collect_delay"):
		tween.chain().tween_callback(item_instance.activate_collect_delay.bind(1.0))
