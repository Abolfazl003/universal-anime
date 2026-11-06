extends RefCounted
## Validates character records without mutating them.
## Producing a report is mandatory: missing fields are reported, never invented.

const Consts = preload("res://scripts/core/constants.gd")

var errors: Array[String] = []
var warnings: Array[String] = []
var duplicate_ids: Array[int] = []
var duplicate_names: Array[String] = []
var incomplete_ids: Array[int] = []


func _reset() -> void:
	errors.clear()
	warnings.clear()
	duplicate_ids.clear()
	duplicate_names.clear()
	incomplete_ids.clear()


## Validates an array of raw dictionaries (as parsed from JSON).
## Returns a report dictionary that is safe to log and display in UI.
func validate(records: Array) -> Dictionary:
	_reset()
	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var status_counts: Dictionary = {}
	var series_set: Dictionary = {}
	var valid_count: int = 0
	var total: int = records.size()

	for index in range(records.size()):
		var raw: Variant = records[index]
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("Record #%d is not an object." % index)
			continue
		var record: Dictionary = raw
		var rec_id: int = int(record.get("id", -1))
		if not record.has("id"):
			errors.append("Record #%d has no 'id'." % index)
		elif rec_id < 0:
			errors.append("Record #%d has a non-numeric or negative id (%s)." % [index, str(record.get("id"))])

		var duplicate_id: bool = false
		if seen_ids.has(rec_id):
			duplicate_id = true
			duplicate_ids.append(rec_id)
			errors.append("Duplicate id %d (records #%d and #%d)." % [rec_id, seen_ids[rec_id], index])
		else:
			seen_ids[rec_id] = index

		var cname: String = str(record.get("name", "")).strip_edges()
		if cname.is_empty():
			errors.append("Record id %d has an empty 'name'." % rec_id)
		else:
			var key: String = cname.to_lower()
			if seen_names.has(key):
				duplicate_names.append(cname)
				warnings.append("Duplicate character name '%s' (ids %d and %d)." % [cname, seen_names[key], rec_id])
			else:
				seen_names[key] = rec_id

		var missing: Array[String] = []
		for field in Consts.CHARACTER_REQUIRED_FIELDS:
			if not record.has(field) or record[field] == null:
				missing.append(field)
		# Empty collections are as unusable as missing ones.
		if record.has("powers"):
			var powers_value: Variant = record.get("powers")
			if typeof(powers_value) != TYPE_ARRAY or (powers_value as Array).is_empty():
				if not missing.has("powers"):
					missing.append("powers")
		if not missing.is_empty():
			incomplete_ids.append(rec_id)
			errors.append("Record id %d ('%s') is incomplete, missing: %s" % [rec_id, cname, ", ".join(missing)])
		elif not duplicate_id:
			# A structurally complete record that collides with another id can never
			# be imported, so it does not count towards the usable roster.
			valid_count += 1

		var status_name: String = str(record.get("status", Consts.STATUS_NAMES[Consts.Status.DATA_ONLY]))
		if not Consts.STATUS_NAMES.values().has(status_name):
			warnings.append("Record id %d has unknown status '%s'; treated as DATA_ONLY." % [rec_id, status_name])
			status_name = Consts.STATUS_NAMES[Consts.Status.DATA_ONLY]
		status_counts[status_name] = int(status_counts.get(status_name, 0)) + 1

		var series_name: String = str(record.get("series", "")).strip_edges()
		if not series_name.is_empty():
			series_set[series_name] = true

	return {
		"total_records": total,
		"valid_records": valid_count,
		"distinct_series": series_set.size(),
		"series": series_set.keys(),
		"status_counts": status_counts,
		"duplicate_ids": duplicate_ids,
		"duplicate_names": duplicate_names,
		"incomplete_ids": incomplete_ids,
		"errors": errors,
		"warnings": warnings,
		"ok": errors.is_empty(),
	}


## Normalizes one record into the in-memory shape used by the UI.
## The original values (name, series, city, power names/descriptions) are copied
## verbatim; nothing is renamed or translated. Absent fields remain empty.
func normalize(record: Dictionary) -> Dictionary:
	var status_name: String = str(record.get("status", Consts.STATUS_NAMES[Consts.Status.DATA_ONLY]))
	var status_value: int = Consts.Status.DATA_ONLY
	for key in Consts.STATUS_NAMES.keys():
		if Consts.STATUS_NAMES[key] == status_name:
			status_value = int(key)
			break

	var powers: Array = []
	var raw_powers: Variant = record.get("powers", [])
	if typeof(raw_powers) == TYPE_ARRAY:
		for power in raw_powers:
			if typeof(power) == TYPE_DICTIONARY:
				powers.append({
					"name": str((power as Dictionary).get("name", "")),
					"description": str((power as Dictionary).get("description", "")),
				})
			else:
				# Some sources store powers as bare strings. Keep them as names
				# with an empty description instead of dropping information.
				powers.append({"name": str(power), "description": ""})

	return {
		"id": int(record.get("id", -1)),
		"name": str(record.get("name", "")),
		"series": str(record.get("series", "")),
		"city": str(record.get("city", "")),
		"element": str(record.get("element", Consts.UNKNOWN_LABEL)),
		"role": str(record.get("role", Consts.UNKNOWN_LABEL)),
		"rarity": str(record.get("rarity", Consts.UNKNOWN_LABEL)),
		"powers": powers,
		"status": status_value,
		"status_name": Consts.STATUS_NAMES[status_value],
		"has_world": record.has("world") and not str(record.get("world", "")).is_empty(),
		"world": str(record.get("world", "")),
		"architecture": str(record.get("architecture", "")),
		"description": str(record.get("description", "")),
		"raw": record,
	}
