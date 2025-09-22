extends Control

# NOVO: Sinal emitido quando um item é clicado na grade.
signal item_selected(item_data: ItemData)

@onready var item_grid = $MainContainer/ContentVBox/HBoxContainer/ItemGrid
@onready var item_description_label = $MainContainer/ContentVBox/ItemDescriptionLabel

# NOVO: Referências para o display do item selecionado
@onready var selected_item_container = $MainContainer/ContentVBox/HBoxContainer/SelectedItemContainer
@onready var selected_item_icon = $MainContainer/ContentVBox/HBoxContainer/SelectedItemContainer/SelectedItemIcon
@onready var selected_item_name = $MainContainer/ContentVBox/HBoxContainer/SelectedItemContainer/SelectedItemName

func _ready():
	item_description_label.text = "Passe o mouse sobre um item para ver sua descrição."
	# Esconde o display de item selecionado no início
	selected_item_container.visible = false

func update_inventory_display(inventory_data: Dictionary, current_active_item: ItemData):
	for child in item_grid.get_children():
		child.queue_free()

	for item_data in inventory_data:
		var item_info = inventory_data[item_data]
		
		# IMPORTANTE: Usaremos um Botão em vez de um Painel para capturar cliques facilmente.
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(96, 96)
		slot_button.flat = true # Deixa o botão transparente como um painel
		
		# Conecta os sinais de mouse e clique
		slot_button.mouse_entered.connect(_on_item_slot_mouse_entered.bind(item_data))
		slot_button.mouse_exited.connect(_on_item_slot_mouse_exited)
		slot_button.pressed.connect(_on_item_slot_pressed.bind(item_data)) # NOVO: Para o clique
		
		# ... (criação do TextureRect e Label da quantidade continua igual)
		var texture_rect = TextureRect.new()
		texture_rect.texture = item_data.item_icon
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		texture_rect.mouse_filter = MOUSE_FILTER_IGNORE
		
		var quantity_label = Label.new()
		quantity_label.text = str(item_info["quantity"])
		# ... (resto da configuração do label)
		
		slot_button.add_child(texture_rect)
		if item_data.is_stackable and item_info["quantity"] > 1:
			slot_button.add_child(quantity_label)
		
		item_grid.add_child(slot_button)

# NOVO: Chamado quando um slot de item é clicado.
func _on_item_slot_pressed(item_data: ItemData):
	emit_signal("item_selected", item_data)
	# Também atualiza o display local imediatamente
	update_selected_item_display(item_data)

# NOVO: Atualiza a UI do "Item Selecionado"
func update_selected_item_display(item_data: ItemData):
	if item_data:
		selected_item_container.visible = true
		selected_item_icon.texture = item_data.item_icon
		selected_item_name.text = item_data.item_name
	else:
		selected_item_container.visible = false
		selected_item_icon.texture = null
		selected_item_name.text = ""


func _on_item_slot_mouse_entered(item_data: ItemData):
	item_description_label.text = "[b]" + item_data.item_name + "[/b]\n" + item_data.item_description

func _on_item_slot_mouse_exited():
	item_description_label.text = ""
	
# Esta função será usada pelo GameMenus.tscn para gerenciar o foco
func _set_menu_visibility(visible_status: bool):
	visible = visible_status
	if visible_status:
		var item_grid_node = $MainContainer/ContentVBox/ItemGrid
		if item_grid_node:
			# Tenta encontrar o primeiro filho focalizável dentro do GridContainer
			for child in item_grid_node.get_children():
				if child is Control and child.focus_mode != Control.FOCUS_NONE:
					child.grab_focus()
					return # Focou em um, então podemos sair
			
			# Se não encontrou nenhum filho focalizável, tenta focar no próprio GridContainer
			if item_grid_node is Control and item_grid_node.focus_mode != Control.FOCUS_NONE:
				item_grid_node.grab_focus()
				return

		# Se nada disso funcionou, tenta focar no container principal do menu
		if $MainContainer is Control and $MainContainer.focus_mode != Control.FOCUS_NONE:
			$MainContainer.grab_focus()
		else:
			# Último recurso: focar no nó raiz do InventoryMenu, se ele for focalizável
			if focus_mode != Control.FOCUS_NONE:
				grab_focus()
			
	else:
		# Quando o menu é fechado, remova o foco
		release_focus()
