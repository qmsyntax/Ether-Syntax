class_name UserDirMigration
extends RefCounted
## The game was renamed from "Passage" to "Ether Syntax" (Brent 2026-10-22), and user:// now lives in a folder
## of its own ("custom_user_dir_name" in project.godot). Saves and key bindings made under the old name sat in
## Godot's app_userdata folder for "Passage (prototype)". On the first run under the new name, copy them across.
## The old folder is left where it is, as a backup.

const OLD_FOLDER := "Godot/app_userdata/Passage (prototype)"
const DONE_FLAG := "user://.migrated_from_passage"


static func run() -> void:
	if FileAccess.file_exists(DONE_FLAG):
		return
	var appdata: String = OS.get_environment("APPDATA")
	if appdata == "":
		return
	var old_root: String = appdata.path_join(OLD_FOLDER)
	if DirAccess.dir_exists_absolute(old_root) and DirAccess.get_files_at("user://").is_empty():
		_copy_dir(old_root, OS.get_user_data_dir())
	var f := FileAccess.open(DONE_FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string("copied from %s\n" % old_root)


static func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for name: String in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(name), to.path_join(name))
	for sub: String in DirAccess.get_directories_at(from):
		if sub == "shader_cache" or sub == "vulkan" or sub == "logs":
			continue
		_copy_dir(from.path_join(sub), to.path_join(sub))
