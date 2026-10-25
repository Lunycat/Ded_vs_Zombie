extends Zombie
class_name ZombieFast

func _ready() -> void:
	super()
	move_speed = 5
	knockback_force = 10
	toss = 3
