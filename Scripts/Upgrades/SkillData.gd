extends Resource
class_name SkillData

@export var skill_id: String = ""
@export var skill_name: String = "Nova Habilidade"
@export var icon: Texture2D
@export_multiline var description: String = "Descrição da habilidade."
@export var function_name: String = "func new_skill()"
@export_multiline var base_code: String = "# Escreva o código aqui"
@export var recipes: Array[UpgradeRecipeData]
# --- ADICIONE AS LINHAS ABAIXO ---
@export var skill_scene: PackedScene # A cena da habilidade (ex: AttackPulseSkill.tscn)
@export_group("Stats Base")
@export var mana_cost: int = 5
@export var cooldown_time: float = 2.0
@export_group("Attack Pulse Stats") # Use grupos para organizar
@export var base_damage: int = 1
@export var base_range: float = 60.0
# --- ADICIONE O GRUPO E A LINHA ABAIXO ---
@export_group("Attack Loop Stats")
@export var base_bounces: int = 2
