extends Node2D

@export var columns: int = 6
@export var rows: int = 6
@export var tiles_per_grid_cell: Vector2i = Vector2i(1, 1)
@export var auto_origin_from_used_rect: bool = true
@export var grid_origin_tile: Vector2i = Vector2i.ZERO
@export_node_path("TileMap") var tile_map_path: NodePath = NodePath("TileMap")

@onready var _tile_map: TileMap = get_node(tile_map_path)


func is_inside(grid_position: Vector2i) -> bool:
	return grid_position.x >= 0 and grid_position.y >= 0 and grid_position.x < columns and grid_position.y < rows


func grid_to_world(grid_position: Vector2i) -> Vector2:
	var cell_span: Vector2i = _get_cell_span()
	var origin_tile: Vector2i = _get_grid_origin_tile(cell_span)
	var map_cell: Vector2i = origin_tile + Vector2i(grid_position.x * cell_span.x, grid_position.y * cell_span.y)

	var cell_center_local: Vector2 = _tile_map.map_to_local(map_cell)
	var tile_size: Vector2 = Vector2(_tile_map.tile_set.tile_size)
	var block_center_offset: Vector2 = tile_size * (Vector2(cell_span) - Vector2.ONE) * 0.5
	return _tile_map.to_global(cell_center_local + block_center_offset)


func world_to_grid(world_position: Vector2) -> Vector2i:
	var cell_span: Vector2i = _get_cell_span()
	var origin_tile: Vector2i = _get_grid_origin_tile(cell_span)
	var local_position: Vector2 = _tile_map.to_local(world_position)
	var map_position: Vector2i = _tile_map.local_to_map(local_position)
	var relative_tile: Vector2i = map_position - origin_tile
	return Vector2i(
		floori(float(relative_tile.x) / float(cell_span.x)),
		floori(float(relative_tile.y) / float(cell_span.y))
	)


func get_arena_center_world() -> Vector2:
	var center: Vector2 = Vector2((columns - 1) / 2.0, (rows - 1) / 2.0)
	return grid_to_world(Vector2i(roundi(center.x), roundi(center.y)))


func _get_cell_span() -> Vector2i:
	return Vector2i(max(1, tiles_per_grid_cell.x), max(1, tiles_per_grid_cell.y))


func _get_grid_origin_tile(cell_span: Vector2i) -> Vector2i:
	if not auto_origin_from_used_rect:
		return grid_origin_tile

	var used_rect: Rect2i = _tile_map.get_used_rect()
	var grid_tiles_size: Vector2i = Vector2i(columns * cell_span.x, rows * cell_span.y)
	var delta: Vector2i = used_rect.size - grid_tiles_size
	var half_delta: Vector2i = Vector2i(
		floori(delta.x / 2.0),
		floori(delta.y / 2.0)
	)
	return used_rect.position + half_delta
