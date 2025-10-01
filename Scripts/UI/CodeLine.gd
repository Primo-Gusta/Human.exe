extends Button
class_name CodeLine
# Referência ao container pai (para reordenação)
var container: VBoxContainer

func _ready():
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

# --- Drag & Drop API ---
func _get_drag_data(at_position: Vector2) -> Variant:
	var preview = Label.new()
	preview.text = text
	preview.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	set_drag_preview(preview)
	return self  # Retorna a referência do próprio botão

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Só aceita se for outro CodeLine
	return data is CodeLine

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data == self:
		return
	# Remove o item arrastado do container e insere de volta na posição correta
	var index = container.get_children().find(self)
	container.remove_child(data)
	container.add_child(data)
	container.move_child(data, index)
