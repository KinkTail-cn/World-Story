extends SceneTree

const Definition = preload("res://scripts/character/CharacterDefinition.gd")
const Creator = preload("res://scripts/ui/CharacterCreator.gd")
var checks: int = 0
var failures: int = 0
var timings: Dictionary = {}

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("CHARACTER_EDIT_PERFORMANCE_TIMEOUT"); quit(1))
	_run.call_deferred()

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func frames(count: int = 3) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var editor = Creator.new()
	root.add_child(editor)
	var model := Definition.new_model("编辑性能测试")
	var equipment: Array[int] = [0,0,0,0,0,0,0]
	editor.open(model,equipment,[])
	await frames()
	var session = editor.edit_session
	var mesh_ids := instance_resources(editor)
	var before_count: int = session.model.cubes.size()
	var head: Vector3 = Definition.rest_origins(session.model).head
	var point: Vector2 = editor.camera.unproject_position(editor.preview_character.global_transform * (head+Vector3(0,0,-0.225))) * editor.preview.size / Vector2(editor.viewport.size)
	var samples: Array[float] = []
	for i in range(8):
		var started := Time.get_ticks_usec()
		click(editor.preview.get_global_transform()*point)
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
		await frames(1)
	check(session.model.cubes.size() == before_count+8,"Repeated real preview clicks each add a cube")
	check(instance_resources(editor) == mesh_ids,"Adding cubes keeps the existing joint render resources alive")
	record_timing("real_click",samples)
	check(float(timings.real_click.median_ms) < 100.0,"Normal building no longer blocks input for hundreds of milliseconds")
	var added: String = session.selection[0]
	var cube: Dictionary = session.model.cubes[session.find(added)]
	check(render_matches(editor,cube),"New cube is immediately present in the actual preview renderer")
	check(session.undo_stack.back().kind == "cubes" and session.undo_stack.back().patches.size() == 1,"A one-cube edit records only its changed data")
	samples.clear()
	for i in range(12):
		var started := Time.get_ticks_usec()
		session.set_properties({"color":"dc6688" if i%2 == 0 else "5599dd"})
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	record_timing("paint",samples)
	check(render_matches(editor,session.model.cubes[session.find(added)]),"Incremental painting updates the displayed color")
	check(instance_resources(editor) == mesh_ids,"Painting does not recreate unrelated body meshes")
	var original: Dictionary = session.model.cubes[session.find(added)].duplicate(true)
	var history_size: int = session.undo_stack.size()
	var drag_state: Dictionary = session.begin_translation()
	samples.clear()
	for i in range(20):
		var started := Time.get_ticks_usec()
		session.preview_patch_translation(drag_state,Vector3.RIGHT*0.005*float(i+1))
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	check(session.undo_stack.size() == history_size,"Drag preview does not append history on every mouse movement")
	check(render_matches(editor,session.model.cubes[session.find(added)]),"Dragging updates the actual instance transform immediately")
	record_timing("drag",samples)
	check(float(timings.drag.median_ms) < 50.0,"Continuous drag updates stay below the former full-rebuild delay")
	check(session.commit_translation(drag_state) and session.undo_stack.size() == history_size+1,"A whole drag commits as one transaction")
	check(session.undo() and session.model.cubes[session.find(added)] == original,"Undo restores an entire incremental drag exactly")
	check(session.redo() and render_matches(editor,session.model.cubes[session.find(added)]),"Redo restores both data and the displayed instance")
	check(session.set_properties({"hidden":true}),"A cube can be hidden incrementally")
	check(render_matches(editor,session.model.cubes[session.find(added)]),"Hidden edit cubes no longer draw geometry")
	check(session.set_properties({"hidden":false,"bone":"left_hand"}),"A cube can be rebound and shown in the same transaction")
	check(str(editor.preview_character._edit_mesh.locations[added].bone) == "left_hand" and render_matches(editor,session.model.cubes[session.find(added)]),"Rebinding removes the old instance and creates the new joint attachment")
	check(session.erase_selected() and not editor.preview_character._edit_mesh.locations.has(added),"Deletion removes the live instance")
	check(session.undo() and render_matches(editor,session.model.cubes[session.find(added)]),"Deleted instances return correctly through undo")
	# Removing several nonadjacent items exercises index shifts and the
	# renderer's swap removal, including selection and list restoration.
	var selected: Array = [session.model.cubes[0].id,session.model.cubes[5].id,session.model.cubes[20].id]
	var before: Dictionary = session.model.duplicate(true)
	session.select(selected)
	check(session.erase_selected() and session.model.cubes.size() == before.cubes.size()-3,"A batch deletion handles nonadjacent source indices")
	check(session.undo() and session.model == before,"Batch undo restores source order and exact model data")
	for id in selected:
		check(render_matches(editor,session.model.cubes[session.find(str(id))]),"Restored cube retains its correct instance slot")
	# A genuine reshape must materialize the latest sculpted reference. Check
	# mixed patch/snapshot history in both directions, not just plain cubes.
	session.select([added])
	before = session.model.duplicate(true)
	check(session.set_parameter("body_width",1.1),"Body reshaping still accepts accumulated incremental edits")
	check(session.undo() and session.model == before,"Undo crosses from full reshape history back to the sculpted model")
	check(session.redo() and session.undo() and session.model == before,"Mixed history remains repeatable in both directions")
	var before_drag: PackedByteArray = session.snapshot()
	drag_state = session.begin_translation()
	session.preview_patch_translation(drag_state,Vector3.RIGHT*0.2)
	session.cancel_translation(drag_state)
	check(session.snapshot() == before_drag,"Cancelling a drag restores geometry, selection and the reshape reference")
	drag_state = session.begin_translation()
	session.preview_patch_translation(drag_state,Vector3.ZERO)
	check(not session.commit_translation(drag_state) and session.snapshot() == before_drag,"A zero-distance drag adds no history and changes no reference state")
	var before_growth: Dictionary = session.model.duplicate(true)
	for i in range(40):
		session.add("neck",Vector3(float(i)*0.006,0,0.1),0.005,Color("c5a57b"))
	var neck: Dictionary = editor.preview_character._edit_mesh.groups.neck
	check(neck.node.multimesh.instance_count >= 40,"Instance storage grows when a bone exceeds its initial capacity")
	var all_neck_cubes := true
	for neck_cube in session.model.cubes:
		if neck_cube.bone == "neck":
			all_neck_cubes = all_neck_cubes and render_matches(editor,neck_cube)
	check(all_neck_cubes,"Growing instance capacity retains earlier cube transforms and colors")
	for i in range(40):
		session.undo()
	check(session.model == before_growth,"A run of incremental additions can be undone after capacity growth")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Qi/AppData/Local/Temp/opencode/character-edit-performance.png")
	var large := model.duplicate(true)
	var index := 0
	while large.cubes.size() < 16000:
		var copy: Dictionary = model.cubes[index%model.cubes.size()].duplicate(true)
		copy.id = "stress_%d" % index
		large.cubes.append(copy)
		index += 1
	editor._bind(large)
	await frames()
	mesh_ids = instance_resources(editor)
	samples.clear()
	for i in range(12):
		var started := Time.get_ticks_usec()
		session.add("head",Vector3(0.25+0.01*i,0,0),0.0325,Color("73abb5"))
		samples.append(float(Time.get_ticks_usec()-started)/1000.0)
	record_timing("add_16000_cubes",samples)
	check(session.model.cubes.size() == 16012 and instance_resources(editor) == mesh_ids,"A near-limit model also builds without replacing unrelated render resources")
	check(float(timings.add_16000_cubes.median_ms) < 100.0,"Near-limit single-cube additions avoid whole-character rebuilds")
	check(Definition.validation_error(session.model).is_empty(),"Incremental output still passes complete save-time model validation")
	editor.queue_free()
	await frames()
	print("CHARACTER_EDIT_TIMINGS: ",JSON.stringify(timings))
	print("CHARACTER_EDIT_PERFORMANCE_PASS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func record_timing(label: String, samples: Array[float]) -> void:
	samples.sort()
	timings[label] = {"median_ms":snappedf(samples[samples.size()/2],0.001),"max_ms":snappedf(samples.back(),0.001),"samples":samples.size()}

func instance_resources(editor) -> Dictionary:
	var result := {}
	for bone in editor.preview_character._edit_mesh.groups:
		var group: Dictionary = editor.preview_character._edit_mesh.groups[bone]
		result[bone] = [group.node.get_instance_id(),group.node.multimesh.get_instance_id()]
	return result

func render_matches(editor, cube: Dictionary) -> bool:
	var renderer = editor.preview_character._edit_mesh
	if not renderer.locations.has(cube.id):
		return false
	var location: Dictionary = renderer.locations[cube.id]
	var mesh: MultiMesh = renderer.groups[location.bone].node.multimesh
	var transform: Transform3D = renderer._values[cube.id].transform if DisplayServer.get_name() == "headless" else mesh.get_instance_transform(int(location.index))
	var edge := 0.0 if cube.get("hidden",false) else float(cube.edge)
	# GL Compatibility stores instance colors as half floats. Keep the saved
	# model exact and compare the GPU value at its actual storage precision.
	# The headless dummy server does not retain instance buffers. It verifies
	# the submitted renderer state; the OpenGL run reads the actual GPU buffer.
	var actual: Color = renderer._values[cube.id].color if DisplayServer.get_name() == "headless" else mesh.get_instance_color(int(location.index))
	var expected := Color(cube.color)
	var color_matches := maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b))) < 0.001
	return str(location.bone) == str(cube.bone) and transform.origin.is_equal_approx(Definition.vector(cube.center)) and transform.basis.get_scale().is_equal_approx(Vector3.ONE*edge) and color_matches

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
