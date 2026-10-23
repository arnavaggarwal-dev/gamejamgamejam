extends SceneTree
## Headless logic checks. Run from the project folder:
##   "$GODOT" --headless --path . --import
##   "$GODOT" --headless --path . -s tests/test_logic.gd
## Exit code 0 = all passed.

var failures := 0


func _initialize() -> void:
	# A runtime error inside a test stops _run before quit(); the watchdog ends the process instead of hanging.
	create_timer(20.0, true, false, true).timeout.connect(_on_timeout)
	_run.call_deferred()


func _run() -> void:
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS  ", what)
	else:
		failures += 1
		printerr("FAIL  ", what)


func _on_timeout() -> void:
	printerr("TIMEOUT: a test crashed or hung")
	quit(2)
