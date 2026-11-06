extends Node
## Headless test runner.
##
##   godot --headless --path . res://tests/test_runner.tscn
##
## Exits with code 0 when every check passes and 1 otherwise, so CI or a shell
## script can gate on it.

const TestContext = preload("res://tests/test_context.gd")
const SUITES: Array = [
	preload("res://tests/test_data.gd"),
	preload("res://tests/test_combat.gd"),
	preload("res://tests/test_dungeon.gd"),
	preload("res://tests/test_ui_save.gd"),
]


func _ready() -> void:
	await get_tree().process_frame
	print("=== ANIME SAGA — headless test run ===")
	print("engine: %s" % Engine.get_version_info().get("string", "?"))
	print("display: %s" % DisplayServer.get_name())
	print("characters loaded: %d" % GameData.characters.size())
	var ctx := TestContext.new(get_tree())
	for suite_script in SUITES:
		var suite = suite_script.new()
		await suite.run(ctx)
	ctx.print_summary()
	var failed: int = ctx.failed
	if failed > 0:
		print("RESULT: FAILED")
	else:
		print("RESULT: PASSED")
	# Give queued frees a frame so shutdown stays clean.
	await get_tree().process_frame
	get_tree().quit(0 if failed == 0 else 1)
