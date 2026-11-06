extends RefCounted
## Minimal assertion + reporting helper for the headless test run.

var passed: int = 0
var failed: int = 0
var lines: Array[String] = []
var tree: SceneTree = null
var current_suite: String = ""


func _init(p_tree: SceneTree = null) -> void:
	tree = p_tree


func suite(name: String) -> void:
	current_suite = name
	print("\n[%s]" % name)


func ok(test_name: String, condition: bool, detail: String = "") -> bool:
	if condition:
		passed += 1
		print("  PASS  %s" % test_name)
	else:
		failed += 1
		print("  FAIL  %s%s" % [test_name, ("  -> " + detail) if not detail.is_empty() else ""])
	lines.append("%s | %s | %s" % [current_suite, "PASS" if condition else "FAIL", test_name])
	return condition


func eq(test_name: String, actual: Variant, expected: Variant) -> bool:
	var equal: bool = actual == expected
	return ok(test_name, equal, "expected %s, got %s" % [str(expected), str(actual)])


func close(test_name: String, actual: float, expected: float, epsilon: float = 0.01) -> bool:
	var equal: bool = absf(actual - expected) <= epsilon
	return ok(test_name, equal, "expected %.3f ± %.3f, got %.3f" % [expected, epsilon, actual])


func between(test_name: String, actual: float, minimum: float, maximum: float) -> bool:
	var inside: bool = actual >= minimum and actual <= maximum
	return ok(test_name, inside, "expected %s..%s, got %s" % [str(minimum), str(maximum), str(actual)])


func not_empty(test_name: String, value: Variant) -> bool:
	var empty: bool = false
	match typeof(value):
		TYPE_STRING:
			empty = str(value).is_empty()
		TYPE_ARRAY:
			empty = (value as Array).is_empty()
		TYPE_DICTIONARY:
			empty = (value as Dictionary).is_empty()
		TYPE_NIL:
			empty = true
		_:
			empty = false
	return ok(test_name, not empty, "value is empty")


## Waits an exact number of simulation ticks.
func wait_ticks(count: int) -> void:
	if tree == null:
		return
	for _i in range(maxi(1, count)):
		await tree.physics_frame


func print_summary() -> void:
	print("\n---------------------------------------------")
	print("PASSED: %d   FAILED: %d   TOTAL: %d" % [passed, failed, passed + failed])
	print("---------------------------------------------")
