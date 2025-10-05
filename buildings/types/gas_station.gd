extends Destination
class_name GasStation

func spawn_agents(parent: Node2D) -> Array[Agent]:
	# For now - just hardcode some stuff, but might be able to abstract away
	# as like a dict or something
	var agents: Array[Agent]
	for h: Home in all_homes():
		var from = h.get_grid_cell()
		var to = get_grid_cell()
		agents.append(await Car.create_slow(parent, from, to))
		await _sleep(0.2)
	await _sleep(0.2)
	
	for h: Home in get_appartments():
		var from = get_grid_cell()
		var to = h.get_grid_cell()
		agents.append(await Car.create_distracted(parent, from, to))
		await _sleep(0.5)
		  
	return agents

func get_description() -> String:
	return """
Gas Sation:
	* First, summons a slow-driver from homes of all types
	* Then, sends a distracted-driver to all appartments
""".strip_edges()
