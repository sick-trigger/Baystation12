/datum/submap
	var/name
	var/pref_name
	var/singleton/submap_archetype/archetype
	var/list/jobs
	var/associated_z

/datum/submap/New(existing_z)
	SSmapping.submaps[src] = TRUE
	associated_z = existing_z

/datum/submap/Destroy()
	SSmapping.submaps -= src
	. = ..()

/datum/submap/proc/setup_submap(singleton/submap_archetype/_archetype)

	if(!istype(_archetype))
		testing( "Submap error - [name] - null or invalid archetype supplied ([_archetype]).")
		qdel(src)
		return

	// Not much point doing this when it has presumably been done already.
	if(_archetype == archetype)
		testing( "Submap error - [name] - submap already set up.")
		return

	archetype = _archetype
	if(!pref_name)
		pref_name = archetype.descriptor

	testing("Starting submap setup - '[name]', [archetype], [associated_z]z.")

	// Instantiate our job list.
	jobs = list()
	for(var/crew_job in archetype.crew_jobs)
		var/datum/job/submap/job = new crew_job(src, archetype.crew_jobs[crew_job])
		if(!job.whitelisted_species)
			job.whitelisted_species = archetype.whitelisted_species
		if(!job.blacklisted_species)
			job.blacklisted_species = archetype.blacklisted_species
		jobs[job.title] = job

	if(!associated_z)
		testing( "Submap error - [name]/[archetype ? archetype.descriptor : "NO ARCHETYPE"] could not find an associated z-level for spawnpoint placement.")
		qdel(src)
		return

	var/obj/overmap/visitable/cell = map_sectors["[associated_z]"]
	if(istype(cell))
		sync_cell(cell)

	// Add the spawn points to the appropriate job list.
	var/added_spawnpoint
	for(var/check_z in GetConnectedZlevels(associated_z))
		for(var/thing in block(locate(1, 1, check_z), locate(world.maxx, world.maxy, check_z)))
			for(var/obj/submap_landmark/spawnpoint/landmark in thing)
				var/datum/job/submap/job = jobs[landmark.name]
				if(istype(job))
					job.spawnpoints += landmark
					added_spawnpoint = TRUE

	if(!added_spawnpoint)
		testing( "Submap error - [name]/[archetype ? archetype.descriptor : "NO ARCHETYPE"] has no job spawn points.")
		qdel(src)
		return

	if(archetype && archetype.call_webhook)
		SSwebhooks.send(archetype.call_webhook, list("name" = name))

/datum/submap/proc/sync_cell(obj/overmap/visitable/cell)
	name = cell.name

/datum/submap/proc/available()
	return TRUE
