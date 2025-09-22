# CodeFragmentData.gd
extends Resource
class_name CodeFragmentData

## O texto que será exibido no fragmento (ex: "projectile.speed", "+=", "1.2").
@export var fragment_text: String = "novo_fragmento"

## Um ID único para que a "receita" possa verificar se este é o fragmento correto.
## Manteremos simples, usando o próprio texto como ID por enquanto.
@export var fragment_id: String = ""

## O ícone que representará este fragmento no inventário de componentes.
@export var icon: Texture2D

func _init():
	# Garante que, se o ID não for definido manualmente, ele use o texto do fragmento como um ID.
	if fragment_id == "":
		fragment_id = fragment_text
