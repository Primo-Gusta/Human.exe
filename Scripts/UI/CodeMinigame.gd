extends CanvasLayer

signal puzzle_solved

@onready var code_lines_container = $PanelContainer/VBoxContainer/CodeLinesContainer
@onready var compile_button = $PanelContainer/VBoxContainer/CompileButton

var puzzle_lines: Array[String] = []
var correct_solution: Array[String] = []

func _ready():
	# Garante que este CanvasLayer e filhos processem input mesmo com o jogo pausado
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	code_lines_container.process_mode = Node.PROCESS_MODE_ALWAYS
	compile_button.process_mode = Node.PROCESS_MODE_ALWAYS

	# Conecta o botão se ainda não estiver conectado
	if not compile_button.is_connected("pressed", Callable(self, "_on_compile_button_pressed")):
		compile_button.pressed.connect(_on_compile_button_pressed)

	# Debug
	print("[CodeMinigame] _ready() -> compile_button:", compile_button, " disabled:", compile_button.disabled)

	# Pausa o jogo e libera o mouse
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func start_puzzle(puzzle_data: Dictionary):
	puzzle_lines.clear()
	for line in puzzle_data["lines"]:
		puzzle_lines.append(line as String)

	correct_solution.clear()
	for line in puzzle_data["solution"]:
		correct_solution.append(line as String)

	puzzle_lines.shuffle()

	for child in code_lines_container.get_children():
		child.queue_free()

	var code_line_scene = preload("res://Scenes/UI/CodeLine.tscn")
	for line_text in puzzle_lines:
		var line_button = code_line_scene.instantiate()
		line_button.text = line_text
		line_button.container = code_lines_container
		code_lines_container.add_child(line_button)


func _flash_wrong_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color.RED)
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(btn):
			btn.remove_theme_color_override("font_color")
	)


func _on_compile_button_pressed() -> void:
	print("[CodeMinigame] Compile button pressed!")
	compile_button.disabled = true

	var current_order: Array[String] = []
	for child in code_lines_container.get_children():
		if child is Button:
			current_order.append(child.text as String)

	if current_order == correct_solution:
		print("Puzzle resolvido! ✅")
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		puzzle_solved.emit()
		queue_free()
		return

	print("Solução incorreta — destacando linhas erradas.")
	for i in range(code_lines_container.get_child_count()):
		var node = code_lines_container.get_child(i)
		if node is Button:
			var btn = node as Button
			var is_wrong = false
			if i >= correct_solution.size() or btn.text != correct_solution[i]:
				is_wrong = true
			if is_wrong:
				_flash_wrong_button(btn)

	await get_tree().create_timer(0.45).timeout
	compile_button.disabled = false
