/obj/landmark/map_data
	name = "Map Data"
	desc = "An unknown location."
	invisibility = INVISIBILITY_ABSTRACT

	var/height = 1     ///< The number of Z-Levels in the map.
	var/turf/edge_type ///< What the map edge should be formed with. (null = world.turf)
