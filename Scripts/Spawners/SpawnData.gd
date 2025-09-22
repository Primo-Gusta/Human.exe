# SpawnData.gd
extends Resource
class_name SpawnData

## Uma lista dos tipos de inimigos que este spawner pode gerar.
## Arraste as cenas .tscn dos inimigos (ex: Enemy.tscn, Worm.tscn) para este array no Inspetor.
@export var enemy_scenes: Array[PackedScene]

## O número máximo de inimigos gerados por este spawner que podem estar vivos ao mesmo tempo.
@export var max_enemies_on_screen: int = 2

## O tempo em segundos que o spawner espera, após todos os seus inimigos serem derrotados,
## para poder gerar novos.
@export var respawn_cooldown: float = 60.0
