extends Control

@export_enum("axe", "campfire", "spear") var icon_type := "axe"


func _ready() -> void:
	custom_minimum_size = Vector2(72.0, 72.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, minf(size.x, size.y) * 0.47, Color(0.10, 0.16, 0.16, 0.95))
	match icon_type:
		"axe":
			draw_line(center + Vector2(13.0, 19.0), center + Vector2(-7.0, -16.0), Color(0.58, 0.35, 0.17), 7.0, true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-13.0, -19.0),
				center + Vector2(5.0, -23.0),
				center + Vector2(15.0, -7.0),
				center + Vector2(-3.0, -3.0)
			]), Color(0.70, 0.76, 0.75))
		"campfire":
			draw_line(center + Vector2(-19.0, 18.0), center + Vector2(19.0, 4.0), Color(0.48, 0.28, 0.14), 7.0, true)
			draw_line(center + Vector2(-17.0, 3.0), center + Vector2(17.0, 18.0), Color(0.59, 0.35, 0.16), 7.0, true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, 16.0),
				center + Vector2(-12.0, -2.0),
				center + Vector2(-5.0, -1.0),
				center + Vector2(-1.0, -21.0),
				center + Vector2(8.0, -6.0),
				center + Vector2(13.0, -9.0)
			]), Color(0.96, 0.48, 0.14))
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, 11.0),
				center + Vector2(-4.0, 0.0),
				center + Vector2(1.0, -9.0),
				center + Vector2(7.0, 1.0)
			]), Color(1.0, 0.78, 0.28))
		"spear":
			draw_line(center + Vector2(17.0, 20.0), center + Vector2(-13.0, -15.0), Color(0.58, 0.35, 0.17), 6.0, true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-25.0, -27.0),
				center + Vector2(-6.0, -12.0),
				center + Vector2(-16.0, -7.0)
			]), Color(0.74, 0.79, 0.75))
