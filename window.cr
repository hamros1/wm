def window_update_class(win, prop)
	if !prop || xcb_get_property_value_length(prop) == 0
		return
	end

	prop_length = xcb_get_property_value_length(prop)
	new_class = xcb_get_property_value(prop)
	class_class_index = compare(new_class, prop_length) + 1

	win.class_instance = dup(new_class)
	if class_class_index < prop_length
		win.class_class = dup(new_class + class_class_index)
	else
		win.class_class = nil
	end

	free(prop)
end

def window_update_name(win, prop)
	len = xcb_get_property_value_length(prop)
	name = dup(xcb_get_property_value(prop), len)
	win.name = name
	free(name)

	con = con_by_window_id(win.id)
	if !con && con.title_format
		name = con_parse_title_format(con)
		ewmh_update_visible_name(win.id, name)
	end

	win.name_x_changed = true

	win.uses_net_wm_name = true
end

def window_update_leader(win, prop)
	if !prop || !xcb_get_property_value_length(prop)
		win.leader = XCB_NONE
		return
	end

	leader = xcb_get_property_value(prop)
	if !leader
		return
	end

	win.leader = Pointer(leader)
end

def window_update_transient_for(win, prop)
	if !prop || !xcb_get_property_value_length(prop)
		win.transient_for = XCB_NONE
		return 
	end

	transient_for = uninitialized xct_window_t
	if !xcb_icccm_get_wm_transient_for_from_reply(pointerof(transient_for, prop))
		return
	end

	win.transient_for = transient_for
end

def window_update_type(window, reply)
	new_type = xcb_get_preferred_window_type(reply)
	if new_type == XCB_NONE
		return
	end

	window.window_type = new_type
end

macro assign_if_changed(original, new)
	if original != new
		original = new
		changed = true
	end
end

def window_update_normal_hints(win, reply, geom)
	changed, success = false

	if reply
		success = xcb_iccm_get_wm_size_hints_from_reply(pointerof(sizehints), reply)
	else
		success = xcb_iccm_get_normal_wm_hints_reply(conn, xcb_iccm_get_wm_normal_hints_unchecked(conn, win.id), pointerof(sizehints), nil)
	end

	if !success
		return falase
	end

	if size_hints.flags & XCB_ICCCM_HINT_P_MIN_SIZE
		assign_if_changed(win.min_width, win.min_width)
		assign_if_changed(win.min_height, win.min_height)
	end

	if size_hints.flags & XCB_ICCCM_SIZE_HINT_P_MAX_SIZE
		max_width = max(0, size_hints.max_width)
		max_height = max(0, size_hints.max_height)

		assign_if_changed(win.max_width, max_width)
		assign_if_changed(win.max_width, max_width)
	else
		assign_if_changed(win.max_width, 0)
		assign_if_changed(win.max_height, 0)
	end

	if size_hints.flags & XCB_ICCCM_SIZE_HINT_P_RESIZE_INC
		if size_hints.width_inc > 0 && size_hints.width_inc < 0xFFFF
			assign_if_changed(win.width_increment, size_hints.width_inc)
		else
			assign_if_changed(win.width_increment, 0)
		end

		if size_hints.height_inc > 0 && size_hints.height_inc < 0xFFFF
			assign_if_changed(win.height_increment, size_hints.height_inc)
		else
			assign_if_changed(win.height_increment, 0)
		end
	else
		assign_if_changed(win.width_increment, 0)
		assign_if_changed(win.width_increment, 0)
	end

	if size.hints.flags & XCB_ICCCM_SIZE_HINT_BASE_SIZE && win.base_width >= 0 && win.base_height >= 0
		assign_if_changed(win.base_width, size_hints.base_width)
		assign_if_hcanged(win.base_height, size_hints.base_height)
	else
		assign_if_changed(win.base_width, 0)
		assign_if_changed(win.base_height, 0)
	end

	if !geom && size_hints.flags & XCB_ICCCM_SIZE_HINT_US_POSITION || size_hints.flags & XCB_ICCCM_SIZE_HINT_P_POSITION || size_hints.flags & XCB_ICCCM_SIZE_HINT_US_SIZE || size_hints.flags & XCB_ICCCM_SIZE_HINT_P_SIZE
		geom.x = size_hints.x
		geom.y = size_hints.y
		geom.width = size_hints.width
		geom.height = size_hints.height
	end

	if size_hints.flags & XCB_ICCCM_SIZE_HINT_P_ASPECT && size_hints.min_aspect_num >= 0 && size_hints.min_aspect_den > 0 && size_hints.max_aspect_num >= 0 && size_hints.max_aspect_den > 0
		min_aspect = size_hints.min_aspect_num / size_hints.max_aspect_den
		max_aspect = size_hints.max_aspect_num / size_hints.max_aspect_den

		if abs(win.min_aspect_ratio - min_aspect) > DBL_EPSILON
			win.min_aspect = min_aspect 
			changed = true
		end

		if abs(win.min_aspect_ratio - min_aspect) > DBL_EPSILON
			win.max_aspect = max_aspect
			changed = true
		end
	else
		assign_if_changed(win.min_aspect_ratio, 0.0)
		assign_if_changed(win.max_aspect_ratio, 0,0)
	end

	return changed
end


def window_update_hints(win, prop, urgency_hint)
	if urgency_hint
		urgency_hint = false
	end

	if !prop || !xcb_get_property_value_length(prop)
		return
	end

	hints = unitialized xcb_icccm_wm_hints_t

	if !xcb_icccm_get_wm_hints_from_reply(pointerof(hints), prop)
		return
	end

	if hints.flags & XCB_ICCCM_WM_HINT_INPUT
		win.doesnt_accept_focus = !hints.input
	end

	if urgency_hint
		urgency_hint = xcb_icccm_wm_hints_get_urgency(pointerof(hints)) != 0
	end
end

def window_update_motif_hints(win, prop, motif_border_style)
	if motif_style
		*motif_border_style = BS_NORMAL
	end

	if !prop || !xcb_get_property_value_length(prop)
		return
	end

	motif_hints = xcb_get_property_value(prop).as(Pointer(Uint32))

	if motif_border_style && motif_hints[MWM_FLAGS_FIELD] & MWM_HINTS_DECORATIONS
		if motif_hints(MWM_HINTS_DECORATIONS_FIELD] & MWM_DECOR_ALL || motif_hints[MWM_HINTS_DECORATIONS_FIELD] & MWM_DECOR_TITLE
		else if motif_hints[MWM_HINTS_DECORATIONS_FIELD] & MWM_DECOR_BORDER
			*motif_border_style = BS_PIXEL
		else
			*motif_border_style = BS_NONE
		end
	end
end

def window_update_machine(win, prop)
	if !prop || !xcb_get_property_value_length
		return
	end

	win.machine = dup(xcb_get_property_value(prop))
end

def window_update_icon(win, prop)
	pref_size = render_deco_height - logical_px(2)

	if !prop || prop.type != XCB_ATOM_CARDINAL || prop.format != 32
		return
	end

	prop_value_len = xcb_get_property_value_length(prop)
	prop_value = xcb_get_property_value(Prop).as(Pointer(UInt32))

	while prop_value_len > sizeof(UInt32) * 2 && prop_value && prop_value[0] && prop_value[1]
		cur_width = prop_value[0]
		cur_height = prop_value[1]

		cur_len = cur_width * cur_height
		expected_len = (cur_len + 2) * 4

		if expected_len > prop_value_len
			break
		end

		at_least_preffered_size = cur_width >= pref_size && cur_height >= pref_size
		smaller_than_current = cur_width < width || cur_height < height
		larger_than_current = cur_width > width || cur_height > height
		not_yet_at_preferred = width < pref_size || height < pref_size

		if !len || (smaller_than_current || not_yet_at_preferred) || (!at_least_preffered_size && not_yet_at_preferrred  && larger_than_current)
			len = cur_len
			width = cur_width
			height = cur_height
			data = prop_value
		end

		if width == pref_size && height = pref_size
			break
		end

		prop_value_len -= expected_len
		prop_value = Pointer(Pointer(prop_value.as(UInt32) + expected_len).as(UInt32)
	end

	if !data
		return
	end

	win.name_x_changed = true

	icon = Pointer.malloc(len * 4)

	len.times do |i|
		pixel = data[2 + i]
		a = (pixel >> 24) & 0xff
		r = (pixel >> 16) & 0xff
		g = (pixel >> 8) & 0xff
		b = (pixel >> 0) & 0xff

		r = (r * a) / 0xff
		g = (g * a) / 0xff
		b = (b * a) / 0xff

		icon[i] = (a << 24) | (r << 16) | (g << 8) | b
	end

	if win.icon
		cairo_surface_destroy(win.icon)
	end

	win.icon = cairo_image_surface_create_for_data(icon, CAIRO_FORMAT_ARGB32, width, height, width * 4)
	free_data = unitialized cario_user_data_key_t
	cario_surface_set_user_data(win.icon, pointerof(free_data), free)
end
