# Item.gd
extends Area2D
class_name Item

## Sinal emitido quando o item é coletado pelo jogador.
## Passa os dados completos do item (o Resource) para quem estiver ouvindo (o Player).
signal item_collected(item_data: ItemData)

## A "alma" do item. Arraste um arquivo .tres de ItemData aqui no Inspetor.
@export var item_data: ItemData

@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready():
	# Conecta o sinal 'body_entered' da própria Area2D a uma função neste script.
	self.body_entered.connect(_on_body_entered)

	# Atualiza a aparência do item no mundo com base no ícone definido no ItemData.
	if item_data and item_data.item_icon:
		sprite_2d.texture = item_data.item_icon
	else:
		print("AVISO: O item '", self.name, "' não tem um ItemData ou ícone definido.")

## Chamado automaticamente quando um corpo físico (como o Player) entra na área.
func _on_body_entered(body):
	if body.is_in_group("player"):
		# ANTES: item_collected.emit(item_data)
		# AGORA:
		if body.has_method("add_item_to_inventory"):
			body.add_item_to_inventory(item_data)
			queue_free() # Remove o item do mundo
