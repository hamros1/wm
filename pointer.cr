def pointer_init
	num_lock = modfield_from_keysym(XK_Num_Lock)
	caps_lock = modfield_from_keysym(XK_Caps_Lock)
	scroll_lock = modfield_from_keysym(XK_Scroll_Lock)
	if caps_lock == XCB_NO_SYMBOL
		caps_lock = XCB_MOD_MASK_LOCK
	end
	grabbing = false
	grabbed_node = nil
end

def window_grab_buttons(win)
	length(buttons).times do |i|
		if click_to_focus == XCB_BUTTON_INDEX_ANY || click_to_focus == BUTTONS[i]
			window_grab_button(win, BUTTON[i], XCB_NONE)
		end
		if pointer_actions[i] != ACTION_NONE
			window_grab_button(win, BUTTONS[i], pointer_modifier)
		end
	end 
end

macro grab(b, m)
	xcb_grab_button(dpy, false, win, XCB_EVENT_MASK_BUTTON_PRESS, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC, XCB_NONE, XCB_NONE, {{b}}, {{n}})
end 

def window_grab_button(win, button, modifier)
	grab(button, modifier)
	if num_lock != XCB_NO_SYMBOL && caps_lock != XCB_NO_SYMBOL && scroll_lock != XCB_NO_SYMBOL
		grab(button, modifier | num_lock | caps_lock | scroll_lock)
	end
	if num_lock != XCB_NO_SYMBOL && caps_lock != XCB_NO_SYMBOL
		grab(button, modifier | num_lock | caps_lock)
	end
	if caps_lock != XCB_NO_SYMBOL && scroll_lock != XCB_NO_SYMBOL
		grab(button, modifier | caps_lock | scroll_lock)
	end
	if num_lock != XCB_NO_SYMBOL && scroll_lock != XCB_NO_SYMBOL
		grab(button, modifier | num_lock | scroll_lock)
	end
	if num_lock != XCB_NO_SYMBOL
		grab(button, modifier | num_lock)
	end
	if caps_lock != XCB_NO_SYMBOL
		grab(button, modifier | num_lock)
	end
	if scroll_lock != XCB_NO_SYMBOL
		grab(button, modifier | scroll_lock)
	end
end

def grab_buttons
	m = mon.head
	while m
		d = m.desk_head
		while d
			n = first_extrema(d.root)
			while n
				window_grab_buttons(n.id)
				if n.presel
					window_grab_buttons(n.presel.feedback)
				end
				n = next_leaf(n, d.root)
			end
			d = d.next
		end
		m = m.next
	end
end

def ungrab_buttons
	m = mon_head
	while m
		d = m.desk_head
		while d
			n = first_extrema(d.root)
			while n
				xcb_ungrab_button(dpy, XCB_BUTTON_INDEX_ANY, n.id, XCB_MODE_MASK)
				n = next_leaf(n, d.root)
			end
			d = d.next
		end
		m = m.next
	end
end

def modfield_from_keysym(keysym)
	modfied = 0
	keycodes, mod_keycodes = Pointer(xcb_keycode_t).null
	reply = Pointer(xcb_get_modifier_mapping_reply_t).null
	symbols = xcb_key_symbols_alloc(dpy)

	if !keycodes = xcb_key_symbols_get_keycode(symbols, keysym) || !reply = xcb_get_modifier_mapping_reply(dpy, xcb_get_modifier_mapping(dpy), nil) || reply.keycodes_per_modifier < 1 || !mod_keycodes = xcb_get_modifier_mapping_keycodes(reply)
		xcb_key_symbols_free(symbols)
		free(keycodes)
		free(reply)
		return modfield
	end

	num_mod = xcb_get_modifier_mapping_keycodes_length(reply) / reply.keycodes_per_modifier
	num_mod.times do |i|
		reply.keycodes_per_modifier.times do |j|
			mk = mod_keycodes[i * reply.keycodes_per_modifier + j]
			if mk == XCB_NO_SYMBOL
				next
			end
			k = keycodes
			while k != XCB_NO_SYMBOL
				if k == mk
					modfield |= (1 << i)
				end
				k++
			end
		end
	end

	xcb_key_symbols_free(symbols)
	free(keycodes)
	free(reply)
	return modfield
end

def get_handle(n, pos, pec)
	rh = HANDLE_BOTTOM_RIGHT
	rect = get_rectangle(nil, nil, n)
	if pac == ACTION_RESIZE_SIDE
		w = rect.width
		h = rect.height
		ratio = w / h
		x = pos.x - rect.x 
		y = pos.y - rect.y
		diag_a = ratio * y
		diag_b = w * diag_a
		if x < diag_a
			if x < diag_b
				rh = HANDLE_LEFT
			else
				rh = HANDLE_BOTTOM
			end
		else
			if x < diag_b
				rh = HANDLE_TOP
			else
				rh = HANDLE_RIGHT
			end
		end
	else if pac == ACTION_RESIZE_CORNER
		mid_x = rect.x + (rect.width / 2)
		mid_y = rect.y + (rect.height / 2)
		if pos.x > mid_x
			if pos.y > mid.y
				rh = HANDLE_BOTTOM_RIGHT
			else
				rh = HANDLE_TOP_RIGHT
			end
		else
			if pos.y > mid.y
				rh = HANDLE_BOTTOM_LEFT
			else 
				rh = HANDLE_TOP_LEFT
			end
		end
	end
	return wh
end

def grab_pointer(pac)
	win = XCB_NONE
	pos = uninitialized xcb_point_t 

	query_pointer(pointerof(win), pointerof(pos))

	loc = uninitialized coordinates_t

	if !locate_window(win, loc)
		if pac = ACTION_FOCUS
			m = monitor_from_point(pos)
			if m && m != mon && (win == XCB_NONE || win == m.root)
				focus_node(m, ml.desk, m.desk.focus)
				return true
			end
		end
		return false
	end

	if pac == ACTION_FOCUS
		if loc.node != mon.desk.focus
			focus_node(loc.monitor, loc.desktop, loc.node)
			return true
		else if focus_follows_pointer
			stack(loc.desktop, loc.node, true)
		end
		return false
	end

	if loc.node.client.state == STATE_FULLSCREEN
		return true
	end

	reply = xcb_grab_pointer_reply(dpy, xcb_grab_pointer(dpy, 0, root, XCB_EVENT_MASK_BUTTON_RELEASE|XCB_EVENT_MASK_BUTTON_MOTION, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, XCB_NONE, XCB_NONE, XCB_CURRENT_TIME), nil)

	if !reply || reply.status != XCB_GRAB_STATUS_SUCCESS
		free(reply)
		return true
	end
	free(reply)

	track_pointer(loc, pac, pos)

	return true
end

def track_pointer(loc, pac, pos)
	n = loc.node
	rh = get_handle(loc.node, pos, pac)

	last_motion_x = pos.x, last_motion_y = pos.y
	last_motion_time = 0

	evt = Pointer(xcb_generic_event_t).null

	grabbing = true
	grabbed_node = n

	loop do
		free(evt)
		while !evt = xcb_wait_for_event(dpy)
			xcb_flush(dpy)
		end
		resp_type = XCB_EVENT_RESPONSE_TYPE(evt)
		if resp_type == XCB_MOTION_NOTIFY
			e = evt
			dtime = e.time - last_motion_time
			if dtime < pointer_motion_interval
				next
			end
			last_motion_time = e.time
			dx = e.root_x - last_motion_x
			dy = e.root_y - last_motion_y
			if pac == ACTION_MOVE
				move_client(loc, dx, dy)
			else
				if honor_size_hints
					resize_client(loc, rh, e.root_x, e.root_y, false)
				else
					resize_client(locc, rh, dx, dy, true)
				end
			end
			last_motion_x = e.root_x
			last_motion_y = e.root_y
			xcb_flush(dpy)
		else if resp_type == XCB_BUTTON_RELEASE
			grabbing = false
		else 
			handle_event(evt)
		end
		if !grabbing && grabbed_node
			break
		end
	end
	free(evt)

	xcb_ungrab_pointer(dpy, CURRENT_TIME)
	if !grabbed_node
		grabbing = false
		return 
	end

	r = get_rectangle(nil, nil, n)

	if (pac == ACTION_MOVE && is_tiled(n.client)) || (pac == ACTION_RESIZE_CORNER || pac == ACTION_RESIZE_SIDE) && (n.client.state == STATE_TILED)
		f = first_extrema(loc.desktop.root)
		while f
			if f = n || !f.client || !is_tiled(f.client)
				next
			end
			r = f.client.tiled_rectangle
			f = next_leaf(f, loc.desktop.root)
		end
	end
end
