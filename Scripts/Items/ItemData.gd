# ItemData.gd
extends Resource
class_name ItemData

## O nome do item, que será exibido no inventário.
@export var item_name: String = "Novo Item"

## A descrição do item, para quando o jogador inspecioná-lo.
@export var item_description: String = "Descreva o item aqui."

## O ícone que representará o item na UI (inventário, HUD, etc.).
@export var item_icon: Texture2D

## O item pode ser empilhado no inventário?
@export var is_stackable: bool = true

@export_enum("Nenhum", "Cura", "Mana") var effect_type: String = "Nenhum"
@export var effect_value = 0.0
