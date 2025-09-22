extends Resource
class_name LootDrop

## Arraste o .tres do item (ItemData ou CodeFragmentData) aqui.
@export var item_data: Resource

## Quantidade do item a ser gerada.
@export var quantity: int = 1

## A chance em % (de 0 a 100) de este item ser gerado.
@export_range(0, 100) var chance_percent: float = 100.0
