class_name FloatingRelic
extends Node3D

## FloatingRelic — Artefak jam/mekanik melayang mengikuti bahu player dalam formasi busur.
## Terintegrasi dengan dimensi [T] (WorldManager), HidingSpot, reset saat terkena TheEraser,
## dan altar penyerahan (RelicSocketZone).

signal relic_collected(relic: FloatingRelic)
signal relic_reset(relic: FloatingRelic)
signal relic_delivered(relic: FloatingRelic)

enum RelicState { IDLE_ON_PEDESTAL, COLLECTED, DELIVERING, DELIVERED }

const SHOULDER_SLOTS: Array[Vector3] = [
	Vector3(0.55, 1.55, -0.55),
	Vector3(-0.55, 1.65, -0.55),
	Vector3(0.0, 1.95, -0.65),
]

@export var relic_id: String = "relic_1"
@export var display_name: String = "Artefak Waktu"
@export_enum("Always", "Remembered", "Forgotten") var home_dimension: String = "Remembered"
@export var interact_range: float = 2.9
@export var auto_collect_on_touch: bool = true
@export var follow_lerp_speed: float = 6.5
@export var bob_amplitude: float = 0.12
@export var bob_frequency: float = 4.0
@export var spin_speed_rad: float = 0.85
@export var base_light_energy: float = 1.2
@export var hidden_light_energy: float = 0.1

var state: int = RelicState.IDLE_ON_PEDESTAL

var _initial_transform: Transform3D = Transform3D.IDENTITY
var _initial_home_dimension: String = "Remembered"
var _pedestal_origin: Vector3 = Vector3.ZERO
var _time_acc: float = 0.0
var _recollect_cooldown: float = 0.0
var _player: CharacterBody3D = null
var _world_manager: Node = null
var _is_in_memory: bool = true
var _player_in_pickup_zone: bool = false
var _player_registered: bool = false

var _pickup_zone: Area3D = null
var _glow_light: OmniLight3D = null
var _delivery_tween: Tween = null


func _ready() -> void:
	add_to_group("floating_relic_item")
	_initial_transform = global_transform
	_initial_home_dimension = home_dimension
	_pedestal_origin = _initial_transform.origin
	_strip_physics_colliders(self)
	_setup_nodes()
	_resolve_world_manager()
	_resolve_player()
	_apply_dimension_visibility()


## Menghapus StaticBody3D dari model agar artefak tidak menabrak atau membuat player tersangkut.
func _strip_physics_colliders(node: Node) -> void:
	for child in node.get_children():
		if child.name == "PickupZone":
			continue
		if child is StaticBody3D:
			for sub in child.find_children("*", "CollisionShape3D", true, false):
				(sub as CollisionShape3D).disabled = true
			child.set("collision_layer", 0)
			child.set("collision_mask", 0)
			child.queue_free()
			continue
		_strip_physics_colliders(child)


func _setup_nodes() -> void:
	_pickup_zone = get_node_or_null("PickupZone") as Area3D
	if _pickup_zone == null:
		_pickup_zone = Area3D.new()
		_pickup_zone.name = "PickupZone"
		add_child(_pickup_zone)

	_pickup_zone.collision_layer = 0
	_pickup_zone.collision_mask = 2
	_pickup_zone.monitoring = true
	_pickup_zone.monitorable = false

	var col := _pickup_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere := SphereShape3D.new()
		var world_s := global_transform.basis.get_scale()
		var avg_scale := maxf((absf(world_s.x) + absf(world_s.y) + absf(world_s.z)) / 3.0, 0.05)
		sphere.radius = 1.2 / avg_scale
		col.shape = sphere
		_pickup_zone.add_child(col)

	if not _pickup_zone.body_entered.is_connected(_on_pickup_zone_entered):
		_pickup_zone.body_entered.connect(_on_pickup_zone_entered)
	if not _pickup_zone.body_exited.is_connected(_on_pickup_zone_exited):
		_pickup_zone.body_exited.connect(_on_pickup_zone_exited)

	_glow_light = get_node_or_null("RelicGlowLight") as OmniLight3D
	if _glow_light == null:
		_glow_light = OmniLight3D.new()
		_glow_light.name = "RelicGlowLight"
		_glow_light.light_color = Color(1.0, 0.86, 0.56)
		_glow_light.omni_range = 4.5
		_glow_light.shadow_enabled = false
		_glow_light.position = Vector3(0.0, 3.5, 0.0)
		add_child(_glow_light)
	_glow_light.light_energy = base_light_energy


func _resolve_world_manager() -> void:
	var cur := get_parent()
	while cur:
		if cur.has_signal("dimension_shifted"):
			_world_manager = cur
			break
		cur = cur.get_parent()
	if _world_manager == null and get_tree() and get_tree().current_scene:
		var root := get_tree().current_scene
		if root.has_signal("dimension_shifted"):
			_world_manager = root

	if _world_manager:
		if not _world_manager.is_connected("dimension_shifted", _on_dimension_shifted):
			_world_manager.connect("dimension_shifted", _on_dimension_shifted)
		if "in_memory" in _world_manager:
			_is_in_memory = bool(_world_manager.get("in_memory"))


func _resolve_player() -> void:
	if _player and is_instance_valid(_player):
		return
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		_player = scene.find_child("Player", true, false) as CharacterBody3D
	if _player == null and get_tree():
		_player = get_tree().root.find_child("Player", true, false) as CharacterBody3D


func _is_player_node(body: Node) -> bool:
	return body is CharacterBody3D and (body.name == "Player" or body.is_in_group("player") or "floating_relics" in body)


func _on_dimension_shifted(is_in_memory: bool) -> void:
	_is_in_memory = is_in_memory
	_apply_dimension_visibility()


func _is_active_in_dimension() -> bool:
	match home_dimension:
		"Remembered":
			return _is_in_memory
		"Forgotten":
			return not _is_in_memory
		_:
			return true


func _apply_dimension_visibility() -> void:
	if state == RelicState.COLLECTED:
		_sync_player_hiding_visuals(1.0)
		return
	if state == RelicState.DELIVERING or state == RelicState.DELIVERED:
		visible = true
		if _glow_light:
			_glow_light.light_energy = base_light_energy
		return

	var dim_ok := _is_active_in_dimension()
	visible = dim_ok
	if _pickup_zone:
		_pickup_zone.set_deferred("monitoring", dim_ok)
	if _glow_light:
		_glow_light.light_energy = base_light_energy if dim_ok else 0.0
	if not dim_ok:
		_set_player_registered(false)


func _on_pickup_zone_entered(body: Node3D) -> void:
	if not _is_player_node(body):
		return
	_player = body as CharacterBody3D
	_player_in_pickup_zone = true
	if can_be_collected():
		if auto_collect_on_touch:
			collect(_player)
		else:
			_set_player_registered(true)


func _on_pickup_zone_exited(body: Node3D) -> void:
	if body == _player:
		_player_in_pickup_zone = false


func _set_player_registered(registered: bool) -> void:
	if _player_registered == registered:
		return
	_player_registered = registered
	if _player and is_instance_valid(_player):
		if registered and _player.has_method("register_nearby_floating_relic"):
			_player.call("register_nearby_floating_relic", self)
		elif not registered and _player.has_method("unregister_nearby_floating_relic"):
			_player.call("unregister_nearby_floating_relic", self)


func can_be_collected() -> bool:
	return state == RelicState.IDLE_ON_PEDESTAL and _is_active_in_dimension() and _recollect_cooldown <= 0.0


func get_interact_prompt() -> String:
	return "[E] Ambil " + display_name


func _process(delta: float) -> void:
	_time_acc += delta
	if _recollect_cooldown > 0.0:
		_recollect_cooldown = maxf(_recollect_cooldown - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_resolve_player()

	match state:
		RelicState.IDLE_ON_PEDESTAL:
			_process_idle(delta)
		RelicState.COLLECTED:
			_process_follow_player(delta)
		RelicState.DELIVERED:
			_process_delivered(delta)


func _process_idle(delta: float) -> void:
	if not _is_active_in_dimension():
		_set_player_registered(false)
		return

	rotate_y(spin_speed_rad * 0.55 * delta)
	var bob := sin(_time_acc * 2.2) * 0.08 + 0.06
	global_position = _pedestal_origin + Vector3(0.0, bob, 0.0)

	if _player and is_instance_valid(_player):
		var flat_dist := Vector2(_player.global_position.x - _pedestal_origin.x, _player.global_position.z - _pedestal_origin.z).length()
		var same_floor := absf(_player.global_position.y - _pedestal_origin.y) < 3.4
		var is_near := _player_in_pickup_zone or (same_floor and flat_dist <= interact_range)
		_set_player_registered(is_near and _recollect_cooldown <= 0.0)

		if _player_in_pickup_zone and auto_collect_on_touch and _recollect_cooldown <= 0.0:
			collect(_player)


func _process_follow_player(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var target_pos := _compute_companion_target_pos()
	if global_position.distance_squared_to(target_pos) > 144.0:
		global_position = target_pos + Vector3(0.0, 0.4, 0.0)
	else:
		global_position = global_position.lerp(target_pos, clampf(follow_lerp_speed * delta, 0.0, 1.0))

	rotate_y(spin_speed_rad * delta)
	_sync_player_hiding_visuals(delta)


func _process_delivered(delta: float) -> void:
	rotate_y(spin_speed_rad * 0.7 * delta)
	global_position = _pedestal_origin + Vector3(0.0, sin(_time_acc * 2.5) * 0.06, 0.0)


func _compute_companion_target_pos() -> Vector3:
	var idx := 0
	if "floating_relics" in _player:
		var list: Variant = _player.get("floating_relics")
		if list is Array:
			idx = maxi((list as Array).find(self), 0)

	var slot_offset: Vector3
	if idx < SHOULDER_SLOTS.size():
		slot_offset = SHOULDER_SLOTS[idx]
	else:
		var angle := float(idx) * 1.15
		slot_offset = Vector3(cos(angle) * 0.65, 1.8 + float(idx % 2) * 0.25, -0.6 - sin(angle) * 0.2)

	var base_pos := _player.global_position + slot_offset
	if idx == 0:
		var anchor := _player.get_node_or_null("RelicFloatAnchor") as Marker3D
		if anchor:
			base_pos = anchor.global_position

	if "sedang_jongkok" in _player and bool(_player.get("sedang_jongkok")):
		base_pos.y -= 0.45

	var bob_y := sin(_time_acc * bob_frequency + float(idx) * 2.1) * bob_amplitude
	return base_pos + Vector3(0.0, bob_y, 0.0)


func _sync_player_hiding_visuals(delta: float) -> void:
	var in_wardrobe := _player != null and "is_in_wardrobe" in _player and bool(_player.get("is_in_wardrobe"))
	var is_hidden := _player != null and "is_hidden" in _player and bool(_player.get("is_hidden"))

	if in_wardrobe:
		visible = false
		if _glow_light:
			_glow_light.light_energy = 0.0
		return

	visible = true
	if _glow_light:
		var target_energy := hidden_light_energy if is_hidden else base_light_energy
		_glow_light.light_energy = lerpf(_glow_light.light_energy, target_energy, clampf(8.0 * delta, 0.0, 1.0))


## Mengubah status artefak menjadi COLLECTED dan mulai mengorbit di belakang bahu player.
func collect(player: CharacterBody3D) -> bool:
	if not can_be_collected() or player == null or not is_instance_valid(player):
		return false

	_player = player
	state = RelicState.COLLECTED
	_player_in_pickup_zone = false
	_set_player_registered(false)
	if _pickup_zone:
		_pickup_zone.set_deferred("monitoring", false)

	if player.has_method("add_floating_relic"):
		player.call("add_floating_relic", self)

	visible = true
	if _glow_light:
		_glow_light.light_energy = base_light_energy

	relic_collected.emit(self)
	if get_tree():
		get_tree().call_group("chapter2_puzzle_manager", "notify_relic_collected", self)
	return true


## Mengembalikan relic ke posisi spawn awalnya (dipanggil saat player terkena serangan TheEraser).
func reset_to_origin() -> void:
	if _delivery_tween and _delivery_tween.is_valid():
		_delivery_tween.kill()

	if _player and is_instance_valid(_player) and _player.has_method("remove_floating_relic"):
		_player.call("remove_floating_relic", self)

	state = RelicState.IDLE_ON_PEDESTAL
	home_dimension = _initial_home_dimension
	global_transform = _initial_transform
	_pedestal_origin = _initial_transform.origin
	_recollect_cooldown = 2.0
	_player_in_pickup_zone = false
	_set_player_registered(false)

	_resolve_world_manager()
	_apply_dimension_visibility()
	relic_reset.emit(self)


## Menerbangkan artefak secara melengkung ke titik altar socket lalu menguncinya di sana.
func deliver_to_socket(socket_world_pos: Vector3, on_arrived: Callable = Callable()) -> void:
	if state == RelicState.DELIVERING or state == RelicState.DELIVERED:
		return

	state = RelicState.DELIVERING
	_set_player_registered(false)
	if _pickup_zone:
		_pickup_zone.set_deferred("monitoring", false)

	if _player and is_instance_valid(_player) and _player.has_method("remove_floating_relic"):
		_player.call("remove_floating_relic", self)

	visible = true
	if _glow_light:
		_glow_light.light_energy = base_light_energy * 1.4

	if _delivery_tween and _delivery_tween.is_valid():
		_delivery_tween.kill()

	var start_pos := global_position
	var peak_offset := Vector3(0.0, 1.15, 0.0)
	_delivery_tween = create_tween()
	_delivery_tween.tween_method(func(t: float) -> void:
		var base_lerp := start_pos.lerp(socket_world_pos, t)
		global_position = base_lerp + peak_offset * sin(t * PI)
	, 0.0, 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_delivery_tween.tween_callback(func() -> void:
		state = RelicState.DELIVERED
		_pedestal_origin = socket_world_pos
		global_position = socket_world_pos
		if _glow_light:
			_glow_light.light_energy = base_light_energy * 1.3
		relic_delivered.emit(self)
		if get_tree():
			get_tree().call_group("chapter2_puzzle_manager", "notify_relic_delivered", self)
		if on_arrived.is_valid():
			on_arrived.call()
	)
