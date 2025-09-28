extends CanvasLayer

signal puzzle_solved

# Referências para os nós da nossa UI
@onready var code_lines_container = $PanelContainer/VBoxContainer/CodeLinesContainer
@onready var compile_button = $PanelContainer/VBoxContainer/CompileButton

# Variáveis para guardar a lógica do puzzle
var puzzle_lines: Array[String] = []
var correct_solution: Array[String] = []

func _ready():
	compile_button.pressed.connect(_on_compile_pressed)
	# O jogo deve estar pausado quando este menu estiver ativo
	get_tree().paused = true
	# Libera o mouse para o jogador interagir com a UI
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Esta função será chamada pelo GuardianBoss para iniciar o puzzle
func start_puzzle(puzzle_data: Dictionary):
	# Guarda os dados do puzzle
	self.puzzle_lines = puzzle_data["lines"]
	self.correct_solution = puzzle_data["solution"]
	
	# Embaralha as linhas para o jogador
	puzzle_lines.shuffle()
	
	# Limpa qualquer linha de um puzzle anterior
	for child in code_lines_container.get_children():
		child.queue_free()
	
	# Cria os botões para cada linha de código
	for line_text in puzzle_lines:
		var line_button = Button.new()
		line_button.text = line_text
		line_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_lines_container.add_child(line_button)

func _on_compile_pressed():
	# Por enquanto, apenas fecha o puzzle e emite o sinal de sucesso
	print("Botão [COMPILAR] pressionado!")
	
	# Futuramente, aqui virá a lógica de verificação da ordem
	
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	puzzle_solved.emit()
	queue_free()
