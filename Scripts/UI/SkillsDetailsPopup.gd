extends Control

# --- SINAIS ---
signal closed_popup
signal upgrade_compiled(recipe_data: UpgradeRecipeData)

# --- PRELOADS ---
const FragmentIconScene = preload("res://Scenes/Upgrades/FragmentIcon.tscn")
const RecipeSlotScene = preload("res://Scenes/Upgrades/RecipeSlot.tscn")

# --- REFERÊNCIAS DA CENA ---
@onready var skill_name_label = $DetailsPanel/ContentVbox/HeaderVbox/SkillNameLabel
@onready var code_label = $DetailsPanel/ContentVbox/HBoxContainer/RecipePanel/CodePanel/CodeLabel
@onready var recipe_slots_container = $DetailsPanel/ContentVbox/HBoxContainer/RecipePanel/RecipeSlotsContainer
@onready var fragment_inventory_grid = $DetailsPanel/ContentVbox/HBoxContainer/FragmentsPanel/ScrollContainer/FragmentInventoryGrid
@onready var compile_button = $DetailsPanel/ContentVbox/HBoxContainer/RecipePanel/CompileButton
@onready var close_button = $DetailsPanel/CloseButton


# --- VARIÁVEIS DE ESTADO ---
var possible_recipes: Array[UpgradeRecipeData] # AGORA é uma lista de receitas
var player_node: Node
var placed_fragments = []
var base_code_text: String # NOVO: Guarda o código original
var current_code_text: String # NOVO: Guarda o código como está agora

func _ready():
	close_button.pressed.connect(on_close_button_pressed)
	compile_button.pressed.connect(_on_compile_button_pressed)
	# Conecta o sinal do jogador para atualizar o inventário de fragmentos em tempo real
	# Precisamos garantir que a referência do player_node exista antes de conectar
	
# ATUALIZADO: A função agora recebe uma LISTA de receitas
# ATUALIZADO: A função agora recebe o nome e o código base da skill
func open_with_recipes(recipes: Array[UpgradeRecipeData], p_player: Node, skill_name: String, p_base_code: String):
	self.possible_recipes = recipes
	self.player_node = p_player
	self.base_code_text = p_base_code
	
	if is_instance_valid(player_node) and not player_node.code_fragments_inventory_updated.is_connected(populate_fragment_inventory):
		player_node.code_fragments_inventory_updated.connect(populate_fragment_inventory)

	# Usa o nome da função e o código recebidos
	skill_name_label.text = skill_name
	update_code_display() # Exibe o código base e os upgrades já feitos
	
	populate_recipe_slots()
	populate_fragment_inventory()
	
	compile_button.disabled = false

# ATUALIZADO: Cria um número fixo de slots universais
func populate_recipe_slots():
	for child in recipe_slots_container.get_children():
		child.queue_free()
	placed_fragments.clear()
	
	# AGORA, cria os slots baseado no tamanho da PRIMEIRA receita disponível
	# (uma melhoria futura seria ter uma UI para selecionar qual receita montar)
	var recipe_to_show = find_next_available_recipe()
	if not recipe_to_show:
		# Se não houver mais upgrades, podemos mostrar uma mensagem
		var no_more_upgrades_label = Label.new()
		no_more_upgrades_label.text = "Todos os upgrades instalados."
		recipe_slots_container.add_child(no_more_upgrades_label)
		return

	var slots_to_create = recipe_to_show.required_fragments.size()
	for i in range(slots_to_create):
		var slot_instance = RecipeSlotScene.instantiate()
		slot_instance.fragment_changed.connect(_on_fragment_changed_in_slot)
		recipe_slots_container.add_child(slot_instance)
	
	placed_fragments.resize(slots_to_create)
	placed_fragments.fill(null)

# ATUALIZADO: Agora pode ser chamado por um sinal
# Em SkillsDetailsPopup.gd

# Substitua a função inteira por esta versão com depuração
func populate_fragment_inventory(_inventory_data = {}):
	print("--- Iniciando populate_fragment_inventory ---")

	# Limpa os filhos antigos
	for child in fragment_inventory_grid.get_children():
		child.queue_free()
		
	if not is_instance_valid(player_node):
		print("DEBUG: Referência do player_node é INVÁLIDA.")
		return
	
	print("DEBUG: Player encontrado. Verificando inventário de fragmentos...")
	var inventory_to_display = player_node.code_fragments_inventory
	
	if inventory_to_display.is_empty():
		print("DEBUG: Inventário de fragmentos do jogador está VAZIO.")
		return
	else:
		print("DEBUG: Encontrados ", inventory_to_display.size(), " tipos de fragmentos no inventário.")

	# Itera sobre os fragmentos e cria os ícones
	for fragment_id in inventory_to_display:
		var fragment_info = inventory_to_display[fragment_id]
		var fragment_data = fragment_info["data"]
		print("DEBUG: Criando ícone para o fragmento '", fragment_data.fragment_text, "'")
		
		var icon_instance = FragmentIconScene.instantiate()
		icon_instance.fragment_data = fragment_data
		fragment_inventory_grid.add_child(icon_instance)
	
	print("--- Finalizando populate_fragment_inventory ---")
# ATUALIZADO: Apenas rastreia o estado atual dos slots
func _on_fragment_changed_in_slot(fragment_data: CodeFragmentData, slot_instance: Panel):
	var slot_index = slot_instance.get_index()
	placed_fragments[slot_index] = fragment_data

# NOVO: Esta função é responsável por exibir e atualizar o código
func update_code_display():
	current_code_text = base_code_text
	# Itera sobre as receitas e os upgrades já desbloqueados pelo jogador
	for recipe in possible_recipes:
		if recipe.upgrade_effect_id in player_node.unlocked_upgrade_ids:
			# Se o upgrade está desbloqueado, substitui o placeholder pela linha de código final
			current_code_text = current_code_text.replace(recipe.placeholder_to_replace, recipe.result_code_line)
	
	code_label.text = current_code_text
# REESCRITO: A lógica principal agora está no botão "Compilar"
func _on_compile_button_pressed():
	if not player_node: return

	var current_combination = []
	for fragment in placed_fragments:
		if fragment != null:
			current_combination.append(fragment) # Guardamos o objeto Resource inteiro

	if current_combination.is_empty():
		print("Nenhum fragmento para compilar.")
		return

	# Itera sobre todas as receitas possíveis para esta habilidade
	for recipe in possible_recipes:
		# A condição de verificação é esta:
		var recipe_matches = (recipe.required_fragments == current_combination)
		var is_new = not (recipe.upgrade_effect_id in player_node.unlocked_upgrade_ids)
		
		# Se a combinação for igual E o upgrade for novo...
		if recipe_matches and is_new:
			print("Compilação bem-sucedida! Receita encontrada: ", recipe.upgrade_name)
			
			# Chama a função no jogador para aplicar o efeito do upgrade
			player_node.apply_skill_upgrade(recipe.upgrade_effect_id)
			
			# Atualiza o display do código imediatamente para o jogador ver a mudança
			update_code_display()
			
			emit_signal("upgrade_compiled", recipe)
			
			return # Sai da função após o sucesso

	# Se o loop terminar e nenhuma receita válida for encontrada
	print("Falha na compilação. A combinação de fragmentos não corresponde a nenhum upgrade conhecido ou já foi instalada.")
	# Adicionar um feedback de erro aqui (ex: tremer os slots, som de erro)

func on_close_button_pressed():
	# Desconecta o sinal para evitar erros quando o popup for destruído
	if is_instance_valid(player_node) and player_node.code_fragments_inventory_updated.is_connected(populate_fragment_inventory):
		player_node.code_fragments_inventory_updated.disconnect(populate_fragment_inventory)
	closed_popup.emit()
	queue_free()
	
func find_next_available_recipe() -> UpgradeRecipeData:
	if not is_instance_valid(player_node): return null
	for recipe in possible_recipes:
		if not recipe.upgrade_effect_id in player_node.unlocked_upgrade_ids:
			return recipe # Retorna a primeira receita que o jogador ainda não tem
	return null # Retorna nulo se todos os upgrades já foram feitos
	
func _unhandled_input(event):
	# Se a ação "ui_cancel" (geralmente ESC) for pressionada...
	if event.is_action_pressed("ui_cancel"):
		# ...marca o evento como "manuseado". Isso impede que outros nós (como o GameMenus)
		# recebam este mesmo evento e reajam a ele.
		get_viewport().set_input_as_handled()
		# Chama a nossa função de fechar o popup.
		on_close_button_pressed()
