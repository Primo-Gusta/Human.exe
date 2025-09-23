extends Node
class_name Skill

## Uma referência ao jogador, que será o "dono" desta habilidade.
## Será definida quando a habilidade for equipada.
var player: CharacterBody2D

## Uma referência aos dados da habilidade (ícone, nome, etc.).
var skill_data: SkillData


# --- Funções "Contrato" ---
# Estas são funções que TODAS as nossas habilidades deverão ter.
# Usamos o '_' no início para indicar que devem ser sobrescritas (overridden)
# pelas classes filhas (como AttackPulseSkill.gd).

## A função principal que executa a lógica da habilidade.
func _execute():
	# Esta função será implementada em cada script de habilidade específico.
	push_warning("A função _execute() não foi implementada para esta habilidade!")

## Uma função para aplicar um upgrade específico a esta habilidade.
func _apply_upgrade(upgrade_id: String):
	# Esta função também será implementada em cada script de habilidade.
	push_warning("A função _apply_upgrade() não foi implementada para esta habilidade!")
