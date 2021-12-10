def ewmh_update_current_desktop
	old_idx = NET_WM_DESKTOP_NONE
	idx = ewmh_get_workspace_index(focused)

	if idx == old_idx || idx == NET_WM_DESKTOP_NONE
		return
	end

	old_idx = idx

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__CURRENT_DESKTOP, XCB_ATOM, 32, 1, pointerof(idx))
end

def ewmh_update_number_of_desktops
	idx = 0
	croot.nodes_head.each do |nodes|
		idx++
	end

	if idx == oldidx
		return
	end
	oldidx = idx

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_NUMBER_OF_DESKTOPS, XCB_ATOM_CARDINAL, 32, 1, pointerof(idx))
end

def ewmh_update_desktop_names
	croot.nodes_head.each do |nodes|
		msg_length = ws.name.size + 1
	end

	croot.nodes_head.each do |nodes|
		desktop_names[current_position++] = ws.name[i]
	end
end

def ewmh_update_desktop_viewport
	num_desktops = 0
	croot.nodes_head.each do |nodes|
		num_desktops++
	end

	current_position = 0
	croot.nodes_head.each do |nodes|
		viewports[current_position++] = output.rect.x
		viewports[current_position++] = output.rect.y
	end

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_DESKTOP_VIEWPORT, XCB_ATOM_CARDINAL, 32, current_position, pointerof(viewports))
end

def ewmh_update_desktop_properties
	ewmh_update_number_of_desktops
	ewmh_update_desktop_viewport
	ewmh_update_current_desktop
	ewmh_update_desktop_names
	ewmh_update_wm_desktop
end

def ewmh_update_wm_desktop
	desktop = 0
	
	croot.nodes_head.each do |nodes|
		output_get_content(output).nodes_head.each do |nodes|
			ewmh_update_wm_desktop_recursively(workspace, desktop)

			if !con_is_internal(workspace)
				++desktop
			end
		end
	end
end

def ewmh_update_active_window(window)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_ACTIVE_WINDOW, XCB_ATOM_WINDOW, 32, 1, pointerof(window))
end

def ewmh_update_visible_name(window, name)
	if !name
		xcb_change_property(conn, XCB_PROP_MODE_REPLACE, window, A__NET_WM_VISIBLE_NAME, A_UTF8_STRING, 8, name.size, name)
	else
		xcb_delete_property(conn, window, A__NET_WM_VISIBLE_NAME)
	end
end

def ewmh_update_workarea
	xcb_delete_property(conn, root, A__NET_WORKAREA)
end

def ewmh_update_client_list(list, num_windows)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_CLIENT_LIST, XCB_ATOM_WINDOW, 32, num_windows, list)
end

def ewmh_update_client_list_stacking(stack, num_windows)
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_CLIENT_LIST_STACKING, XCB_ATOM_WINDOW, 32, num_windows, stack)
end

def ewmh_update_sticky(window, sticky)
	if sticky
		xcb_add_property_atom(conn, window, A__NET_WM_STATE, A__NET_WM_STATE_STICKY)
	else
		xcb_remove_property_atom(conn, window, A__NET_WM_STATE, A__NET_WM_STATE_STICKY)
	end
end

def ewmh_update_focused(window, is_focused)
	if is_focused
		xcb_add_property_atom(conn, window, A__NET_WM_STATE, A__NET_WM_STATE_FOCUSED)
	else
		xcb_remove_property_atom(conn, window, A__NET_WM_STATE, A__NET_WM_STATE_FOCUSED)
	end
end

def ewmh_setup_hints
	ewmh_window = xcb_generate_id(conn)
	xcb_create_window(conn, XCB_COPY_FROM_PARENT, ewmh_window, root, -1, -1, 1, 1, 0, XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT, XCB_CW_OVERRIDE_REDIRECT, [1].as(Array(UInt32)))
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, ewmh_window, A__NET_SUPPORTING_WM_CHECK, XCB_ATOM_WINDOW, 32, 1, pointerof(ewmh_window))
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, ewmh_window, A__NET_WM_NAME, A_UTF8_STRING, 8, "wm".size, "wm")
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_SUPPORTING_WM_CHECK, XCB_ATOM_WINDOW, 32, 1, pointerof(ewmh_window))

	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_WM_NAME, A_UTF8_STRING, 8, "wm".size, "wm")
	
	xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root, A__NET_SUPPORTED, XCB_ATOM_ATOM, 32, sizeof(supported_atoms) / sizeof(xcb_atom_t), supported_atoms)

	xcb_map_window(conn, ewmh_window)
	xcb_configure_window(conn, ewmh_window, XCB_CONFIG_STACK_MODE, [XCB_STACK_MODE_BELOW].as(Array(UInt32)))
end


