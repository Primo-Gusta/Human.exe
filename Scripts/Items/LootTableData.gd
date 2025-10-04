extends Resource
class_name LootTableData

## A lista de todos os possíveis drops desta tabela de loot.
## Clique em "Add Element" para criar novos slots de loot.
@export var loot_drops: Array[LootDrop]
@export var contains_unique_code_fragment: bool = false
