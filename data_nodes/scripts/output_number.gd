extends DataNode


func function() -> void:
	params[0] = inputs[0]
	$Parameters/Label0/Value.text = str(params[0])
