extends RuneRules
## A second, deliberately different rune rule set, for tests only: any rune may join any other,
## nothing has sockets, and a skill holds at most three runes. It proves the rune screen and the
## save path work with whatever rule set is in force (selftest _test_runes, ui_click_probe).

const CAP := 3


func _init() -> void:
	setup("free_test", {"title": "Free (test rules)", "notes": ["Test rules: anything joins anything, three runes at most."]})


func legend() -> Array[Dictionary]:
	return [{"colour": "plain", "label": "joined"}]


func capacity(_ctx: RuneContext) -> int:
	return CAP


func _describe_link(word: Dictionary, a: int, b: int, _ctx: RuneContext) -> Dictionary:
	return {"kind": "joined", "label": "joined", "colour": "plain", "text": "%s - %s: joined" % [rune_name(word, a), rune_name(word, b)]}


func _word_state(word: Dictionary, _ctx: RuneContext) -> Dictionary:
	var one: bool = RuneWord.is_joined(word)
	return {"closed": one and RuneWord.size(word) > 1, "label": "whole" if one else "in pieces"}
