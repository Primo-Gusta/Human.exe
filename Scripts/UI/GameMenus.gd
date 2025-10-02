extends CanvasLayer

signal menu_closed_requested

@onready var background_overlay: ColorRect = $BackgroundOverlay
@onready var main_container: PanelContainer = $MainContainer
@onready var tabs: TabContainer = $MainContainer/Tabs
@onready var inventory_menu = $MainContainer/Tabs/Inventário
@onready var skills_menu = $MainContainer/Tabs/Habilidades
var player_node: Node

signal request_set_active_item(item_data: ItemData)


# Adicione esta nova função PÚBLICA:
func initialize_with_player(p_player: Node):
	if is_instance_valid(skills_menu) and skills_menu.has_method("initialize"):
		skills_menu.initialize(p_player)

func _ready() -> void:
	visible = false

	# Garantir que o menu processe durante pausa (redundante se World já setou)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Força visibilidade inicial das abas conforme a cena
	if is_instance_valid(inventory_menu):
		inventory_menu.visible = true
	if is_instance_valid(skills_menu):
		skills_menu.visible = false

	if is_instance_valid(tabs):
		tabs.current_tab = 0
		tabs.focus_mode = Control.FOCUS_ALL

		# Conectar o signal usando Callable e evitando múltiplas conexões
		var tab_conn := Callable(self, "_on_tab_changed")
		if not tabs.tab_changed.is_connected(tab_conn):
			tabs.tab_changed.connect(tab_conn)

	# Garantir que controles das abas possam receber foco
	if is_instance_valid(inventory_menu):
		inventory_menu.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(skills_menu):
		skills_menu.focus_mode = Control.FOCUS_ALL
	# NOVO: Conecta o sinal do menu de inventário a uma função neste script
	if is_instance_valid(inventory_menu):
		inventory_menu.item_selected.connect(_on_inventory_item_selected)


func set_menu_state(active: bool) -> void:
	visible = active
	if active:
		_on_tab_changed(tabs.current_tab)
		if is_instance_valid(tabs):
			tabs.grab_focus()
	else:
		_release_focus_recursive(self)
		emit_signal("menu_closed_requested")


func _unhandled_input(event) -> void:
	if not visible:
		return

	# Fecha com a mesma ação de pause (ESC)
	if event.is_action_pressed("toggle_pause") and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		set_menu_state(false)


func _on_tab_changed(tab_index: int) -> void:
	if is_instance_valid(inventory_menu):
		inventory_menu.visible = (tab_index == 0)
	if is_instance_valid(skills_menu):
		skills_menu.visible = (tab_index == 1)

	# Dá foco ao primeiro control interativo da aba
	if is_instance_valid(tabs) and tab_index >= 0 and tab_index < tabs.get_child_count():
		var current_tab_node := tabs.get_child(tab_index)
		if current_tab_node and current_tab_node is Control:
			for child in current_tab_node.get_children():
				if child is Control and child.focus_mode != Control.FOCUS_NONE:
					child.grab_focus()
					break


func _release_focus_recursive(node: Node) -> void:
	if node is Control:
		if node.has_focus():
			node.release_focus()
	for child in node.get_children():
		_release_focus_recursive(child)
		
func update_inventory(inventory_data: Dictionary, current_active_item: ItemData):
	if is_instance_valid(inventory_menu):
		# Passa os dois argumentos para a função do InventoryMenu
		inventory_menu.update_inventory_display(inventory_data, current_active_item)
		
# NOVO: Esta função ouve o sinal do InventoryMenu e o repassa para o World
func _on_inventory_item_selected(item_data: ItemData):
	emit_signal("request_set_active_item", item_data)
	
# Altere a sua função 'initialize' para guardar a referência do player
func initialize(p_player: Node):
	self.player_node = p_player
	if is_instance_valid(skills_menu) and skills_menu.has_method("initialize"):
		skills_menu.initialize(player_node)
	
	# --- NOVA CONEXÃO AQUI ---
	# Conecta o sinal de selecção de item do inventário à função 'set_active_item' do jogador
	if is_instance_valid(inventory_menu) and inventory_menu.has_signal("item_selected"):
		inventory_menu.item_selected.connect(Callable(player_node, "set_active_item"))

		
# Esta função é chamada pelo World.gd
func on_player_inventory_updated(inventory_data: Dictionary, current_active_item: ItemData):
	if is_instance_valid(inventory_menu) and inventory_menu.has_method("update_inventory_display"):
		inventory_menu.update_inventory_display(inventory_data, current_active_item)
