# UpgradeRecipeData.gd
extends Resource
class_name UpgradeRecipeData

## O nome do upgrade que será exibido na UI (ex: "Dano do Pulso Aumentado Nv. 1").
@export var upgrade_name: String = "Novo Upgrade"

## A descrição do que o upgrade faz.
@export_multiline var upgrade_description: String = "Descrição do upgrade."

## A qual habilidade este upgrade pertence (ex: "attack_pulse", "attack_loop").
## Usaremos este ID para mostrar apenas as receitas relevantes.
@export var target_skill_id: String = ""

## O ID único que o Player.gd usará para aplicar o efeito correto.
## Ex: "pulse_damage_1", "loop_bounces_1"
@export var upgrade_effect_id: String = ""

## A "receita": uma lista ordenada dos fragmentos de código necessários para este upgrade.
## Arraste os arquivos CodeFragmentData.tres para esta lista no Inspetor.
@export var required_fragments: Array[CodeFragmentData]

## A linha de código final que será exibida na UI após a montagem bem-sucedida.
@export var result_code_line: String = "// Upgrade instalado com sucesso"

## NOVO: O texto do placeholder que esta receita deve substituir no código.
@export var placeholder_to_replace: String = "# UPGRADE 1"
