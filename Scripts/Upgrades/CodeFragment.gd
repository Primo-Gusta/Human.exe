# CodeFragment.gd
extends Area2D
class_name CodeFragment

## Arraste um arquivo .tres do tipo CodeFragmentData aqui no Inspetor.
@export var fragment_data: CodeFragmentData

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collect_delay_timer = $CollectDelayTimer
@onready var collision_shape = $CollisionShape2D

func _ready():
	# Conecta o sinal 'body_entered' da própria Area2D a uma função neste script.
	self.body_entered.connect(_on_body_entered)

	# Atualiza a aparência do fragmento no mundo com base no ícone definido nos dados.
	if fragment_data and fragment_data.icon:
		sprite_2d.texture = fragment_data.icon
	else:
		print("AVISO: O fragmento '", self.name, "' não tem dados ou ícone definido.")

## Chamado automaticamente quando um corpo físico (como o Player) entra na área.
func _on_body_entered(body):
	# Verificamos se o corpo que entrou na área pertence ao grupo "player".
	if body.is_in_group("player"):
		# Verifica se o jogador tem o método para adicionar fragmentos
		if body.has_method("add_fragment_to_inventory"):
			print("Fragmento '", fragment_data.fragment_text, "' coletado!")
			
			# Chama a função específica para adicionar fragmentos no jogador
			body.add_fragment_to_inventory(fragment_data)
			
			# Remove o fragmento do mundo.
			queue_free()

# Esta função será chamada pelo Baú
func activate_collect_delay(duration: float):
	collision_shape.disabled = true # Desativa a coleta
	collect_delay_timer.wait_time = duration
	collect_delay_timer.start()
	collect_delay_timer.timeout.connect(_on_collect_delay_timer_timeout)

func _on_collect_delay_timer_timeout():
	collision_shape.disabled = false # Reativa a coleta
