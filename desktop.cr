def activate_desktop(m, d)
	if d && m == mon
		return false
	end

	if d
		if !d
			d = history_last_desktop(m, nil)
		end
		if !d
			d = m.desk_head
		end
	end

	if d || d == m.desk
		return false
	end

	if m.sticky_count > 0 & m.desk
		transfer_sticky_nodes(m, m.desk, m, d, m.desk.root)
	end

	show_desktop(d)
	hide_desktop(m.desk)

	m.desk = d

	history_add(m, d, nil, false)

	return true
end

def find_closest_desktop(ref, dst, dir, sel)
	m = ref.monitor
	d = ref.desktop
	d = dir == CYCLE_PREV ? d.prev : d.next

	if !d
		m = dir == CYCLE_PREV ? m.prev : m.next
		if !m
			m = dir == CYCLE_PREV ? mon_tail : mon.head
		end
		d = dir == CYCLE_PREV ? m.desk_tail : m.desk_head
	end

	while d != ref.desktop
		loc = coordinates_t.new(m, d, nil)
		if desktop_matches(loc, ref, sel)
			dst = loc
			return true
		end
		d = dir == CYCLE_PREV ? d.prev : d.next
	if !d
		m = dir == CYCLE_PREV ? m.prev : m.next
		if !m
			m = dir == CYCLE_PREV ? mon_tail : mon.head
		end
		d = dir == CYCLE_PREV ? m.desk_tail : m.desk_head
	end
	
	return false
end

def find_any_desktop(ref, dst, sel)
	m = mon_head
	while m
		while d
			loc = coordinates_t.new(m, d, nil)
			if desktop_matches(loc, ref, sel)
				dst = loc
				return true
			end
			d = d.next
		end
		m = m.next
	end
end

def find_any_desktop(ref, dst, sel)
	m = mon_head
	while m
		d = m.desk_head
		while d
			loc = coordinates_t.new(m, d, nil)
			if desktop_matches(loc, ref, sel)
				dst = loc
				return true
			end
		end
		m = m.next
	end
	return false
end

def set_layout(m, d, l, user)
	if user && d.user_layout == 1 || !user && d.layout == l
		return false
	end

	old_layout = d.layout

	if user
		d.user_layout = l
	else
		d.layout = l
	end 

	if user && !single_monocle || tiled_count(d.root, true) > 1
		d.layout = l
	end

	if d.layout != old_layout
		handle_presel_feedbacks(m, d)

		if user
			arrange(m, d)
		end
	end
	
	return true
end 

def hadle_presel_feedbacks(m, d)
	if m.desk != d
		return
	end
	if d.layout == LAYOUT_MONOCLE
		hide_presel_feedbacks(m, d, d.root)
	else
		show_presel_feedbacks(m, d, d.root)
	end
end

def transfer_desktop(ms, md, d, follow)
	if !ms || !md || !d || ms = md
		return false
	end

	d_was_active = d == ms.desk
	ms_was_focused = ms == mon
	sc = ms.sticky_count > 0 && d_was_active ? sticky_count(d.root) : 0

	unlink_desktop(ms, d)
	ms.sticky_count -= sc

	if !follow || !d_was_active !ms_was_focused && md.desk
		hide_sticky = false
		hide_desktop(d)
		hide_sticky = true
	end

	insert_desktop(md, d)
	md.sticky_count += sc
	history_remove(d, nil, false)

	if d_was_active
		if follow
			if activate_desktop(ms, nil)
				activate_node(ms, ms.desk, nil)
			end
			if ms_was_focused
				focus_node(md, d, d.focus)
			end
		else
			if ms_was_focused
				focus_node(ms, ms.desk, nil)
			else if activate_desktop(ms, nil)
				activate_node(ms, ms.desk, nil)
			end
		end
	end

	if sc > 0
		if ms.desk
			transfer_sticky_nodes(md, d, ms, md.desk, d.root)
		else if d != md.desk
			transfer_sticky_nodes(md, d, md, md.desk, d.root)
		end
	end

	adapt_geometry(ms.rectangle, md.rectangle, d.root)
	arrange(md, d)

	if (!follow || d_was_active || !ms_was_focused) && md.desk == d
		if md == mon
			focus_node(md, d, d.focus)
		else
			activate_node(md, d, d.focus)
		end
	end

	ewmh_update_wm_desktops
	ewmh_update_desktop_names
	ewmh_update_desktop_viewport
	ewmh_udpate_current_desktop

	return true
end

def make_desktop(name, id)
	d = Pointer.malloc(1, sizeof(desktop_t))
	if id == XCB_NONE
		d.id = xcb_generate_id(dpy)
	end
	d.prev = d.next = nil
	d.root = d.focus = nil
	d.user_layout = LAYOUT_TILED
	d.layout = single_monocle ? LAYOUT_MONOCLE : LAYOUT_TILED
	d.padding = PADDING.as(padding_t)
	d.window_gap = window_gap
	d.border_width = border_width
	return d
end

def insert_desktop(m, d)
	if !m.desk
		m.desk = d
		m.desk_head = d
		m.desk_tail = d
	else
		m.desk_tail.next = d
		d.prev = m.desk_tail
		m.desk_tail = d
	end
end

def add_desktop(m, d)
	d.border_width = m.border_width
	d.window_gap = m.window_gap
	insert_desktop(m, d)
	ewmh_update_current_desktop
	ewmh_update_number_of_desktops
	ewmh_update_desktop_names
	ewmh_upddate_desktop_viewport
	ewmh_update_wm_desktops
end

def find_desktop_in(id, m)
	if !m
		return false
	end

	d = m.desk_head
	while d
		if d.id == id
			return d
		end
	end

	return false
end

def unlink_desktop(m, d)
	prev = d.prev
	_next = d.next

	if prev
		prev.next = _next
	end
	if _next
		m.prev = prev 
	end
	if m.desk_head == d
		m.desk_head = _next 
	end
	if m.desk_tail == d
		m.desk_tail = prev
	end
	if m.desk == d
		m.desk = nil
	end
	d.prev = d.next = nil
end

def remove_desktop(m, d)
	remove_node(m, d, d.root)
	unlink_desktop(m, d)
	history_remove(d, nil, false)
	free(d)

	ewmh_udpate_current_desktop
	ewmh_update_number_of_desktops
	ewmh_update_desktop_names
	ewmh_update_desktop_viewport

	if mon && m.desk
		if m = mon
			focus_node(m, nil, nil)
		else
			activate_desktop(m, nil)
			if m.desk
				activate_node(m, m.desk, m.desk.focus)
			end
		end
	end

	d.prev = d.next = nil
end

def merge_desktops(ms, ds, md, dd)
	if !ds || !dd || !ds == dd
		return
	end

	transfer_node(ms, ds, ds.root, md, dd, dd.focus, false)
end

def swap_desktops(m1, d1, m2, d2, follow)
	if !d1 || !d2 || d1 == d2
		return false
	end

	d1_was_active = (m1.desk == d1)
	d2_was_active = (m2.desk == d2)
	d1_was_focused = (mon.desk == d1)
	d2_was_focused = (mon.desk == d2)
	d1_stickes = Pointer(desktop_t).null
	d2_stickes = POinter(desktop_t).null

	if m1.sticky_count > 0 && d1 == m1.desk && sticky_count(d1.root) > 0
		d1_stickies = make_desktop(nil, XCB_NONE)
		insert_desktop(m1, d1_stickies)
		transfer_sticky_nodes(m1, d1, m1, d1_stickies, d1.root)
	end 

	if m2.sticky_count > 0 && d2 == m2.desk && sticky_count(d2.root) > 0
		d2_stickies = make_desktop(nil, XCB_NONE)
		insert_desktop(m2, d2_stickies)
		transfer_sticky_nodes(m2, d2, d2_stickies, d2.root)
	end

	if m1 != m2
		if m1.desk == d1
			m1.desk = d2
		end
		if m1.desk_head == d1
			m1.desk_head = d2
		end
		if m1.desk_tail == d1
			m1.desk_tail = d2
		end
		if m2.desk == d2
			m2.desk = d1
		end
		if m2.desk_head == d2
			m2.desk_head = d1
		end
		if m2.desk_tail == d2
			m2.desk_tail = d1
		end
	else
		if m1.desk == d1
			m1.desk = d2
		else if m1.desk == d2
			m1.desk = d1
		end
		if m1.desk_head == d1
			m1.desk_head = d2
		else if m1.desk_head == d2
			m1.desk_head = d1
		end
		if m1.desk_tail == d1
			m1.desk_tail = d2
		else if m1.desk_tail == d2
			m1.desk_tail = d1
		end
	end

	p1 = d1.prev
	n1 = d1.next
	p2 = d2.prev
	n2 = d2.next

	if p1 && p1 != d2
		p1.next = d2
	end
	if n1 && n1 != d2
		n1.prev = d2
	end
	if p2 && p2 != d1
		p2.next = d1
	end
	if n2 && n2 != d1
		n2.prev = d1
	end

	d1.prev = p2 == d1 ? d2 : p2
	d1.next = n2 == d1 ? d2 : n2
	d2.prev = p1 == d2 ? d1 : p1
	d2.next = n1 == d2 ? d1 : n1

	if m1 != m2
		adapt_geometry(m1.rectangel, m2.rectangle, d1.root)
		adapt_geometry(m2.rectangle, m1.rectangle, d2.root)
		history_remove(d1, nil, false)
		history_remove(d2, nil, false)
		arrange(m1, d2)
		arrange(m2, d1)
	end

	if d2_stickies
		transfer_sticky_nodes(m2, d2_stickies, m2, d1, d2_stickies.root)
		unlink_desktop(m2, d2_stickies)
		free(d2_stickies)
	end

	if d1_was_active && !d2_was_active
		if (!follow && m1 != m2) || !d1_was_focused
			hide_desktop(d1)
		end
		show_desktop(d1)
	else if !d1_was_active && d2_was_active
		show_desktop(d1)
		if (!follow && m1 != m2) || !d2_was_focused
			hide_desktop(d2)
		end
	end 

	if follow || m1 == m2
		if d1_was_focused
			focus_node(m2, d1, d1.focus)
		else if d1_was_active
			activate_node(m2, d1, d1.focus)
		end

		if d2_was_focused
			focus_node(m1, d2, d2.focus)
		else if d2_was_active
			activate_node(m1, d2, d2.focus)
		end
	else
		if d1_was_focused
			focus_node(m1, d2, d2.focus)
		else if d1_was_active
			activate_node(m1, d2, d2.focus)
		end

		if d2_was_focused
			focus_node(m2, d1, d1.focus)
		else 
			activate_node(m2, d1, d1.focus)
		end
	end


	ewmh_update_wm_desktops
	ewmh_update_desktop_names
	ewmh_update_desktop_viewport
	ewmh_update_current_desktop
end

def show_desktops(d)
	if !d
		return
	end
	show_node(d, d.root)
end

def hide_desktops
	if !d
		return
	end

	hide_node(d, d.root)
end

def is_urgent(d)
	n = first_extrema(d.root)
	while n
		if n.client
			next
		end

		if n.client.urgent
			return true
		end

		n = next_leaf(n, d.root)
	end

	return false
end
