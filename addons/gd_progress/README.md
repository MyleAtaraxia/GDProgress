# GDProgress

One progress window for every addon that does work when Play is pressed. It is a
single GDScript file with no binaries, and it does not need enabling in Project
Settings. Each addon brings its own copy of `gd_progress.gd`, anywhere inside its
own folder. Copy only that file, because a shared `.uid` makes Godot warn.

The newest copy in the project creates one `GDProgress` Engine singleton, which
runs the window. Older copies report to it, each addon under its own task name,
so they all share one window and one bar. Do not add a `class_name`: two scanned
copies would stop each other from loading.

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

const GDProgress := preload("gd_progress.gd")

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
	const char *path = "res://addons/my_addon/gd_progress.gd";
	ResourceLoader *loader = ResourceLoader::get_singleton();
	return loader->exists(path) ? Ref<Script>(loader->load(path)) : Ref<Script>();
}

Ref<Script> progress = gd_progress();
if (progress.is_valid()) {
	progress->call("update", "My Addon", "Baking", 0.5);
}
```

## Changing the script

Raise `VERSION` in every release. Older copies call the members listed at the top
of the script, so those can only gain optional arguments, never change.
