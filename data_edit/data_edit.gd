class_name DataEdit
extends GraphEdit


@export var replace_links: bool = true
var nodes_connections_from: Dictionary = {}
var nodes_linked_from: Dictionary = {}
var nodes_linked_to: Dictionary = {}
var node_refs: Dictionary = {}
var selected_nodes: Dictionary = {}
var sorted_nodes: Array = []
@onready var context_menu: PopupMenu = $ContextMenu
@onready var datanode_context_menu: PopupMenu = $DataNodeContextMenu


func _ready() -> void:
	connection_request.connect(_on_connection_request)
	delete_nodes_request.connect(_on_delete_nodes_request)
	disconnection_request.connect(_on_disconnection_request)
	node_selected.connect(_on_node_selected)
	node_deselected.connect(_on_node_deselected)
	popup_request.connect(_on_popup_request)
	
	context_menu.node_selected.connect(add_datanode)
	#datanode_context_menu.connect(_on_node_popup_request)


func add_datanode(node_name: String) -> void:
	var node: DataNode = DataNodes.get_node(node_name).duplicate()
	add_child(node)
	node.position_offset = (scroll_offset + get_local_mouse_position()) / zoom
	node.close_request.connect(_on_node_close_request.bind(node))
	node.popup_request.connect(_on_node_popup_request.bind(node))
	node.user_update.connect(evaluate_datanodes)
	
	nodes_connections_from[node.name] = []
	nodes_linked_from[node.name] = {}
	nodes_linked_to[node.name] = {}
	node_refs[node.name] = node
	set_selected(node)
	sort_datanodes()


func clear_datanode_links(node: Node, sort_now: bool = false) -> void:
	for conn in get_connection_list():
		if conn.to == node.name or conn.from == node.name:
			unlink_datanode(conn.from, conn.from_port, conn.to, conn.to_port, false)
	if sort_now:	#true only on right-click context menu
		sort_datanodes()


func evaluate_datanodes() -> void:
	for node in sorted_nodes:
		var binds: Dictionary = {}
		if nodes_connections_from.has(node):
			for conn in nodes_connections_from[node]:
				binds[conn.to_port] = node_refs[conn.from].outputs[conn.from_port]
		node_refs[node].evaluate(binds)


func link_datanode(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node: return
	connect_node(from_node, from_port, to_node, to_port)
	nodes_connections_from[to_node].push_back({"from": from_node, "from_port": from_port, "to_port": to_port})
	nodes_linked_from[to_node][from_node] = nodes_linked_from[to_node].get(from_node, 0) + 1
	nodes_linked_to[from_node][to_node] = nodes_linked_to[from_node].get(to_node, 0) + 1
	if not sort_datanodes():
		unlink_datanode(from_node, from_port, to_node, to_port)


func remove_datanode(node: Node, sort_now: bool = false) -> void:
	clear_datanode_links(node)
	nodes_connections_from.erase(node.name)
	nodes_linked_from.erase(node.name)
	nodes_linked_to.erase(node.name)
	node_refs.erase(node.name)
	node.queue_free()
	if sort_now:	#true only on right-click context menu
		sort_datanodes()


func sort_datanodes() -> bool:
	# Kahn's algorithm: https://en.wikipedia.org/wiki/Topological_sorting#Kahn's_algorithm
	var ins: Dictionary = nodes_linked_from.duplicate(true)
	var outs: Dictionary = nodes_linked_to.duplicate(true)
	var L: Array = []
	var S: Array = ins.keys().filter( func(n): if ins[n].is_empty(): return n )
	
	while S:
		var n: StringName = S.pop_back()
		ins.erase(n)
		if not n in L:
			L.push_back(n)
		for m in outs[n].keys():
			ins[m].erase(n)
			if ins[m].is_empty():
				if not m in S:
					S.push_back(m)
		outs.erase(n)
	
	sorted_nodes = [] if ins or outs else L
	
	var is_valid_sorting = not sorted_nodes.is_empty()
	if is_valid_sorting:
		evaluate_datanodes()
	return is_valid_sorting


func toggle_arrange_button() -> void:
	get_zoom_hbox().get_child(-1).disabled = selected_nodes.values().count(true) == 1


func unlink_datanode(from_node: StringName, from_port: int, to_node: StringName, to_port: int, sort_now: bool = true) -> void:
	disconnect_node(from_node, from_port, to_node, to_port)
	nodes_connections_from[to_node].erase({"from": from_node, "from_port": from_port, "to_port": to_port})
	nodes_linked_from[to_node][from_node] -= 1
	if not nodes_linked_from[to_node][from_node]:
		nodes_linked_from[to_node].erase(from_node)
	nodes_linked_to[from_node][to_node] -= 1
	if not nodes_linked_to[from_node][to_node]:
		nodes_linked_to[from_node].erase(to_node)
	if sort_now:	#false only on bulk disconnect by clear_datanode_connections
		sort_datanodes()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	for conn in get_connection_list():
		if conn.to == to_node and conn.to_port == to_port:
			if conn.from == from_node and conn.from_port == from_port: return
			if not replace_links: return
			unlink_datanode(conn.from, conn.from_port, conn.to, conn.to_port)
			break
	link_datanode(from_node, from_port, to_node, to_port)


func _on_delete_nodes_request(nodes: Array[StringName]) -> void:
	if nodes.is_empty(): return
	for node in selected_nodes.keys():
		if selected_nodes[node]:
			remove_datanode(node)
	selected_nodes = {}
	toggle_arrange_button()
	sort_datanodes()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	unlink_datanode(from_node, from_port, to_node, to_port)
	set_selected(null)


func _on_node_close_request(node: Node) -> void:
	set_selected(node)
	_on_delete_nodes_request([node.name])


func _on_node_deselected(node: Node) -> void:
	selected_nodes[node] = false
	toggle_arrange_button()


func _on_node_popup_request(location: Vector2, node: Node) -> void:
	set_selected(node)
	datanode_context_menu.position = location
	datanode_context_menu.popup()


func _on_node_selected(node: Node) -> void:
	selected_nodes[node] = true
	toggle_arrange_button()


func _on_popup_request(location: Vector2) -> void:
	set_selected(null)
	context_menu.position = location
	context_menu.popup()
