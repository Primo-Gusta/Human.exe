extends Area2D
class_name CodePatch

signal item_collected(item_data: ItemData)

@export var data: ItemData

func _ready():
	body_entered.connect(_on_body_entered)
	if not data:
		push_warning("CodePatch em cena não tem um arquivo de 'ItemData' associado.")
		return
	if data.item_icon and $Sprite2D:
		$Sprite2D.texture = data.item_icon

func _on_body_entered(body):
	if body.is_in_group("player"):
		emit_signal("item_collected", data)
		queue_free()
