extends Node2D
## Throne-room scenery: the crowd cheers on cue (its CheerTimer sends it back to idle, wired in
## the scene), and the room darkens and the torches burn hotter each phase.

const MOODS := [Color(1, 1, 1), Color(0.86, 0.8, 0.95), Color(0.72, 0.64, 0.86)]
const TORCH_TINTS := [Color(1, 1, 1), Color(1.15, 0.9, 0.9), Color(1.35, 0.75, 0.75)]

@onready var crowd: AnimatedSprite2D = $WallLayer/Crowd
@onready var cheer_timer: Timer = $CheerTimer


func cheer(seconds := 1.5) -> void:
	crowd.play(&"cheer")
	cheer_timer.start(maxf(seconds, cheer_timer.time_left))


func set_phase(p: int) -> void:
	create_tween().tween_property(self, "modulate", MOODS[p], 0.6)
	for torch in get_tree().get_nodes_in_group("torches"):
		torch.speed_scale = 1.0 + p * 0.5
		torch.modulate = TORCH_TINTS[p]
	cheer(2.0)
