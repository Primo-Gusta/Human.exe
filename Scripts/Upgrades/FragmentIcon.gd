extends Control

# Esta variável será preenchida pelo script do Popup com os dados do fragmento
var fragment_data: CodeFragmentData

@onready var label: Label = $Label # ATUALIZADO: Agora é uma referência ao Label

func _ready():
	# Configura o texto do label
	if fragment_data:
		label.text = fragment_data.fragment_text
		# --- ADICIONE ESTAS 2 LINHAS ---
		# Força o label a recalcular seu tamanho mínimo com o novo texto
		label.reset_size() 
		# Ajusta o tamanho mínimo do nosso controle pai para ser igual ao do label + um pouco de preenchimento
		custom_minimum_size.x = label.get_minimum_size().x + 10 

# Esta é a função mágica do drag-and-drop.
# É chamada pelo Godot quando um arrastar começa neste controle.
func _get_drag_data(at_position):
	# ATUALIZADO: A pré-visualização do arrastar agora é uma cópia do nosso próprio Label
	var drag_preview = Label.new()
	drag_preview.text = label.text
	# Para a pré-visualização ter a mesma aparência, precisamos copiar o estilo
	drag_preview.add_theme_stylebox_override("normal", label.get_theme_stylebox("normal"))
	drag_preview.modulate = Color(1, 1, 1, 0.7) # Deixa um pouco transparente
	set_drag_preview(drag_preview)
	
	# Retorna os dados que estamos "carregando" com o mouse (isso não muda)
	return fragment_data
