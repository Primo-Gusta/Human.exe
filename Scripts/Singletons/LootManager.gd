extends Node

# O caminho para a pasta que contém TODOS os seus recursos .tres de CodeFragmentData
const FRAGMENTS_PATH = "res://Resources/Fragments/"

# A lista que guardará todos os fragmentos que ainda não foram encontrados no jogo
var available_fragments: Array[CodeFragmentData] = []

func _ready():
	# Esta função é chamada uma vez quando o jogo inicia
	_load_all_fragments()

# Carrega todos os recursos da pasta e popula a nossa lista
func _load_all_fragments():
	print("LootManager: A carregar todos os Code Fragments...")
	
	var dir = DirAccess.open(FRAGMENTS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Garante que estamos a ler apenas ficheiros .tres
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var fragment_resource = load(FRAGMENTS_PATH + file_name)
				if fragment_resource is CodeFragmentData:
					available_fragments.append(fragment_resource)
			
			file_name = dir.get_next()
	else:
		push_error("LootManager: Não foi possível encontrar a pasta de fragmentos em: " + FRAGMENTS_PATH)

	# Embaralha a lista para garantir que a ordem de drop seja aleatória a cada jogo
	available_fragments.shuffle()
	print("LootManager: ", available_fragments.size(), " fragmentos carregados e prontos.")

# A função que os baús irão chamar para obter um fragmento único
func get_unique_code_fragment() -> CodeFragmentData:
	if available_fragments.is_empty():
		print("LootManager AVISO: Não há mais fragmentos de código únicos para distribuir.")
		return null

	# Retira e retorna o último fragmento da nossa lista embaralhada
	var fragment = available_fragments.pop_back()
	print("LootManager: A distribuir o fragmento '", fragment.fragment_id, "'. Restam: ", available_fragments.size())
	return fragment
