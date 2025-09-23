extends Resource
class_name SkillData

## O nome da habilidade (ex: "Pulso de Ataque").
@export var skill_name: String = "Nova Habilidade"

## O ícone da habilidade para a UI.
@export var icon: Texture2D

## A descrição do que a habilidade faz.
@export_multiline var description: String = "Descrição da habilidade."

## O nome da função que será exibido na "IDE".
@export var function_name: String = "func new_skill()"

@export var skill_id: String = ""
## O código base da habilidade, com os placeholders de upgrade.
@export_multiline var base_code: String = "# Escreva o código aqui"

## A lista de todas as receitas de upgrade para esta habilidade.
## Arraste os arquivos UpgradeRecipeData.tres aqui.
@export var recipes: Array[UpgradeRecipeData]
