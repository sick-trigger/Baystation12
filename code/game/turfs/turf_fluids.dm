/turf/CanFluidPass(coming_from)
	if(flooded || density)
		return FALSE
	if(isnull(fluid_can_pass))
		fluid_can_pass = TRUE
		for(var/atom/movable/AM in src)
			if(AM.simulated && !AM.CanFluidPass(coming_from))
				fluid_can_pass = FALSE
				break
	return fluid_can_pass

/turf/proc/add_fluid(amount, fluid)
	if(!flooded)
		var/obj/fluid/F = locate() in src
		if(!F) F = new(src)
		SET_FLUID_DEPTH(F, F.fluid_amount + amount)

/turf/proc/remove_fluid(amount = 0)
	var/obj/fluid/F = locate() in src
	if(F) LOSE_FLUID(F, amount)

/turf/return_fluid()
	return (locate(/obj/fluid) in contents)

/turf/proc/make_flooded()
	if(!flooded)
		flooded = TRUE
		for(var/obj/fluid/F in src)
			qdel(F)
		update_icon()
		fluid_update()

/turf/is_flooded(lying_mob, absolute)
	return (flooded || (!absolute && check_fluid_depth(lying_mob ? FLUID_OVER_MOB_HEAD : FLUID_DEEP)))

/turf/check_fluid_depth(min)
	..()
	return (get_fluid_depth() >= min)

/turf/get_fluid_depth()
	..()
	if(is_flooded(absolute=1))
		return FLUID_MAX_DEPTH
	var/obj/fluid/F = return_fluid()
	return (istype(F) ? F.fluid_amount : 0 )

/turf/proc/show_bubbles()
	set waitfor = 0

	if(flooded)
		if(istype(flood_object))
			flick("ocean-bubbles", flood_object)
		return

	var/obj/fluid/F = locate() in src
	if(istype(F))
		flick("bubbles",F)

/turf/fluid_update(ignore_neighbors)

	fluid_blocked_dirs = null
	fluid_can_pass = null

	// Wake up our neighbors.
	if(!ignore_neighbors)
		for(var/checkdir in GLOB.cardinal)
			var/turf/T = get_step(src, checkdir)
			if(T) T.fluid_update(1)

	// Wake up ourself!
	var/dry_run = TRUE
	if(flooded)
		var/flooded_a_neighbor = 0
		FLOOD_TURF_NEIGHBORS(src, dry_run)
		if(flooded_a_neighbor)
			ADD_ACTIVE_FLUID_SOURCE(src)
	else
		REMOVE_ACTIVE_FLUID_SOURCE(src)
		for(var/obj/fluid/F in src)
			ADD_ACTIVE_FLUID(F)
