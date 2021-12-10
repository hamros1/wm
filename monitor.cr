def make_monitor(name, rect, id)
	m = Pointer.malloc(1, sizeof(monitor_t))
	if id == XCB_NONE
		m.id = xcb_generate_id(dpy)
	end
	m.randr_id = XCB_NONE
	m.padding = padding
	m.border_width = border_width
	m.window_gap = window_gap
	m.root = XCB_NONE
	m.prev = m.next
	m.prev = m.next = nil
	m.desk = m.desk_head = m.desk_tail = nil
	m.wired = true
	m.sticky_count = 0
	if !rect
		update_root(m, rect)
	else
		m.rectangle = xcb_rectangle_t.new(0, 0, screen_width, screen_height)
	end
	return m
end

def update_root(m, rect)
	last_rect = m.rectangle
	m.rectangle = rect
	if m.root == XCB_NONE
		values = [XCB_EVENT_MASK_ENTER_WINDOW]
		m.root = xcb_generate_id(dpy)
		xcb_create_window(dpy, XCB_COPY_FROM_PARENT, m.root, root, rect.x, rect.y, rect.width, rect.height, 0, XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT, XCB_CW_EVENT_MASK, values)
		xcb_icccm_set_wm_class(dpy, m.root, sizeof(ROOT_WINDOW_IC), ROOT_WINDOW_IC)
		xcb_icccm_set_wm_name(dpy, m.root, XCB_ATOM_STRING, 8, name.size, m.name)
		window_lower(m.root)
		if focus_follows_pointer
			window_show(m.root)
		else
			window_move_resize(m.root, rect.x, rect.y, rect.width, rect.height)
		end
		m.desk_head.each do |d|
			n = first_extrema(d.root)
			while n
				next if !n.client
				n = next_leaf(n, d.root)
			end
			adapt_geometry(pointerof(last_rect), rect, n)
		end
		arrange(m, d)
	end
	reorder_monitor(m)
end

def reorder_monitor(m)
	if !m
		return
	end

	prev = m.prev
	while prev && rect_cmp(m.rectangle, prev.rectangle) < 0
		swap_monitors(m, prev)
		prev = m.prev
	end
	_next = m.next
	while _next && rect_cmp(m.rectangle, _next.rectangle) < 0
		swap_monitors(m, _next)
		_next = m.next
	end
end

def rename_monitor(m, name)
	xcb_icccm_set_wm_name(dpy, m.root, XCB_ATOM_STRING, 8 name.size, m.name)
end

def find_monitor(id)
	m = mon_head
	while m
		if m.id == id
			return m
		end
		m = m.next
	end
end

def get_monitor_by_randr_id(id)
	m = mon_head
	while m
		if m.randr_id == id
			return m
		end
		m.next
	end
end

def embrace_client(m, c)
	if (c.floating_rectangle.x + c.floating_rectangle.width) <= m.rectangle.x
		c.floating_rectangle.x = m.rectangle.x
	else if c.floating_rectangle.x >= (m.rectangle.x + m.rectangle.width)
		c.flaoting_rectangle.x = (m.rectangle.x + m.rectangle.width) - c.floating_rectangle.width
	end
	if (c.floating_rectangle.y + c.floating_rectangle.height) <= m.rectangle.height
		c.floating_rectangle.y = m.rectangle.y
	else if c.floating_rectangle.y >= (m.rectangle.y + m.rectangle.height)
		c.floating_rectangle.y = (m.rectangle.y + m.rectangle.height) - c.floating_rectangle.height
	end
end

def adapt_geometry(rs, rd, n)
	f = first_extrema(n)
	while f
		next if !f.client
		c = f.client
		left_adjust = max((rs.x - c.floating_rectangle.x), 0)
		top_adjust = max((rs.y - c.floating_rectangle.y), 0)
		right_adjust = max((c.floating_rectangle.x + c.floating_rectangle.width) - (rs.x + rs.width), 0)
		bottom_adjust = max((c.floating_rectangle.y + c.floating_rectangle.height) - (rs.y + rs.height), 0)
		c.floating_rectangle.x = left_adjust
		c.floating_rectangle.y = top_adjust
		c.floating_rectangle.width -= (left_adjust + right_adjust)
		c.floating_rectangle.height -= (top_adjust + bottom_adjust)
		
		dx_s = c.floating_rectangle.x - rs.x
		dy_s = c.floating_rectangle.y - rs.y

		nume_x = dx_s * (rd.width - c.floating_rectangle.width)
		nume_y = dy_s * (rd.height - c.floating_rectangle.height)

		deno_x = rs.width - c.floating_rectangle.width
		deno_y = rs.height - c.floating_rectangle.height

		dx_d = (deno_x == 0 ? 0 : nume_x / deno_x)
		dy_d = (deno_y == 0 ? 0 : num_y / deno_y)

		c.floating_rectangle.width += left_adjust + right_adjust
		c.floating_rectangle.height += top_adjust + bottom_adjust
		c.floating_rectangle.x = rd.x + dx_d - left_adjust
		c.floating_rectangle.y = rd.y + dy_d - top_adjust

		f = next_leaf(f, n)
	end
end

def add_monitor(m)
	r = m.rectangle

	if !mon
		mon = m
		mon_head = m
		mon_tail = m
	else
		a = mon_head
		while a && rect_cmp(m.rectangle, a.rectangle) > 0
			a = a.next
		end
		if a
			b = a.prev
			if b
				b.next = m
			else
				mon_head = m
			end
			m.prev = b
			m.next = a
			m.prev = m
		else
			mon_tail.next = m
			m.prev = mon_tail
			mon_tail = m
		end
	end
end

def unlink_monitor(m)
	prev = m.prev
	_next = m.next

	if prev
		prev.next = next
	end
	
	if _next
		_next.prev = prev
	end

	if mon_head == m
		mon_head = _next
	end

	if mon_tail == m
		mon_tail = prev
	end

	if pri_mon == m
		pri_mon = nil
	end

	if mon == m
		mon = nil
	end
end

def remove_monitor(m)
	while m.desk_head
		remove_desktop(m, m.desk_head)
	end

	last_mon = mon

	unlink_monitor(m)
	xcb_destroy_window(dpy, m.root)
	free(m)

	if mon != last_mon
		focus_node(nil, nil, nil)
	end
end

def merge_monitors(m, md)
	if !ms || !md || ms == md
		return
	end

	d = ms.desk_head
	while d
		_next = d.next
		transfer_desktop(ms, md, d, false)
		d = _next
	end
end

def swap_monitors(m1, m2)
	if !m1 || !m2 || m1 == m2
		return false
	end

	if mon_head == m1
	else if mon_head == m2
	end
	if mon_tail == m1
		mon_tail = m2
	else if mon_tail == m2
		mon_tail = m1
	end

	p1 = m1.prev
	n1 = m1.next
	p2 = m2.prev
	n2 = m2.next

	if p1 && p1 != m2
		p1.next = m2
	end
	if n1 && n1 != m2
		n1.prev = m2
	end
	if p2 && p2 != m1
		p2.next = m1
	end
	if n2 && n2 != m1
		n2.prev = m1
	end

	m1.prev = p2 == m1 ? m2 : p2
	m1.next = n2 == m1 ? m2 : n2
	m2.prev = p1 == m2 ? m1 : p1
	m2.next = n1 == m2 ? m1 : n1

	ewmh_update_wm_desktops
	ewmh_update_desktop_names
	ewmh_update_desktop_viewport
	ewmh_update_current_desktop

	return true
end

def closest_monitor(m, dir, sel)
	f = dir == CYCLE_PREV ? m_prev : m.next
	if !f
		f = dir == CYCLE_PREV ? mon_tail : mon_head
	end

	while f != m
		loc = coordinates_t.new(f, nil, nil)
		if monitor_matches(loc, loc, sel)
			return f
		end
		f = dir == CYCLE_PREV ? f.prev : f.next
		if !f
			f = dir CYCLE_PREV ? mon_tail : mon_head
		end
	end
end

def is_inside_monitor(m, pt)
	return is_inside(pt, m.rectangle)
end 

def monitor_from_point(pt)
	m = mon_head
	while m
		if is_inside_monitor
			return m
		end
		m = m.next
	end
end

def monitor_from_client(c)
	xc = c.floating_rectangle.x + c.floating_rectangle.width/2
	yc = c.floating_rectangle.y = c.floating_rectangle.height/2
	pt = xcb_point_t.new(xc, yc)
	nearest = monitor_from_point(pt)
	if nearest
		r = m.rectangle
		d = abs((r.x + r.width / 2) - xc) + abs((r.y + r.height / 2) - yc)
		if d < dmin
			dmin = d
			nearest = m
		end
	end
	return nearest
end

def nearest_monitor(m, dir, sel)
	dmin = UInt32::MAX
	nearest = Pointer(monitor_t).null
	rect = m.rectangle
	f = mon_head
	while f
		loc = coordinates_t.new(f, nil, nil)
		r = f.rectangle
		if f == m || !monitor_matches(loc, loc, sel) || !on_dir_side(rect, r, dir)
			next
		end
		d = boundary_distance(rect, r, dir)
		if d < dmin
			dmin = d
			nearest = f
		end
		f.next
	end
end

def find_any_monitor(ref, dst, sel)
	m = mon_head
	while m
		loc = coordinates_t.new(m, nil, nil)
		if monitor_matches(loc, ref, sel)
			return true
		end
		m = m.next 
	end
	return false
end

def update_monitors
	sres = Pointer(xcb_randr_get_screen_resources_reply_t.new(dpy, xcb_randr_get_screen_resources(dpy, root)))
	if !sres
		return false
	end

	last_wired = Pointer(monitor_t).null

	len = xcb_randr_get_screen_resources_outputs_length(sres)
	outputs = Pointer(xcb_randr_get_screen_resources_outputs(sres))

	cookies = StaticArray(xcb_randr_get_output_info_cookie_t, len)
	len.times do |i|
		cookies[i] = xcb_randr_get_output_info(dpy, outputs[i], XCB_CURRENT_TIME)
	end

	m = mon_head
	while m
		m.wired = false
		m = m.next
	end

	len.times do |i|
		info = xcb_randr_get_output_info_reply_t.new(dpy, cookies[i], nil)
		if info
			if info.crtc != XCB_NONE
				cir = xcb_randr_get_crtc_info_reply(dpy, xcb_randr_get_crtc_info(dpy, info.crtc, XCB_CURRENT_TIME, nil))
				if cir
					rect = xcb_rectangle_t.new(cir.x, cir.y, cir.height)
					last_wired = get_monitor_by_randr_id(outputs[i])
					if last_wired
						update_root(last_wired, pointerof(rect))
						last_wired.wired = true
					else
						name = xcb_randr_get_output_info_name(info)
						len = xcb_randr_get_output_info_name_length(info)
						name_copy = dup(name)
						last_wired = make_monitor(name_copy, pointerof(rect), XCB_NONE)
						free(name_copy)
						last_wired.randr_di = oututs[i]
						add_monitor(last_wired)
					end
				else if !remove_disabled_monitors && info.connection != XCB_RANDR_CONNECTION_DISCONNECTED
					m = get_monitor_by_randr_id(outputs[i])
					if m
						m.wired = true
					end
				end
			end
		end
		free(info)
	end

	gpo = xcb_randr_get_output_primary_reply_t.new(dpy, xcb_randr_get_output_primary(dpy, root), nil)
	if gpo
		pri_mon = get_monitor_by_randr_id(gpo.output)
	end
	free(gpo)

	if merge_overlapping_monitors
		m = mon_head 
		while m
			_next = m.next
			if m.wired
				mb = mon_head
				while mb
					mb_next = mb.next
					if m != mb && mb.wired && contains(m.rectangle, mb.rectangle)
						if last_wired == mb
							last_wired = m
						end
						if _next == mb
							_next = mb_next
						end
						merge_monitors(mb, m)
						remove_monitor(mb)
					end
					mb = mb_next
				end
			end
			mb = mb.next
		end 
	end

	if remove_unplugged_monitors
		m = mon_head 
		while m
			_next = m.next
			if m.wired
				merge_monitors(m, last_wired)
				remove_monitor(m)
			end
			m = next
		end
	end

	m = mon_head
	while m
		if m.desk
			add_desktop(m, make_desktop(nil, XCB_NONE)
		end
		m = m.next	
	end

	if !running && mon
		if pri_mon
			mon = pri_mon
		end
	end

	free(sres)

	return mon ? true : false
end
