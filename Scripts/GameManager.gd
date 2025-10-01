extends Node

var main_menu_scene = "res://Scenes/UI/MainMenu.tscn"
var world_scene = "res://Scenes/Maps/World.tscn"

func _ready():
	# Garante que o jogo não está pausado quando o gestor inicia
	get_tree().paused = false

func go_to_main_menu():
	print("GameManager: A voltar para o Main Menu...")
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func start_new_game():
	print("GameManager: A iniciar novo jogo...")
	get_tree().paused = false
	get_tree().change_scene_to_file(world_scene)

func restart_current_level():
	print("GameManager: A reiniciar o nível actual...")
	get_tree().paused = false
	# Usamos change_scene_to_file com o caminho da cena actual para garantir um reinício limpo
	get_tree().change_scene_to_file(get_tree().current_scene.scene_file_path)
