class_name Actor
extends Node2D

## A walking sprite. The origin sits at the feet. Sheets are laid out with
## one column per facing (down, up, left, right) and one row per walk frame;
## single-row animal sheets just loop their frames and flip for direction.

signal arrived

enum Facing { DOWN, UP, LEFT, RIGHT }

var id := ""
var sprite := Sprite2D.new()
var target := Vector2.ZERO
var moving := false
var speed := 40.0
var facing := Facing.DOWN
var _step := 0.0


func setup(visitor: String) -> Actor:
	id = visitor
	sprite.texture = Visitors.sheet(visitor)
	sprite.hframes = Visitors.hframes(visitor)
	sprite.vframes = Visitors.vframes(visitor)
	var cell_h := sprite.texture.get_height() / float(sprite.vframes)
	sprite.offset = Vector2(0, -cell_h / 2.0)
	add_child(sprite)
	_show_frame(0)
	return self


func walk_to(point: Vector2, pace: float = 40.0) -> void:
	target = point
	speed = pace
	moving = true


func face(dir: Facing) -> void:
	facing = dir
	_show_frame(0)


func flash(color: Color = Color(3, 3, 3)) -> void:
	sprite.modulate = color
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _process(delta: float) -> void:
	if not moving:
		return
	var to := target - position
	if to.length() <= speed * delta:
		position = target
		moving = false
		_show_frame(0)
		arrived.emit()
		return
	position += to.normalized() * speed * delta
	if absf(to.x) > absf(to.y):
		facing = Facing.RIGHT if to.x > 0 else Facing.LEFT
	else:
		facing = Facing.DOWN if to.y > 0 else Facing.UP
	_step += delta * speed / 6.0
	_show_frame(int(_step))


func _show_frame(step: int) -> void:
	if sprite.vframes == 1:
		sprite.frame = step % sprite.hframes
		sprite.flip_h = facing == Facing.RIGHT
	else:
		sprite.frame_coords = Vector2i(facing, step % mini(4, sprite.vframes))
