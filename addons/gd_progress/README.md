# GDProgress

One progress window for every addon that does work when Play is pressed. It is a
single GDScript file with no binaries, and it does not need enabling in Project
Settings. Copy `addons/gd_progress/` into the project, always to that path, so
that every addon loads the same file. Newer copies replace older ones.

The first call creates one shared `GDProgress` Engine singleton. Every addon
reports to it, each under its own task name, and they share one window and one bar.

| Call | When |
|------|------|
| `add_task(task)` | In `_enter_tree()`, so the bar knows the addon is coming |
| `remove_task(task)` | In `_exit_tree()`, so a disabled addon gives back its share |
| `update(task, status, ratio)` | During `_build()`, with `ratio` from 0 to 1 |
| `finish(task)` | At the end of `_build()`, even if there was nothing to do |

A task that finishes without calling `update` gives up its share of the bar. The
window opens on the first `update` and closes on the first frame after the build,
so an addon that fails before `finish` cannot leave it open.

Calls must come from the main thread, inside `_build()`. It blocks the editor, so
`update` is what repaints the window: call it about 30 times a second.

## GDScript

```gdscript
@tool
extends EditorPlugin

func _enter_tree() -> void:
	GDProgress.add_task("My Addon")

func _exit_tree() -> void:
	GDProgress.remove_task("My Addon")

func _build() -> bool:
	for i in steps:
		GDProgress.update("My Addon", "Baking %d" % i, float(i) / steps)
		bake(i)
	GDProgress.finish("My Addon")
	return true
```

## GDExtension

Load the script by path, which also lets the addon stay optional:

```cpp
Ref<Script> gd_progress() {
	const char *path = "res://addons/gd_progress/gd_progress.gd";
	ResourceLoader *loader = ResourceLoader::get_singleton();
	return loader->exists(path) ? Ref<Script>(loader->load(path)) : Ref<Script>();
}

Ref<Script> progress = gd_progress();
if (progress.is_valid()) {
	progress->call("update", "My Addon", "Baking", 0.5);
}
```
