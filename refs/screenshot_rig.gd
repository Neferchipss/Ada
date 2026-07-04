extends Node
## Generic headless screenshot rig for Godot 4 projects.
##
## Loads a target scene, places a camera at a list of named spots defined in a
## JSON spec, waits for each frame to settle, and saves a PNG per shot.
##
## IMPORTANT: do NOT use --headless. On Windows (and most platforms), the
## "headless" display driver only supports the "dummy" (no-GPU) rendering
## driver, so get_viewport().get_texture() comes back null and every capture
## silently fails. Run with a real rendering driver instead — this briefly
## opens an actual window while it captures, which is fine for local iteration:
##
##   godot --rendering-driver d3d12 res://tools/screenshot_rig.tscn -- --spec=res://tools/screenshots.json
##
## (swap d3d12 for vulkan/opengl3 to match your platform's default driver;
## check your project's [rendering] section in project.godot, or just omit
## the flag entirely and let Godot pick its own default.)
## (falls back to res://tools/screenshots.json if --spec is omitted)
##
## Spec JSON shape — see tools/screenshots.json in this project for a worked example:
## {
##   "scene": "res://scenes/maps/bazaar_loop.tscn",
##   "output_dir": "res://docs/screenshots/after",
##   "width": 1920, "height": 1080,
##   "initial_settle_frames": 30,
##   "default_settle_frames": 20,
##   "shots": [
##     { "name": "marine_drive", "position": [-210,4,60], "look_at": [-210,3,-40], "fov": 70 },
##     { "name": "flyover", "position": [30,3,20], "rotation_deg": [-10,-70,0] },
##     { "name": "car_chase",
##       "spawn_scene": "res://scenes/car_prototype.tscn",
##       "spawn_position": [-85,1,3], "spawn_rotation_deg": [0,-90,0],
##       "focus_offset": [0,3,-6], "focus_look_at_offset": [0,1,2],
##       "input_hold": { "accelerate": 1.5 }, "settle_frames": 40 }
##   ]
## }
##
## Field notes:
## - position + (look_at OR rotation_deg): a static camera placement.
## - spawn_scene: instantiate a scene, place it, then aim the camera at IT via
##   focus_offset/focus_look_at_offset (both relative to the spawned node's basis) —
##   this is how you get an in-motion gameplay/vehicle shot in any project without
##   the rig knowing anything about your game's classes.
## - focus_path: NodePath string, alternative to spawn_scene — aims at an existing
##   node already in the loaded scene (e.g. a specific building or NPC).
## - input_hold: { action_name: seconds } — held via Input.action_press before the
##   settle wait, so a vehicle can be rolling/leaning when the shot is taken.
##   Unknown action names are ignored (portable across projects with different input maps).
## - settle_frames: per-shot override of default_settle_frames.
## - output: optional filename override (else "<name>.png" under output_dir).

const DEFAULT_SPEC_PATH := "res://tools/screenshots.json"

enum State { LOADING, SHOOTING, DONE }

var _state: State = State.LOADING
var _frame := 0
var _spec: Dictionary = {}
var _shots: Array = []
var _shot_index := -1
var _shot_frame := 0
var _shot_active := false
var _held_actions: Array[String] = []
var _camera: Camera3D
var _target_root: Node
var _spawned: Dictionary = {} # shot_index -> Node

func _ready() -> void:
	var spec_path := _read_spec_arg()
	if not FileAccess.file_exists(spec_path):
		push_error("[screenshot_rig] spec file not found: %s" % spec_path)
		get_tree().quit(1)
		return

	var text := FileAccess.get_file_as_string(spec_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[screenshot_rig] spec is not valid JSON: %s" % spec_path)
		get_tree().quit(1)
		return
	_spec = parsed
	_shots = _spec.get("shots", [])
	if _shots.is_empty():
		push_error("[screenshot_rig] spec has no shots")
		get_tree().quit(1)
		return

	var w: int = int(_spec.get("width", 1920))
	var h: int = int(_spec.get("height", 1080))
	get_window().size = Vector2i(w, h)

	var scene_path: String = _spec.get("scene", "")
	if scene_path != "":
		var packed: PackedScene = load(scene_path)
		if packed == null:
			push_error("[screenshot_rig] could not load scene: %s" % scene_path)
			get_tree().quit(1)
			return
		_target_root = packed.instantiate()
		add_child(_target_root)
	else:
		_target_root = self

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true

	print("[screenshot_rig] loaded scene=%s shots=%d output=%s" % [
		scene_path, _shots.size(), _spec.get("output_dir", "res://screenshots")])

func _read_spec_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spec="):
			return arg.substr("--spec=".length())
	return DEFAULT_SPEC_PATH

func _physics_process(_delta: float) -> void:
	_frame += 1
	match _state:
		State.LOADING:
			var settle: int = int(_spec.get("initial_settle_frames", 30))
			if _frame >= settle:
				_state = State.SHOOTING
		State.SHOOTING:
			_process_shot()
		State.DONE:
			pass

func _process_shot() -> void:
	if not _shot_active:
		_shot_index += 1
		if _shot_index >= _shots.size():
			print("[screenshot_rig] ALL %d SHOTS SAVED" % _shots.size())
			get_tree().quit(0)
			return
		_setup_shot(_shots[_shot_index])
		_shot_frame = 0
		_shot_active = true
		return

	_shot_frame += 1
	var shot: Dictionary = _shots[_shot_index]
	var settle: int = int(shot.get("settle_frames", _spec.get("default_settle_frames", 20)))

	# Release held inputs once their duration (in frames, approximated at 60fps physics) elapses.
	var hold: Dictionary = shot.get("input_hold", {})
	for action_name in hold.keys():
		var frames_needed: int = int(float(hold[action_name]) * Engine.physics_ticks_per_second)
		if _shot_frame == frames_needed and InputMap.has_action(action_name):
			Input.action_release(action_name)

	if _shot_frame >= settle:
		_capture_shot(shot)
		_shot_active = false

func _setup_shot(shot: Dictionary) -> void:
	var focus_node: Node3D = null

	if shot.has("spawn_scene"):
		var packed: PackedScene = load(String(shot["spawn_scene"]))
		if packed:
			var inst: Node3D = packed.instantiate()
			_target_root.add_child(inst)
			var pos: Array = shot.get("spawn_position", [0, 1, 0])
			inst.global_position = Vector3(pos[0], pos[1], pos[2])
			var rot: Array = shot.get("spawn_rotation_deg", [0, 0, 0])
			inst.rotation_degrees = Vector3(rot[0], rot[1], rot[2])
			_spawned[_shot_index] = inst
			focus_node = inst
	elif shot.has("focus_path"):
		var node = _target_root.get_node_or_null(NodePath(String(shot["focus_path"])))
		if node is Node3D:
			focus_node = node

	if focus_node:
		var off: Array = shot.get("focus_offset", [0, 3, -6])
		var look_off: Array = shot.get("focus_look_at_offset", [0, 1, 2])
		var offset := Vector3(off[0], off[1], off[2])
		var look_offset := Vector3(look_off[0], look_off[1], look_off[2])
		var yaw := Basis(Vector3.UP, focus_node.global_transform.basis.get_euler().y)
		_camera.global_position = focus_node.global_position + yaw * offset
		_camera.look_at(focus_node.global_position + yaw * look_offset, Vector3.UP)
	else:
		var pos: Array = shot.get("position", [0, 5, 10])
		_camera.global_position = Vector3(pos[0], pos[1], pos[2])
		if shot.has("look_at"):
			var la: Array = shot["look_at"]
			_camera.look_at(Vector3(la[0], la[1], la[2]), Vector3.UP)
		elif shot.has("rotation_deg"):
			var r: Array = shot["rotation_deg"]
			_camera.rotation_degrees = Vector3(r[0], r[1], r[2])

	_camera.fov = float(shot.get("fov", 70.0))

	var hold: Dictionary = shot.get("input_hold", {})
	for action_name in hold.keys():
		if InputMap.has_action(action_name):
			Input.action_press(action_name, 1.0)

	print("[screenshot_rig] shot %d/%d '%s' — settling" % [
		_shot_index + 1, _shots.size(), shot.get("name", "shot%d" % _shot_index)])

func _capture_shot(shot: Dictionary) -> void:
	var img := get_viewport().get_texture().get_image()
	var out_dir: String = _spec.get("output_dir", "res://screenshots")
	var name: String = shot.get("name", "shot%d" % _shot_index)
	var filename: String = shot.get("output", name + ".png")
	var full_path: String = out_dir.path_join(filename)
	var abs_path: String = ProjectSettings.globalize_path(full_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	print("[screenshot_rig] shot %d/%d '%s' -> %s (%s)" % [
		_shot_index + 1, _shots.size(), name, abs_path,
		"OK" if err == OK else "FAILED err=%d" % err])
