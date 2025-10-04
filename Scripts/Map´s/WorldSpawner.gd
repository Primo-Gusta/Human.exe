extends Node2D

@onready var tilemap: TileMapLayer = $TileMapLayer
@export var breakable_source_id: int = 2

func _ready():
	# Percorre todas as células usadas neste TileMapLayer
	for cell in tilemap.get_used_cells():
		var source_id = tilemap.get_cell_source_id(cell)
		var atlas_coords = tilemap.get_cell_atlas_coords(cell)
		var tile_data = tilemap.get_cell_tile_data(cell)

		if tile_data == null:
			continue

		# Verifica se é um tile "quebrável"
		if source_id == breakable_source_id:
			var world_pos = tilemap.map_to_local(cell)
			var tile_size = tilemap.tile_set.tile_size

			# Converte tudo para Vector2 para evitar erro de tipo
			var object_pos = world_pos + Vector2(tile_size.x / 2, tile_size.y / 2)

			# Cria o objeto quebrável
			spawn_breakable(object_pos)

			# Remove o tile original do mapa
			tilemap.erase_cell(cell)


func spawn_breakable(position: Vector2):
	# Cria e posiciona um objeto que representa algo "quebrável"
	var breakable = Node2D.new()
	breakable.name = "Breakable"
	breakable.position = position
	add_child(breakable)

	# Apenas exemplo visual (poderia ser uma Sprite2D real)
	var sprite = Sprite2D.new()
	# sprite.texture = preload("res://sprites/box.png") # substitua com o caminho certo
	sprite.scale = Vector2(0.5, 0.5)
	breakable.add_child(sprite)
