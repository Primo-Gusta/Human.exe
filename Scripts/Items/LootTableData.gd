extends Resource
class_name LootTableData

# Vamos criar uma classe aninhada para definir um "drop"
# Isso nos permite configurar cada item individualmente no Inspetor
class LootDrop extends Resource:
	@export var item_data: Resource # Pode ser ItemData ou CodeFragmentData
	@export var quantity: int = 1
	@export_range(0, 100) var chance_percent: float = 100.0 # Chance em % de este item dropar

# A lista de todos os possíveis drops desta tabela de loot
@export var loot_drops: Array[LootDrop]
