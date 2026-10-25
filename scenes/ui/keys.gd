class_name Keys
## Key hints: [Z], [X], [C], [A], [UP], [ARROWS], [ENTER] and [ESC] in a line of text become
## inline keycap icons (BBCode for a RichTextLabel), as tall as the text (the two-row arrow
## cluster half as tall again, so each arrow stays readable).

const NAMES: Array[String] = ["Z", "X", "C", "A", "UP", "ARROWS", "ENTER", "ESC"]


static func bbcode(text: String, height: int) -> String:
	for key in NAMES:
		var tall := int(height * 1.5) if key == "ARROWS" else height
		text = text.replace("[%s]" % key, "[img height=%d]res://assets/art/ui/key_%s.png[/img]" % [tall, key.to_lower()])
	return text
