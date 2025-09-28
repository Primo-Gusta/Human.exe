extends Area2D

# Referências para as colisões do anel
@onready var outer_shape: CollisionShape2D = $OuterShape
@onready var inner_shape: CollisionShape2D = $InnerShape
# Referência para o nó que contém os visuais
@onready var visuals: Node2D = $Visuals

var damage = 1
var border_thickness = 20.0 # Espessura da borda de dano em pixels

func _ready():
	add_to_group("attack_waves") # ADICIONE ESTA LINHA
	# Garante que a onda seja desenhada abaixo dos personagens
	z_index = -10
	body_entered.connect(_on_body_entered)
	# Começa invisível e com colisões desativadas
	visuals.modulate.a = 0.0
	outer_shape.disabled = true
	inner_shape.disabled = true

# A nova função de ativação, que agora controla todo o ciclo de vida
func activate(radius: float, color: Color, stay_duration: float, fade_out_duration: float):
	# Define a cor do anel
	visuals.modulate = color
	
	# Define o tamanho do anel (colisão e visual)
	outer_shape.shape.radius = radius
	inner_shape.shape.radius = max(0, radius - border_thickness)
	# Ajusta a escala do visual para corresponder ao raio da colisão
	# O '50.0' é um número mágico baseado no tamanho do seu sprite. Ajuste se necessário.
	visuals.scale = Vector2.ONE * (radius / 50.0)
	
	# Ativa as colisões
	outer_shape.disabled = false
	inner_shape.disabled = false
	
	# Cria o tween para controlar o tempo de vida
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT)
	
	# 1. Permanece visível pelo tempo definido
	tween.tween_interval(stay_duration)
	
	# 2. Desaparece (fade-out)
	tween.tween_property(visuals, "modulate:a", 0.0, fade_out_duration)
	
	# 3. Quando o tween terminar, o nó se autodestrói
	tween.finished.connect(queue_free)

func _on_body_entered(body):
	if body.is_in_group("player"):
		var knockback_direction = global_position.direction_to(body.global_position)
		body.take_damage(damage, knockback_direction)
		# Desativa as colisões para não causar dano múltiplo
		outer_shape.set_deferred("disabled", true)
		inner_shape.set_deferred("disabled", true)
