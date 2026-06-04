extends RefCounted


static func expect(condition: bool, failures: Array[String], message: String) -> void:
	if not condition:
		failures.append(message)


static func expect_equal(actual: Variant, expected: Variant, failures: Array[String], message: String) -> void:
	if actual != expected:
		failures.append("%s (got %s, expected %s)" % [message, str(actual), str(expected)])


static func expect_close(actual: float, expected: float, failures: Array[String], message: String, epsilon: float = 0.0001) -> void:
	if abs(actual - expected) > epsilon:
		failures.append("%s (got %.4f, expected %.4f)" % [message, actual, expected])
