extends Node2D
## The little guy splattered: a goo burst, gobs of him flying off (his sprout spinning away among
## them) and what is left of him in a puddle on the floor below, if there is one in reach. It
## stays until the restart.

@onready var floor_ray: RayCast2D = $Floor
@onready var puddle: Sprite2D = $Puddle


func _ready() -> void:
	$Burst.animation_finished.connect($Burst.hide)
	Sfx.play(&"splat")
	get_tree().call_group("camera", "shake", 14.0)
	_land.call_deferred()  # once the spawner has put it in place


## The puddle lands on the floor straight below (none over a pit or the acid).
func _land() -> void:
	floor_ray.force_raycast_update()
	if floor_ray.is_colliding():
		puddle.global_position = floor_ray.get_collision_point()
		puddle.show()
		$AnimationPlayer.play(&"splat")
