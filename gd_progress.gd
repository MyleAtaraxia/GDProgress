@tool
extends Node

# The newest copy in a project runs the window. The release workflow stamps this from the tag and commits it to master, so do not edit it by hand.
# The members marked below are called by older copies, so never rename them or change their arguments.
const VERSION := 1000000
const SKIPPED := -1.0
const SINGLETON := "GDProgress"
const SELF := preload("gd_progress.gd")

# Called by other copies: version, tasks, _add, _remove, _update, _finish.
var version := VERSION
var tasks := {}
var active := ""
var window: Window
var canvas: Control
var font: Font
var font_size := 16
var ui_scale := 1.0
var base: Color
var accent: Color
var text: Color
var muted: Color
var started_at := 0


static func add_task(task: String) -> void:
	_shared()._add(task)


static func remove_task(task: String) -> void:
	if Engine.has_singleton(SINGLETON):
		Engine.get_singleton(SINGLETON)._remove(task)


static func update(task: String, status: String, ratio: float) -> void:
	if DisplayServer.get_name() != "headless":
		_shared()._update(task, status, ratio)


static func finish(task: String) -> void:
	if DisplayServer.get_name() != "headless":
		_shared()._finish(task)


static func overall(shares: Dictionary) -> float:
	var total := 0.0
	var counted := 0
	for share: float in shares.values():
		if share != SKIPPED:
			total += share
			counted += 1
	return total / counted if counted else 1.0


static func _shared() -> Node:
	var current: Node = Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null
	if current and current.version >= VERSION:
		return current
	var shared := SELF.new()
	shared.name = SINGLETON
	if current:
		shared.tasks = current.tasks
		current.free()
	Engine.register_singleton(SINGLETON, shared)
	EditorInterface.get_base_control().add_child(shared)
	return shared


func _exit_tree() -> void:
	Engine.unregister_singleton(SINGLETON)
	if window:
		window.queue_free()


func _add(task: String) -> void:
	tasks[task] = 0.0


func _remove(task: String) -> void:
	tasks.erase(task)


func _update(task: String, status: String, ratio: float) -> void:
	active = task
	tasks[task] = clampf(ratio, 0.0, 1.0)
	if not window:
		_open()
		_end_run.call_deferred()
	_draw_window(status)


func _finish(task: String) -> void:
	tasks[task] = 1.0 if task == active else SKIPPED
	active = ""
	_end_run.call_deferred()


# shortcut: a run ends at the first frame after _build, so work spread over frames reopens the window each time, track a run explicitly if an addon needs that.
# Ending on the frame also closes the window when an addon fails before calling finish, which would otherwise lock the editor.
func _end_run() -> void:
	active = ""
	for task: String in tasks:
		tasks[task] = 0.0
	if window:
		window.hide()
		window.queue_free()
		window = null


func _open() -> void:
	var editor := EditorInterface.get_editor_theme()
	ui_scale = EditorInterface.get_editor_scale()
	font = editor.get_font("main", "EditorFonts")
	font_size = editor.get_font_size("main_size", "EditorFonts")
	base = editor.get_color("base_color", "Editor")
	accent = editor.get_color("accent_color", "Editor")
	text = editor.get_color("font_color", "Editor")
	muted = editor.get_color("font_placeholder_color", "Editor")
	started_at = Time.get_ticks_msec()
	window = Window.new()
	window.title = "Build"
	window.unresizable = true
	canvas = Control.new()
	window.add_child(canvas)
	window.popup_exclusive_centered(EditorInterface.get_base_control(), Vector2i(Vector2(460, 112) * ui_scale))


# _build blocks the main thread, so the window never gets a frame of its own and has to draw itself.
func _draw_window(status: String) -> void:
	var item := canvas.get_canvas_item()
	var size := Vector2(window.size)
	var pad := 16 * ui_scale
	var line := font_size * 1.5
	var width := size.x - pad * 2
	var seconds := (Time.get_ticks_msec() - started_at) / 1000
	RenderingServer.canvas_item_clear(item)
	RenderingServer.canvas_item_add_rect(item, Rect2(Vector2(), size), base)
	font.draw_string(item, Vector2(pad, pad + font_size), active, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, text)
	font.draw_string(item, Vector2(pad, pad + font_size), "%d s" % seconds, HORIZONTAL_ALIGNMENT_RIGHT, width, font_size, muted)
	font.draw_string(item, Vector2(pad, pad + font_size + line), status, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, muted)
	var bar := Rect2(pad, size.y - pad - 8 * ui_scale, width, 8 * ui_scale)
	RenderingServer.canvas_item_add_rect(item, bar, Color(text, 0.15))
	RenderingServer.canvas_item_add_rect(item, Rect2(bar.position, Vector2(bar.size.x * overall(tasks), bar.size.y)), accent)
	DisplayServer.process_events()
	RenderingServer.force_draw()
