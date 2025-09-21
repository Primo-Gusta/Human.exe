extends Control # Mantenha como Control

# @onready var item_grid = $MainContainer/ContentVBox/ItemGrid
# @onready var item_description_label = $MainContainer/ContentVBox/ItemDescriptionLabel

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
