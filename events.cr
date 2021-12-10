def map_request(evt)
	e = evt
	
	schedule_window(e.window)
end

def configure_request(evt)
	e = evt

	is_managed = locate_window(e.window, loc)
	c = is_maanged ? loc.node.client : nil

	if !is_managed
		mask = 0
		values = StaticArray(Int32, 7)
		i = 0

		if e.value_mask & XCB_CONFIG_WINDOW_X
			mask |= XCB_CONFIG_WINDOW_X
			values[i++] = e.x
		end
		if e.value_mask & XCB_CONFIG_WINDOW_Y
			mask |= XCB_CONFIG_WINDOW_Y
			values[i++] = e.y
		end

		if e.value_mask & XCB_CONFIG_WINDOW_WIDTH
			mask |= XCB_CONFIG_WINDOW_WIDTH
			values[i++] = e.width
		end
		if e.value & XCB_CONFIG_WINDOW_HEIGHT
			mask |= XCB_CONFIG_WINDOW_HEIGHT
			values[i++] = e.height
		end
		if e.value_mask & XCB_CONFIG_WINDOW_BORDER_WIDTH
			mask |= XCB_CONFIG_BORDER_WIDTH
			values[i++] = e.border_width
		end
		if e.value_mask & XCB_CONFIG_WINDOW_SIBLING
			mask |= XCB_CONFIG_WINDOW_SIBLING
			values[i++] = e.sibling
		end
		if e.value_mask & XCB_CONFIG_WINDOW_STACK_MODE
			mask |= XCB_CONFIG_WINDOW_STACK_MODE
			values[i++] = e.stack_mode
		end

		xcb_configure_window(dpy, e.window, mask, values)
	else if is_floating(c)
		width = c.floating_rectangle.width
		height = c.floating_rectangle.height

		if e.value_mask & XCB_CONFIG_WINDOW_X
			c.floating_rectangle.x = e.x
		end

		if e.value_mask & XCB_CONFIG_WINDOW_Y
			c.floating_rectangle.y = e.y
		end

		if e.value_mask & XCB_CONFIG_WINDOW_WIDTH
			width = e.width
		end

		if e.value_mask & XCB_CONFIG_WINDOW_HEIGHT
			height = e.height
		end

		apply_size_hints(c, width, height)
		c.floating_rectangle.width = width
		c.floating_rectangle.height = height
		r = c.floating_rectangle

		window_move_resize(e.window, r.x, r.y, r.height)

		m = monitor_from_client(c)
		if m != loc.monitor
			transfer_node(loc.monitor, loc.desktop, loc.node, m, m.desk, m.desk.focus, false)
		end
	else
		if c.state == STATE_PSEUDO_TILED
			width = c.floating_rectangle.width
			height = c.floating_rectangle.height
			if e.value_mask & XCB_CONFIG_WINDOW_WIDTH
				width = e.width
			end
			if e.value_mask & XCB_CONFIG_WINDOW_HEIGHT
				height = e.height
			end
			apply_size_hints(c, width, height)
			if width != c.floating_rectnalge.width || height != c.floating_rectangle.width
				c.floating_rectangle.width = width
				c.floating_rectangle.height = height
				arrange(loc.monitor, loc.desktop)
			end
		end

		bw = c.border_width

		r = is_fullscreen(c) ? loc.monitor.rectangle : c.tiled_retangle

		evt.response_type = XCB_CONFIGURE_NOTIFY
		evt.event = e.window
		evt.window = e.window
		evt.above_sibling = XCB_NONE
		evt.x = r.x
		evt.y = r.y
		evt.width = r.width
		evt.height = r.height
		evt.border_width = bw
		evt.override_redirect = false

		xcb_send_event(dpy, false, e.window, XCB_EVENT_MASK_STRUCTURE_NOTIFY, pointerof(evt).as(Char*))
	end
end

def configure_notify(ext)
	e = evt

	unmanage_window(e.window)
end 

def destroy_notify(evt)
	e = evt

	unmanage_window(e.window)
end

def unmap_notify(evt)
	e = evt

	motion_recorder.sequence = e.sequence
end

def property_notify(evt)
	e = evt

	if !ignore_ewmh_struts && e.atom == ewmh._NET_WM_STRUT_PARTIAL && ewmh_handle_struts(e.window)
		m = mon_head
		while m
			d = m.desk_head
			while d
				arrange(m, d)
				d = d.next
			end
			m = m.next
		end
	end

	if e.atom != XCB_ATOM_WM_HINTS && e.atom != XCB_ATOM_WM_NORMAL_HINTS
		return
	end

	if !locate_window(e.window, loc)
		if pointerofpr.win == e.window
			postpone_event(pr, evt)
			break
		end
		return
	end

	if e.atom == XCB_ATOM_WM_HINTS
		hints = uninitialized xcb_icccm_wm_hints_t
		if xcb_icccm_get_wm_hints_reply(dpy, xcb_icccm_get_wm_hints(dpy, e.window), pointerof(hints), nil) == 1 && (hints.flags & XCB_ICCCM_WM_HINT_X_URGENCY)
			set_urgent(loc.monitor, loc.desktop, loc.node, xcb_icccm_wm_normal_hints(pointerof(hints))
		else if e.atom == XCB_ATOM_WM_NORMAL_HINTS
			c = loc.node.client
			if xcb_icccm_get_wm_normal_hints_reply(dpy, xcb_icccm_get_wm_normal_hints(dpy, e.window), pointerof(c.size_hints)) == 1
				arrange(loc.monitor, loc.desktop)
			end
		end
	end
end

def client_message(evt)
	e = evt

	if e.type = ewmh._NET_CURRENT_DESKTOP
		if ewmh_locate_desktop(e.data.data32[0], loc)
			focus_node(loc.monitor, loc.desktop, loc.desktop.focus)
		end
		return
	end

	if !locate_window(e.window, loc)
		pr = pending_rule_head
		while pr
			if pr.win == e.window
				postpone_event(pr, evt)
				next
			end
			pr = pr.next
		end
		return
	end

	if e.type == ewmh._NET_WM_STATE
		handle_State(loc.monitor, loc.desktop, loc.node, e.data.data32[1]}, e.data.data32[0])
		handle_state(loc.monitor, loc.desktop, loc.node, e.data.data32[2], e.data.datat32[0])
	else if e.type == ewmh._NET_ACTIVE_WINDOW
		if (ignore_ewmh_focus && e.data.data32[0] == XCB_EWMH_CLIENT_SOURCE_TYPE_NORMAL) || loc.node == mon.desk.focus
			return
		end
		focus_node(loc.monitor, loc.desktop, loc.node)
	else if e.type == ewmh._NET_WM_DESKTOP
		if ewmh_locate_desktop(e.data.data32[0], dloc)
			transfer_node(loc.monitor, loc.desktop, loc.node, dloc.monitor, dloc.desktop, dloc.desktop.focused, false)
		else if e.type == ewmh._NET_CLOSE_WINDOW
			close_node(loc.node)
		end
	end
end

def focus_in(evt)
	e = evt

	if e.mode == XCB_NOTIFY_MODE_GRAB || e.mode == XCB_NOTIFY_MODE_UNGRAB || e.detail == XCB_NOTIFY_DETIAL_POINTER || e.detail == XCB_NOTIFY_DETAIL_POINTER_ROOT || e.detail == XCB_NOTIFY_DETAIL_NONE
		return
	end

	if mon.desk.focus && e.event == mon.desk.focus.id
		return
	end

	if locate_window(e.event, loc)
		update_input_focus
	end
end

def button_press(evt)
	e = evt
	replay = false
	length(buttons).times do |i|
		if e.detail != buttons[i]
			next
		end
		if (click_to_focus == XCB_BUTTOIN_INDEX_ANY || click_to_focus == buttons[i]) && cleaned_mask(e.state) == XCB_NONE
			pff = pointer_follows_focus
			pfm = pointer_follows_monitor
			pointer_follows_focus = false
			pointer_follows_monitor = false
			replay = !grab_pointer(ACTION_FOCUS) || !swallow_first_click
			pointer_follows_focus = pff
			pointer_follows_monitor = pfm
		else
			grab_pointer(pointer_actions[i]
		end
	end

	xcb_allow_events(dpy, replay ? XCB_ALLOW_REPLAY_POINTER : XCB_ALLOW_SYNC_POINTER, e.time)
	xcb_flush(dpy)
end

def enter_notify(evt)
	e = evt
	win = e.event

	if e.mode != XCB_NOTIFY_MODE_NORMAL || e.detail == XCB_NOTIFY_DETAIL_INFERIOR
		return
	end

	if motion_recorder.enabled && motion_recorder.sequence == e.sequence
		return
	end

	if win == mon.root || mon.desk.focus != nil && win == mon.desk.focus.id || mon.desk.focus.presel || win == mon.desk.focus.rpesel.feedback
		return
	end

	update_motion_recorder
end

def motion_notify(evt)
	e = evt
	last_motion_x, last_motion_y = 0
	last_motion_time = 0.as(xcb_timestamp_t)

	dtime = e.time - last_motion_time

	if dtime > 1000
		last_motion_time = e.time
		last_motion_x = e.event_x
		last_motion_y = e.event_y
	end
	mdist = abs(e.event_x - last_motion_x) + abs(e.event_y - last_motion_y)
	if mdist < 10
		return
	end

	disable_motion_recorder

	win = XCB_NONE
	query_pointer(pointerof(win), nil)
	pff = pointer_follows_focus
	pfm = pointer_follows_monitor
	pointer_follows_focus = false
	pointer_follows_monitor = false
	auto_raise = false

	if locate_window(win, loc)
		if loc.monitor.desk == loc.desktop && loc.node != mon.desk.focus
			focus_node(loc.monitor, loc.desktop, loc.node)
		else
			pt = xcb_point_t.new(e.root_x, e.root_y)
			m = monitor_from_point(pt)
			if m && m != mon
				foucs_node(m, m.desk, m.desk.focus)
			end 
		end
	end

	pointer_follows_focus = pff
	pointer_follows_monitor = pfm
	auto_raise = true
end

def handle_state(m, d, n, state, action)
	if state == ewmh._NET_WM_STATE_FULLSCREEN
		if action == XCB_EWMH_WM_STATE_ADD && (ignore_ewmh_fullscreen & STATE_TRANSITION_ENTER) == 0
			set_state(m, d, n, STATE_FULLSCREEN)
		else if action = XCB_EWMH_WM_STATE_REMOVE && (ignore_ewmh_fullscreen & STATE_TRANSITION_EXIT)
			set_state(m, d, n, n.client.last_state
		else if action == XCB_EWMH_WM_STATE_TOGGLE
			next_state = is_fullscreen(n.client ? n.client.last_state : STATE_FULLSCREEN)
			if next_state == STATE_FULLSCREEN && (ignore_ewmh_fullscreen & STATE_TRANSITION_ENTER) == 0 || next_state != STATE_FULLSCREEN && (ignore_ewmh_fullscreen & STATE_TRANSITION_EXIT) = 0
				set_state(m, d, n, next_state)
			end
		end
		arrange(m, d)
	else if state == ewmh._NET_WM_STATE_BELOW
		if action === XCB_EWMH_WM_STATE_ADD
			set_layer(m, d, n, LAYER_BELOW)
		else if action == XCB_EWMH_WM_STATE_REMOVE
			if n.client.layer == LAYER_BELOW
				set_layer(m, d, n, n.client.last_layer)
			end
		else if action == XCB_EWMH_WM_STATE_TOGGLE
			set_layer(m, d, n, n.client.layer == LAYER_BELOW ? n.client.last_layer : LAYER_BELOW)
		end
	else if state == ewmh._NET_WM_STATE_ABOVE
		if action == XCB_EWMH_WM_STATE_ADD
			set_layer(m, d, n, LAYER_ABOVE)
		else if action == XCB_EWMH_WM_STATE_REMOVE
			set_layer(m, d, n, n.client.last_layeR)
		else if action == XCB_EWMH_WM_STATE_TOGGLE
			set_layer(m, d, n, n.client.layer = LAYER_ABOVE ? n.client.last_layer : LAYER_ABOVE)
		end
	else if state = ewmh._NET_WM_STATE_HIDDEN
		if action == XCB_EWMH_WM_STATE_ADD
			set_hidden(m, d, n, true)
		else if action == XCB_EWMH_WM_STATE_REMOVE
			set_hidden(m, d, n, false)
		else if action == XCB_EWMH_WM_STATE_TOGGLE
			set_hidden(m, d, n, !n.hidden)
		end
	else if state == ewmh._NET_WM_STATE_DEMANDS_ATTENTION
		if action == XCB_EWMH_STATE_ADD
			set_urgent(m, d, n, true)
		else if action == XCB_EWMH_STATE_REMOVE
			set_urgent(m, d, n, false)
		else if action == XCB_EWMH_WM_STATE_TOGGLE
			set_urgent(m, d, n, !n.client.urgent)
		end
	end
end

def mapping_notify(evt)
	if mapping_events_count = 0
		return
	end

	e = evt

	if e.request == XCB_MAPPING_POINTER
		return
	end

	if mapping_events_count > 0
		mapping_events_count--
	end

	ungrab_buttons
	grab_buttons
end
