extends Panel

# Sinal emitido quando um fragmento é colocado ou removido.
signal fragment_changed(fragment_data: CodeFragmentData, slot_instance: Panel)

# REMOVIDO: Não precisamos mais saber qual fragmento é esperado.
# var expected_fragment: CodeFragmentData

# NOVO: Armazena a referência do fragmento que está atualmente neste slot.
var current_fragment: CodeFragmentData = null
var is_filled = false

@onready var label: Label = $Label

func _ready():
	label.text = "[ ... ]"
	# Garante que o Label se expande para preencher o nó pai
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Centraliza o texto dentro da área do Label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# Chamado pelo Godot quando algo está sendo arrastado sobre este controle.
func _can_drop_data(at_position, data):
	# A verificação agora é muito mais simples:
	# Apenas aceita se o slot estiver VAZIO e os dados forem um CodeFragmentData.
	return not is_filled and data is CodeFragmentData

# Chamado pelo Godot se _can_drop_data retornar true e o jogador soltar o mouse.
func _drop_data(at_position, data):
	is_filled = true
	current_fragment = data # Armazena o fragmento atual
	label.text = data.fragment_text
	label.reset_size()
	custom_minimum_size.x = label.get_minimum_size().x + 10	
	# Avisa ao Popup qual fragmento foi colocado.
	emit_signal("fragment_changed", current_fragment, self)

# NOVO: Permite que o jogador "pegue de volta" um fragmento do slot.
func _get_drag_data(at_position):
	# Se o slot não estiver preenchido, não há nada para arrastar.
	if not is_filled:
		return null
	
	# Permite arrastar o fragmento para fora do slot.
	var drag_data = current_fragment
	
	# Cria a pré-visualização (o label arrastável)
	var drag_preview = Label.new()
	drag_preview.text = label.text
	drag_preview.add_theme_stylebox_override("normal", label.get_theme_stylebox("normal"))
	drag_preview.modulate = Color(1, 1, 1, 0.7)
	set_drag_preview(drag_preview)
	
	# Limpa o slot, pois estamos "removendo" o fragmento dele.
	clear_slot()
	
	return drag_data

# NOVO: Função para limpar e resetar o slot.
func clear_slot():
	is_filled = false
	current_fragment = null
	label.text = "[ ... ]"
	# --- ADICIONE ESTAS 2 LINHAS ---
	label.reset_size()
	custom_minimum_size.x = label.get_minimum_size().x + 10 # Retorna ao tamanho do placeholder
	emit_signal("fragment_changed", null, self)
