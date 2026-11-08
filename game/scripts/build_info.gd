class_name BuildInfo
extends RefCounted
## Which build this is. The stamp is `application/config/version` in project.godot, written by
## `tools/release/stamp_version.sh <tag> <sha>` just before a release is tagged: the release number and the
## short sha of the commit it was cut from, "0.55.0+4959094" (semver build metadata). Saves record the raw
## stamp (`stamp()`); the title and the game menu show `label()`. A project file without a stamp reads "dev".


## The whole stamp as written in project.godot ("0.55.0+4959094"), or "dev" when there is none.
static func stamp() -> String:
	var v: String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return v if v != "" else "dev"


## The release number alone ("0.55.0"), or "dev".
static func version() -> String:
	return stamp().get_slice("+", 0)


## The short sha the release was cut from ("4959094"), or "" when the stamp carries none.
static func sha() -> String:
	var s: String = stamp()
	return s.get_slice("+", 1) if s.contains("+") else ""


## What the player sees: "v0.55.0 (4959094)", or "dev build".
static func label() -> String:
	if stamp() == "dev":
		return "dev build"
	var s: String = sha()
	return "v%s (%s)" % [version(), s] if s != "" else "v%s" % version()
