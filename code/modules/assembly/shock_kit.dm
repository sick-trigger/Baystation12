/obj/item/assembly/shock_kit
	name = "electrohelmet assembly"
	desc = "This appears to be made from both an electropack and a helmet."
	icon_state = "shock_kit"
	var/obj/item/clothing/head/helmet/part1 = null
	var/obj/item/device/radio/electropack/part2 = null
	var/status = 0
	w_class = ITEM_SIZE_HUGE
	obj_flags = OBJ_FLAG_CONDUCTIBLE

/obj/item/assembly/shock_kit/Destroy()
	qdel(part1)
	qdel(part2)
	..()
	return

/obj/item/assembly/shock_kit/use_tool(obj/item/W, mob/living/user, list/click_params)
	if(isWrench(W) && !status)
		part1.dropInto(loc)
		part2.dropInto(loc)
		part1.master = null
		part2.master = null
		part1 = null
		part2 = null
		qdel(src)
		return TRUE
	if(isScrewdriver(W))
		status = !status
		to_chat(user, SPAN_NOTICE("[src] is now [status ? "secured" : "unsecured"]!"))
		return TRUE
	return ..()

/obj/item/assembly/shock_kit/attack_self(mob/user as mob)
	part1.attack_self(user, status)
	part2.attack_self(user, status)
	add_fingerprint(user)
	return

/obj/item/assembly/shock_kit/receive_signal()
	if(istype(loc, /obj/structure/bed/chair/e_chair))
		var/obj/structure/bed/chair/e_chair/C = loc
		C.shock()
	return
