extends Node2D
class_name LevelLayout

@export var loots_layer: TileMapLayer
@export var world_objects_node_path: NodePath = "WorldObjects" # Caminho para o nó que vai receber os objetos

# Preloads das cenas
const CHEST_SCENE = preload("res://Scenes/Items/Chest.tscn")
const CRATE_SCENE = preload("res://Scenes/Items/Crate.tscn")

var object_layers: Array

func _ready():
	object_layers = [loots_layer]
	await get_tree().process_frame
	_populate_objects_from_layers()

func _populate_objects_from_layers():
	if not is_instance_valid(loots_layer):
		print("LevelLayout: Layer de loot inválida.")
		return

	var world_objects_node = get_node(world_objects_node_path)
	if not is_instance_valid(world_objects_node):
		print("LevelLayout: WorldObjects node inválido ou não encontrado.")
		return
	
	for layer in object_layers:
		if not is_instance_valid(layer):
			continue

		var used_cells = layer.get_used_cells()

		# Marca quais células já processamos para não criar múltiplos objetos
		var processed_cells := {}

		for cell in used_cells:
			if processed_cells.has(cell):
				continue

			var source_id = layer.get_cell_source_id(cell)
			if source_id == -1:
				continue

			# Verifica se esta célula é “top-left” do tile multi-cell
			var origin_meta = layer.get_cell_meta(cell, "origin") if layer.has_method("get_cell_meta") else true
			if not origin_meta:
				continue # não é top-left, ignora

			# Determina qual objeto spawnar
			var instance: Node = null
			match source_id:
				1:
					instance = CHEST_SCENE.instantiate()
				2:
					instance = CRATE_SCENE.instantiate()
				_:
					continue # ignora outros tiles

			# Calcula a posição global correta
			var local_pos = layer.map_to_local(cell)
			var world_pos = layer.to_global(local_pos) + Vector2(layer.tile_set.tile_size) / 2

			# Adiciona ao nó correto para interação
			world_objects_node.add_child(instance)
			instance.global_position = world_pos

			# Marca todas as células 2x2 como processadas para não repetir
			for x in range(2):
				for y in range(2):
					processed_cells[cell + Vector2i(x,y)] = true

			# Remove as células do TileMap
			for x in range(2):
				for y in range(2):
					layer.erase_cell(cell + Vector2i(x,y))
		
	print("LevelLayout: Povoamento de objetos concluído.")
