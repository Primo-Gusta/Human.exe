extends Resource
class_name SpawnerEntry

## A cena que queremos instanciar (ex: Chest.tscn)
@export var scene: PackedScene

## Os dados a serem injectados na instância (ex: um LootTableData.tres)
@export var data_resource: Resource
