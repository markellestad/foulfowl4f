extends GutTest

const FORBIDDEN_PACKS: Array[String] = [
	"SCI-FI_UI_SFX_PACK",
	"Sci-Fi Combat Systems",
	"Explosion SFX Pack",
	"Shapeforms"
]

func check_open_source(source_path: String) -> bool:
	for f in FORBIDDEN_PACKS:
		if source_path.to_lower().contains(f.to_lower()):
			return false
	return true

func test_checker_refuse_and_allow() -> void:
	assert_false(check_open_source("SCI-FI_UI_SFX_PACK/x.wav"), "Refuses licensed pack path")
	assert_true(check_open_source("kenney_interface-sounds/Audio/click_001.ogg"), "Allows open Kenney path")

func test_audio_json_slots() -> void:
	var errs: Array[String] = []
	var data: Variant = DefLoader.load_json("res://data/audio.json", errs)
	assert_not_null(data)
	assert_true(data is Dictionary)
	var slots: Dictionary = (data as Dictionary).get("slots", {})
	assert_false(slots.is_empty())

	for slot_name in slots.keys():
		var info: Dictionary = slots[slot_name]
		assert_true(info.has("open"), "Slot %s has open path" % slot_name)
		var open_path: String = str(info["open"])
		assert_false(open_path.contains("/licensed/"), "Open path does not contain /licensed/")
		assert_true(ResourceLoader.exists(open_path), "Resource exists at open path %s" % open_path)

		var licensed: Variant = info.get("licensed")
		if licensed != null:
			var lic_str: String = str(licensed)
			assert_true(lic_str.begins_with("res://assets/audio/licensed/"), "Licensed path is under res://assets/audio/licensed/: %s" % lic_str)

func test_gitignore_contains_licensed_audio() -> void:
	var text: String = FileAccess.get_file_as_string("res://.gitignore")
	assert_true(text.contains("assets/audio/licensed/"), ".gitignore contains assets/audio/licensed/")

func test_open_manifest_sources() -> void:
	var errs: Array[String] = []
	var data: Variant = DefLoader.load_json("res://tools/audio/open_manifest.json", errs)
	assert_not_null(data)
	assert_true(data is Dictionary)
	var items: Array = (data as Dictionary).get("items", [])
	assert_false(items.is_empty())
	for item in items:
		var src: String = str(item.get("source", ""))
		assert_true(check_open_source(src), "Open source %s contains no forbidden pack names" % src)
