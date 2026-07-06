extends Node
## SkinRegistry — Autoload singleton.
## Swaps grey placeholder Sprite2D textures for final transparent PNGs by
## node group, without touching any grid/push logic. If a final PNG does not
## exist yet, the placeholder is silently kept, so art can land incrementally.

## Logical group name -> final art path. Add entries as Tu Anh's PNGs arrive.
const SKIN_MAP: Dictionary = {
	"skin_wall":    "res://art/final/wall.png",
	"skin_pot":     "res://art/final/pot.png",
	"skin_goal":    "res://art/final/goal.png",
	"skin_balcony": "res://art/final/balcony.png",
	"skin_ledge":   "res://art/final/ledge.png",
	"skin_floor":   "res://art/final/floor.png",
}

## Must match the cell size used by puzzle.gd grid movement.
const CELL_SIZE: int = 64

## If true, incoming PNGs are auto-scaled to fit exactly one grid cell.
const FIT_TO_CELL: bool = true

var _cache: Dictionary = {}


## Call once from the root of any scene whose placeholders should be skinned.
func apply_skins(scene_root: Node) -> void:
	for group_name: String in SKIN_MAP.keys():
		var texture: Texture2D = _get_texture(group_name)
		if texture == null:
			continue  # Final art not delivered yet; keep placeholder.
		for node: Node in scene_root.get_tree().get_nodes_in_group(group_name):
			_apply_to_node(node, texture)


# --- Internal ---

func _get_texture(group_name: String) -> Texture2D:
	if _cache.has(group_name):
		return _cache[group_name]
	var path: String = SKIN_MAP[group_name]
	if not ResourceLoader.exists(path):
		_cache[group_name] = null
		return null
	var tex: Texture2D = load(path)
	_cache[group_name] = tex
	return tex


func _apply_to_node(node: Node, texture: Texture2D) -> void:
	if node is Sprite2D:
		var sprite: Sprite2D = node
		sprite.texture = texture
		if FIT_TO_CELL and texture.get_width() > 0 and texture.get_height() > 0:
			sprite.scale = Vector2(
				float(CELL_SIZE) / texture.get_width(),
				float(CELL_SIZE) / texture.get_height()
			)
	elif node is TextureRect:
		(node as TextureRect).texture = texture
