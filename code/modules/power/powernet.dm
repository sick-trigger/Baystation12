/datum/powernet
	var/list/cables = list()	// all cables & junctions
	var/list/nodes = list()		// all connected machines

	var/load = 0				// the current load on the powernet, increased by each machine at processing
	var/newavail = 0			// what available power was gathered last tick, then becomes...
	var/avail = 0				//...the current available power in the powernet
	var/viewload = 0			// the load as it appears on the power console (gradually updated)
	var/number = 0				// Unused //TODEL

	var/smes_demand = 0			// Amount of power demanded by all SMESs from this network. Needed for load balancing.
	var/list/inputting = list()	// List of SMESs that are demanding power from this network. Needed for load balancing.

	var/smes_avail = 0			// Amount of power (avail) from SMESes. Used by SMES load balancing
	var/smes_newavail = 0		// As above, just for newavail

	var/perapc = 0			// per-apc avilability
	var/perapc_excess = 0
	var/netexcess = 0			// excess power on the powernet (typically avail-load)

	var/problem = 0				// If this is not 0 there is some sort of issue in the powernet. Monitors will display warnings.

/datum/powernet/New()
	START_PROCESSING_POWERNET(src)
	..()

/datum/powernet/Destroy()
	for(var/obj/structure/cable/C in cables)
		cables -= C
		C.powernet = null
	for(var/obj/machinery/power/M in nodes)
		nodes -= M
		M.powernet = null
	STOP_PROCESSING_POWERNET(src)
	return ..()

//Returns the amount of excess power (before refunding to SMESs) from last tick.
//This is for machines that might adjust their power consumption using this data.
/datum/powernet/proc/last_surplus()
	return max(avail - load, 0)

/datum/powernet/proc/draw_power(amount)
	var/draw = clamp(amount, 0, avail - load)
	load += draw
	return draw

/datum/powernet/proc/is_empty()
	return !length(cables) && !length(nodes)

//remove a cable from the current powernet
//if the powernet is then empty, delete it
//Warning : this proc DON'T check if the cable exists
/datum/powernet/proc/remove_cable(obj/structure/cable/C)
	cables -= C
	C.powernet = null
	if(is_empty())//the powernet is now empty...
		qdel(src)///... delete it

//add a cable to the current powernet
//Warning : this proc DON'T check if the cable exists
/datum/powernet/proc/add_cable(obj/structure/cable/C)
	if(C.powernet)// if C already has a powernet...
		if(C.powernet == src)
			return
		else
			C.powernet.remove_cable(C) //..remove it
	C.powernet = src
	cables +=C

//remove a power machine from the current powernet
//if the powernet is then empty, delete it
//Warning : this proc DON'T check if the machine exists
/datum/powernet/proc/remove_machine(obj/machinery/power/M)
	nodes -=M
	M.powernet = null
	if(is_empty())//the powernet is now empty...
		qdel(src)///... delete it - qdel


//add a power machine to the current powernet
//Warning : this proc DON'T check if the machine exists
/datum/powernet/proc/add_machine(obj/machinery/power/M)
	if(M.powernet)// if M already has a powernet...
		if(M.powernet == src)
			return
		else
			M.disconnect_from_network()//..remove it
	M.powernet = src
	nodes[M] = M

// Triggers warning for certain amount of ticks
/datum/powernet/proc/trigger_warning(duration_ticks = 20)
	problem = max(duration_ticks, problem)


//handles the power changes in the powernet
//called every ticks by the powernet controller
/datum/powernet/proc/reset()
	var/numapc = 0

	if(problem > 0)
		problem = max(problem - 1, 0)

	if(nodes && length(nodes)) // Added to fix a bad list bug -- TLE
		for(var/obj/machinery/power/terminal/term in nodes)
			if( istype( term.master_machine(), /obj/machinery/power/apc ) )
				numapc++

	netexcess = avail - load

	if(numapc)
		//very simple load balancing. If there was a net excess this tick then it must have been that some APCs used less than perapc, since perapc*numapc = avail
		//Therefore we can raise the amount of power rationed out to APCs on the assumption that those APCs that used less than perapc will continue to do so.
		//If that assumption fails, then some APCs will miss out on power next tick, however it will be rebalanced for the tick after.
		if (netexcess >= 0)
			perapc_excess += min(netexcess/numapc, (avail - perapc) - perapc_excess)
		else
			perapc_excess = 0

		perapc = avail/numapc + perapc_excess

	// At this point, all other machines have finished using power. Anything left over may be used up to charge SMESs.
	if(length(inputting) && smes_demand)
		var/smes_input_percentage = clamp((netexcess / smes_demand) * 100, 0, 100)
		for(var/obj/machinery/power/smes/S in inputting)
			S.input_power(smes_input_percentage)

	netexcess = avail - load

	if(netexcess)
		var/perc = get_percent_load(1)
		for(var/obj/machinery/power/smes/S in nodes)
			S.restore(perc)

	//updates the viewed load (as seen on power computers)
	viewload = round(load)

	//reset the powernet
	load = 0
	avail = newavail
	smes_avail = smes_newavail
	inputting.Cut()
	smes_demand = 0
	newavail = 0
	smes_newavail = 0

/datum/powernet/proc/get_percent_load(smes_only = 0)
	if(smes_only)
		var/smes_used = load - (avail - smes_avail) 			// SMESs are always last to provide power
		if(!smes_used || smes_used < 0 || !smes_avail)			// SMES power isn't available or being used at all, SMES load is therefore 0%
			return 0
		return clamp((smes_used / smes_avail) * 100, 0, 100)	// Otherwise return percentage load of SMESs.
	else
		if(!load)
			return 0
		return clamp((avail / load) * 100, 0, 100)

/datum/powernet/proc/get_electrocute_damage()
	switch(avail)
		if (1000000 to INFINITY)
			return min(rand(50,160),rand(50,160))
		if (200000 to 1000000)
			return min(rand(25,80),rand(25,80))
		if (100000 to 200000)//Ave powernet
			return min(rand(20,60),rand(20,60))
		if (50000 to 100000)
			return min(rand(15,40),rand(15,40))
		if (1000 to 50000)
			return min(rand(10,20),rand(10,20))
		else
			return 0

// Proc: apcs_overload()
// Parameters: 3 (failure_chance - chance to actually break the APC, overload_chance - Chance of breaking lights, reboot_chance - Chance of temporarily disabling the APC)
// Description: Damages output powernet by power surge. Destroys few APCs and lights, depending on parameters.
/datum/powernet/proc/apcs_overload(failure_chance, overload_chance, reboot_chance)
	for(var/obj/machinery/power/terminal/T in nodes)
		var/obj/machinery/power/apc/A = T.master_machine()
		if(istype(A))
			if (prob(failure_chance))
				A.set_broken(TRUE)
			if (prob(overload_chance))
				A.overload_lighting()
			if(prob(reboot_chance))
				A.energy_fail(rand(30,60))

////////////////////////////////////////////////
// Misc.
///////////////////////////////////////////////


// return a knot cable (O-X) if one is present in the turf
// null if there's none
/turf/proc/get_cable_node()
	if(!istype(src, /turf/simulated))
		return null
	for(var/obj/structure/cable/C in src)
		if(C.d1 == 0)
			return C
	return null
