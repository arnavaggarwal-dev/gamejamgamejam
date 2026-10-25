extends Area2D
## The king's rocket hand: fired along his arm at the player, it leaves stretched and slow, then
## its jet thrusts it up to full speed; once it reaches the floor it skids along it and flies on
## out of the arena. A hazard (layer 8); its Life timer frees it.

const SKID_Y := 580.0  # where it runs along the floor
const THRUST_TIME := 0.18  # s from the slow pop off the wrist to full speed

var velocity := Vector2.ZERO
var _age := 0.0

## Sets it flying (its "launch" clip pops it off stretched along its flight, springing back).
func launch(v: Vector2) -> void:
	velocity = v
	rotation = v.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	position += velocity * minf(1.0, 0.25 + _age / THRUST_TIME) * delta
	if velocity.y > 0.0 and global_position.y >= SKID_Y:
		global_position.y = SKID_Y
		velocity = Vector2(signf(velocity.x) * velocity.length(), 0.0)
		get_tree().call_group("camera", "shake", 6.0)
	rotation = velocity.angle()
