class_name ErrorCatcher
extends Logger
## Counts script errors raised while a test runs, so a test can fail on them.
##
## A GDScript runtime error only aborts the function it happens in; the game carries on, and a
## test that checks state afterwards can pass over a real crash (in the editor that same error
## halts the game). This is how "dying in the Netherecho crashes" and "ascending stops half-way"
## both got past the self-test. Usage:
##   var errors := ErrorCatcher.install()
##   ... run the test ...
##   if errors.count() > 0: fail
## Engine shutdown noise (leaked RIDs and the like) is reported as errors too, so read count()
## before quitting.

var _mutex := Mutex.new()
var _count := 0
var _first := ""


static func install() -> ErrorCatcher:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	return catcher


## May be called from any thread.
func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	_count += 1
	if _first == "":
		_first = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]
	_mutex.unlock()


func count() -> int:
	_mutex.lock()
	var n: int = _count
	_mutex.unlock()
	return n


## The first error seen, for the failure message.
func first() -> String:
	_mutex.lock()
	var s: String = _first
	_mutex.unlock()
	return s
