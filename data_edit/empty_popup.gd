extends PopupMenu


signal node_selected(node_name: String)


var map: Array[String] = []
var counter := 0


func _ready() -> void:
	var curr_cat = ""
	for part in DataNodes.get_children():
		if part.name.begins_with("_"): continue
		if part is DataNode or part is GraphNode:
			add_item(part.name, counter)
			map.append(curr_cat + part.name)
			counter += 1
		elif part is Control:
			var submenu: PopupMenu = PopupMenu.new()
			submenu.name = part.name
			curr_cat = str(part.name, "/")
			add_child(submenu)
			for node in part.get_children():
				submenu.add_item(node.name, counter)
				map.append(curr_cat + node.name)
				counter += 1
			add_submenu_item(part.name, part.name)
			submenu.id_pressed.connect(on_submenu_id_pressed)
			curr_cat = ""
		else:
			assert(false, "Wrong popup menu structure")
	
	id_pressed.connect(on_submenu_id_pressed)


func on_submenu_id_pressed(id: int):
	node_selected.emit(map[id])
