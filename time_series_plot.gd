class_name TimeSeriesPlot
extends Panel


@export var max_data_points := -1

@export var data_range_lower := -1.0

@export var data_range_upper := 1.0

@export var vertical_padding := 0.1

@export var tick_count := 5

@export var tick_width := 10.0

@export var tick_label_width := 64.0

@export var line_color := Color.WHITE_SMOKE

@export var tick_color := Color(0.375, 0.375, 0.375)


var _points := PackedVector2Array()

var _cursor_position := -Vector2i.ONE


@onready var _font := ThemeDB.fallback_font

@onready var _cursor_node := Control.new()


func _ready() -> void:
	clip_contents = true

	_cursor_node.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	_cursor_node.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
	_cursor_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_node.draw.connect(_on_cursor_draw)
	add_child(_cursor_node)


func _process(_delta : float) -> void:
	var mouse_position := Vector2i(get_local_mouse_position())
	var mouse_position_int := Vector2i(mouse_position)
	if Rect2(Vector2.ZERO, size).has_point(mouse_position):
		if mouse_position_int != _cursor_position:
			_cursor_position = mouse_position
			_cursor_node.queue_redraw()
	elif _cursor_position.x >= 0:
		_cursor_position.x = -1
		_cursor_node.queue_redraw()


func push_value(value : float) -> void:
	var x := _points[_points.size() - 1].x + 1.0 if not _points.is_empty() else 0.0
	_points.push_back(Vector2(x, value))
	for i in _points.size() - _get_current_max_data_points():
		_points.remove_at(0)
	_on_data_changed()


func clear_data() -> void:
	_points.clear()
	_on_data_changed()


func _draw() -> void:
	if _points.size() < 2:
		return

	_draw_ticks()
	_draw_line_plot()


func _draw_line_plot() -> void:
	draw_set_transform_matrix(_compute_draw_transform())
	draw_polyline(_points, line_color)


func _draw_ticks() -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var value_transform := _compute_draw_transform()

	var x_from := size.x - tick_width
	var x_to := size.x
	var x_label := size.x - 1.5 * tick_width

	for i in tick_count:
		var tick_distance := (data_range_upper - data_range_lower) / (tick_count - 1)
		var y := data_range_lower + i * tick_distance
		var transformed_y := (value_transform * Vector2(0.0, y)).y
		draw_line(
			Vector2(x_from, transformed_y),
			Vector2(x_to, transformed_y),
			tick_color
		)

		var font_size := tick_width
		draw_string(
			_font,
			Vector2(floor(x_label - tick_label_width), floor(transformed_y + 0.5 * font_size)),
			str(y),
			HORIZONTAL_ALIGNMENT_RIGHT,
			tick_label_width,
			roundi(font_size),
			tick_color
		)


func _on_cursor_draw() -> void:
	if _cursor_position.x < 0:
		return

	var font_size := tick_width

	_cursor_node.draw_line(
		Vector2(_cursor_position.x, 2.0 * font_size),
		Vector2(_cursor_position.x, size.y),
		tick_color
	)

	var value_transform := _compute_draw_transform()
	var transform_scale := value_transform.get_scale()
	var index := roundi(_cursor_position.x / transform_scale.x)
	if index < _points.size():
		var y := _points[index].y
		var transformed_y := floorf(y * transform_scale.y + value_transform.origin.y)

		_cursor_node.draw_circle(
			Vector2(_cursor_position.x, transformed_y),
			3.0,
			line_color
		)

		_cursor_node.draw_string(
			_font,
			Vector2(_cursor_position.x - 0.5 * tick_label_width, 1.5 * font_size),
			str(y),
			HORIZONTAL_ALIGNMENT_CENTER,
			tick_label_width,
			roundi(font_size),
			tick_color
		)


func _compute_draw_transform() -> Transform2D:
	var range_width := data_range_upper - data_range_lower
	var scaling := Vector2(
		size.x / _get_current_max_data_points(),
		-size.y / (range_width + 2.0 * vertical_padding * range_width)
	)
	var translation := scaling * Vector2(
		-_points[0].x,
		-data_range_upper - vertical_padding * range_width
	)
	return Transform2D(0.0, scaling, 0.0, translation)


func _on_data_changed() -> void:
	queue_redraw()
	if _cursor_position.x >= 0:
		_cursor_node.queue_redraw()


func _get_current_max_data_points() -> int:
	return max_data_points if max_data_points >= 0 else int(size.x)
