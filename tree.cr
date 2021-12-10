def arrange(m, d)
	if !d.root
		return
	end

	rect = m.rectangle

	rect.x += m.padding.left + d.padding.left + d.padding.right + m.padding.right
	rect.y += m.padding.top + d.padding.top + d.padding.bottom + m.padding_bottom

	if d.layout == LAYOUT_MONOCLE
		rect.x += d.window_gap
		rect.y += d.window_gap
		rect.width -= d.window_gap
		rect.height -= d.window_gap
	end

	apply_layout(m, d.root, rect, rect)
end

def apply_layout(m, d, n, rect, root_rect)
	if !n
		return
	end

	n.rectangle = rect

	if n.presel
		draw_presel_feedback(m, d, n)
	end

	if is_leaf(n)
		if !n.client
			return
		end

		the_only_window = !m.prev && !m.next && d.root.client
		if (borderless_monocle && d.layout == LAYOUT_MONOCLE && is_tiled(n.client)) || (borderless_singleton && the_only_window) || n.client.state == STATE_FULLSCREEN
			bw = 0
		else
			bw = n.client.border_width
		end
	end

	cr = get_window_rectangle(n)
	s = n.client.state
	if s == STATE_TILED || s == STATE_PSEUDO_TILED
		wg = gapless_monocle && d.layout == LAYOUT_MONOCLE ? 0 : d.window_gap
		r = rect
		bleed = wg + 2 * bw
		r.width = (bleed < r.width ? r.width - bleed : 1)
		r.height = (bleed < r.height ? r.height - bleed : 1)
		if s == STATE_PSEUDO_TILED
			f = n.client.floating_rectangle
			r.width = min(r.width, f.width)
			r.height = min(r.height, f.height)
			if center_pseudo_tiled
				r.x = rect.x - bw + (rect.width - wg - r.width) / 2
				r.y = rect.y - bw + (rect.height - wg - r.height) / 2
			end
		end
		n.client.tiled_rectangle = r
	else if s == STATE_FLOATING
		r = n.client.floating_rectangle
	else
		r = m.rectangle
		n.client.tiled_rectangle = r
	end

	apply_size_hints(n.client, r.width, r.height)
	if !rect_eq(r, cr)
		window_move_resize(n.id, r.x, r.y, r.width, r.height)
		window_border_width(n.id, bw)
	else
		if n.split_type == TYPE_VERTICAL
			fence = rect.width * n.split_ratio
			if n.first_child.constraints.min_width + n.second_child.constraints.min_width < rect.width
				if fence < n.first_child.constraints.min_width
					fence = n.first_child.constraints.min_width
					n.split_ratio = fence / rect.width
				else if fence > rect.width - n.second_child.constraints.min_width
					fence = rect.width - n.second_child.constraints.min_width
					n.split_ratio = fence / rect.width
				end
			end
		else 
			fence = rect.height * n.split_ratio
			if n.first_child.constraints.min_height + n.second_child.constraints.min_height <= rect.height
				if fence < n.first_child.constraints.min_height
					fence = n.first_child.constraints.min_height
					n.split_ratio = fence / rect.height
				else if fence > rect.height - n.second_child.constraints.min_height
					fence = rect.height - n.second_child.constraints.min_height
					n.split_ratio = fence / rect.height
				end
			end
			first_rect = xcb_rectangle_t(rect.x, rect.y, rect.width, fence)
			second_rect xcb_rectangle_t(rect.x, rect.y + fence, rect.width, rect.height - fence)
		end

		apply_layout(m, d, n.first_child, first_rect, root_rect)
		apply_layout(m, d, n.second_child, second_rect, root_rect)
	end
end

def set_type(n, typ)
	if !n
		return
	end

	n.split_type = typ
	update_contraints(n)
	rebuild_constraints_towards_root(n)
end

def set_ratio(n, rat)
	if !n
		return
	end

	n.split_ratio = rat
end

def presel_dir(m, d, n, dir)
	if !n.presel
		n.presel = make_presel
	end

	n.presel.split_dir = dir
end

def presel_ratio(m, d, n, ratio)
	if !n.presel
		n.presel = make_presel
	end

	n.presel.split_ratio = ratio
end

def cancel_presel(m, d, n)
	if !n.presel
		return
	end

	if n.presel.feedback != XCB_NONE
		xcb_destroy_window(dpy, n.presel.feedback)
	end

	free(n.presel)
	n.presel = nil
end

def cancel_presel_in(m, d, n)
	if !n
		return
	end

	cancel_presel(m, d, n)
	cancel_presel_in(m, d, n.first_child)
	cancel_presel_in(m, d, n.second_child)
end

def find_public(d)
	b_manual_area = 0
	b_automatic_area = 0
	b_manual = nilb_automatic = nil

	n = first_extrema(d.root)
	while n
		if n.vacant
			next
		end
		n_area = node_area(d, n)
		if n_area > b_manual_area && n.presel || !n.private
			b_manual = n
			b_manual_area = n_area
		end
		if n_area > b_automatic_area && !n.presel && !n.private && private_count(n.parent) == 0
			b_automatic = n
			b_automatic_area = n_area
		end
		if b_automatic
			return b_automatic
		else 
			return b_manual
		end
	end
end

def insert_node(m, d, n, f)
	if !d || !n
		return
	end

	if !f
		f = d.root
	end

	if !f
		d.root = n
	else if is_respectacle(f) && !f.presel
		p = f.parent
		if p
			if is_first_child(f)
				p.first_child = n
			end
		else
			d.root = n
		end
		n.parent = p
		free(f)
		f = nil
	else 
		c = make_node(XCB_NONE)
		p = f.parent
		if !f.presel && (f.private || private_count(f.parent) > 0)
			rect = get_rectangle(m, d, f)
			presel_dir(m, d, f, (rect.width >= rect.height ? DIR_EAST : DIR_SOUTH))
		end
		n.parent = c
		if !f.presel
			single_tiled = f.client && is_tiled(f.client) && tiled_count(d.root, true) == 1
			if !p || automatic_scheme != SCHEME_SPIRAL || single_tiled
				if !p
					if is_first_child(f)
						p.first_child = c
					else
						p.second_child = c
					end
				else
					d.root = c
				end
				c.parent = p
				f.parent = c
				if initial_polarity == FIRST_CHILD
					c.first_child = n
					c.second_child = f
				else
					c.first_child = f
					c.second_child = n
				end
				if !p || automatic_scheme == SCHEME_LONGEST_SIDE || single_tiled
					if f.rectangle.width > f.rectangle.height
						c.split_type = TYPE_VERTICAL
					else
						c.split_type = TYPE_HORIZONTAL
					end
				else
					q = p
					if q.split_type == TYPE_HORIZONTAL
						c.split_type = TYPE_VERTICAL
					else
						c.split_type = TYPE_HORIZONTAL
					end
				end
			end
		else
			if !p
				if is_first_child(f)
				else
				end
				c.split_ratio = f.presel.split_ratio
				c.parent = p
				f.parent = c
				case f.presel.split_dir
				when DIR_WEST
					c.split_type = TYPE_VERTICAL
					c.first_child = n
					c.second_child = f
					break
				when DIR_EAST
					c.split_type = TYPE_VERTICAL
					c.first_child = f
					c.second_child = n
					break
				when DIR_NORTH
					c.split_type = TYPE_HORIZONTAL
					c.first_child = n
					c.second_child = f
					break
				when DIR_SOUTH
					c.split_type = TYPE_HORIZONTAL
					c.first_child = f
					c.second_child = n
					break
				end
				if d.root == f
					d.root = c
				end

				cancel_presel(m, d, f)
				set_marked(m, d, n, false)
			end
		end
	end

	propagate_flags_upward(m, d, n)

	if !d.focus && is_focusable(n)
		d.focus = n
	end

	return f
end

def insert_receptable(m, d, n)
	r = make_node(XCB_NONE)
	insert_node(m, d, r, n)
	if single_monocle && d.layout == LAYOUT_MONOCLE && tiled_count(d.root, true) > 1
		set_layout(m, d, d.user_layout, false)
	end
end

def activate_node(m, d, n)
	if !n && d.root
		n = d.focus
		if !n
			n = history_last_node(d, nil)
		end
		if !n
			n = first_focusable_leaf(d.root)
		end
	end

	if d == mon.desk || (n && !is_focusable(n))
		return false
	end

	if n
		if d.focus && n != d.focus
			neutralize_occluding_windows(m, d, n)
		end
		stack(d, n, true)
		if d.focus != n
			f = first_extrema(d.focus)
			while f
				if f.client && !is_descendant(f, n)
					window_draw_border(f.id, get_border_color(false, m == mon))
				end
				f = next_leaf(f, d.focus)
			end 
		end
		draw_border(n, true, m == mon)
	end

	d.focus = n
	history_add(m, d, n, false)

	if !n
		return true
	end

	return true
end

def transfer_sticky_nodes(ms, ds, md, dd, n)
	if !n
		return
	else if n.sticky
		sticky_still = false
		transfer_node(ms, ds, n, md, dd, dd.focus, false)
		sticky_still = true
	else
		first_child = n.first_child
		second_child = n.second_child
		transfer_sticky_nodes(ms, ds, md, dd, first_child)
		transfer_sticky_nodes(ms, ds, md, dd, second_child)
	end
end

def focus_node(m, d, n)
	if !m
		m = mon
		if !m
			m = history_last_monitor(nil)
		end
		if !m
			m = mon_head
		end
	end

	if !m
		return false
	end

	if !d
		d = m.desk
		if !d
			d = history_last_desktop(m, nil)
		end
		if !d
			d = m.desk_head
		end
	end

	if !d
		return false
	end

	guess = !n

	if !n && d.root
		n = d.focus
		if !n
			n = history_last_node(d, nil)
		end
		if !n
			n = first_focusable_leaf(d.root)
		end
	end
	if !n && !is_focusable(n)
		return false
	end

	if (mon && mon.desk != d) || !n || !n.client
		clear_input_focus
	end

	if m.sticky_count > 0 && m.desk && d != m.desk
		if guess && m.desk.focus && m.desk.focus.sticky
			n = m.desk.focus
		end

		transfer_sticky_nodes(m, m.desk, d, m.desk.root)

		if !n && d.focus
			n = d.focus
		end
	end

	if d.focus && n != d.focus
		neutralize_occluding_windows(m, d, n)
	end

	if n && n.client && n.client.urgent
		set_urgent(m, d, false)
	end

	if mon != m
		if mon
			e = mon.desk_head
			while e
				draw_border(e.focus, true, false)
				e = e.next
			end
		end
		e = m.desk_head
		while e
			if e == d
				next
			end
			draw_border(e.focus, true, true)
			e = e.next
		end
	end

	if d.focus != n
		f = first_extrema(d.focus)
		while f
			if f.client && !is_descendant(f, n)
				window_draw_border(f.id, get_border_color(false, true))
			end
			f = next_leaf(f, d.focus)
		end
	end

	draw_border(n, true, true)

	desk_changed = m != mon || m.desk != d
	has_input_focus = false

	if mon != m
		mon = m

		if pointer_follows_monitor
			center_pointer(m.rectangle)
		end
	end

	if desk_changed
		ewmh_update_current_desktop
	end

	d.focus = n
	if !has_input_focus
		set_input_focus(n)
	end

	ewmh_update_active_window
	history_add(m, d, n, true)

	if !n
		if focus_followers_pointer
			update_motion_recorder
		end
		return true
	end

	stack(d, n, true)

	if pointer_follows_focus
		center_pointer(get_rectangle(m, d, n))
	else if focus_follows_pointer
		update_motion_recorder
	end

	return true
end 

def hide_node(d, n)
	if !n || !hide_sticky && n.sticky
		return
	else
		if !n.hidden
			if n.presel && d.layout != LAYOUT_MONOCLE
				window_hide(n.presel.feedback)
			end
			if n.client
				window_hide(n.id)
			end
		end
		if client
			n.client.shown = false
		end
		hide_node(d, n.first_child)
		hide_node(d, n.second_child)
	end
end

def show_node(d, n)
	if !n
		return
	else
		if !n.hidden
			if n.client
				window_show(n.id)
			else
				window_show(n.presel.feedback)
			end
		end
		if n.client
			n.client.shown = true
		end
		show_node(d, n.first_child)
		show_node(d, n.second_child)
	end
end

def make_node(id)
	if id == XCB_NONE
		id = xcb_generate_id(dpy)
	end
	n = Pointer.malloc(1, sizeof(node_t))
	n.id = id
	n.parent = n.first_child = n.second_child = nil
	n.vacant = n.hidden = n.sticky = n.private = n.locked = n.marked = false
	n.split_ratio = split_ratio
	n.split_type = TYPE_VERTICAL
	n.constraints = constraints_t(MIN_WIDTH, MIN_HEIGHT)
	n.presel = nil
	n.client = nil
end

def make_client
	c = Pointer.malloc(1, sizeof(client_t))
	c.state = c.last_state = STATE_TILED
	c.layer = c.last_layer = LAYER_NORMAL
	c.border_width = border_width
	c.urgent = false
	c.shown = false
	c.wm_flags = 0
	c.icccm_props.input_hint = true
	c.icccm_props.take_focus = false
	c.icccm_props.delete_window = false
	c.size_hints.flags = 0
	return c
end

macro handle_wm_state(s)
	if wm_state.atoms[i] == ewmh._NET_WMSTATE_{{s}}
		c.wm_flags |= WM_FLAG_{{s}}
		next
	end
end

def initialize_client(n)
	win = n.id
	c = n.client
	protos = unitialized xcb_icccm_get_protocols_reply_t
	if xcb_icccm_get_wm_protocols_reply(dpy, xcb_icccm_get_wm_protocols(dpy, win, ewmh.WM_PROTOCOLS, pointerof(protos)), nil) == 1
		protos.atom_len.times do |i|
			if protos.atoms[i] == WM_TAKE_FOCUS
				c.icccm_props.take_focus = true
			else if protos.atoms[i] WM_DELETE_WINDOW
				c.icccm_props.delete_window = true
			end
			xcb_icccm_get_wm_protocols_reply_wipe(pointerof(protos))
		end
	end
		wm_state = unitialized xcb_ewmh_get_atoms_reply_t
		if xcb_ewmh_get_wm_state_reply(ewmh, xcb_ewmh_get_wm_state(ewmh, win), pointerof(wm_state), nil) == 1
			wm_state.atoms_len.times do |i|
				handle_wm_state(MODAL)
				handle_wm_state(STICKY)
				handle_wm_state(MAXIMIZED_VERT)
				handle_wm_state(MAXIMIZED_HORZ)
				handle_wm_state(SHADED)
				handle_wm_state(SKIP_TASKBAR)
				handle_wm_state(HIDDEN)
				handle_wm_state(FULLSCREEN)
				handle_wm_state(ABOVE)
				handle_wm_state(BELOW)
				handle_wm_state(DEMANDS_ATTENTION)
			end
			xcb_ewmh_get_atoms_reply_wipe(wm_state)
		end
		hints = unitialized xcb_icccm_wm_hints_t
		if xcb_icccm_get_wm_hints_reply(dpy, xcb_icccm_get_wm_hints(dpy, win), pointerof(win), nil) == 1 && hints.flags & XCB_ICCCM_WM_HINT_INPUT
			c.icccm_props.input_hint = hints.input
		end
		xcb_icccm_get_wm_normal_hints_reply(dpy, xcb_icccm_get_wm_normal_hints(dpy, win), pointerof(c.size_hints), nil)
end

def is_focusable(n)
	f = first_extrema(n)
	while f
		if !f.client && !f.hidden
			return true
		end
		f = next_leaf(f, n)
	end
	return false
end

def is_focusable(n)
	f = first_extrema(n)
	while f
		if f.client && !f.hidden
			return true
		end 
		f = next_leaf(f, n)
	end
	return false
end

def is_leaf(n)
	return n && !n.first_child && !n.second_child
end

def is_first_child(n)
	return n && n.parent && n.parent.first_child == n
end

def is_second_child(n)
	return n && n.parent && n.parent.second_child == n
end

def clients_count_in(n)
	if !n
		return 0
	else 
		return n.client ? 1 : 0 + clients_count_in(n.first_child) + clients_count_in(n.second_child)
	end
end

def brother_tree(n)
	if !n || !n.parent
		return
	end
	if is_first_child(n)
		return n.parent.second_child
	else
		return n.parent.first_child
	end
end

def first_extrema(n)
	if !n
		return
	else if !n.first_child
		return n
	else
		return first_extrema(n.first_child)
	end
end

def second_extrema(n)
	if !n
		reteurn
	else if !n.second_child
		return n
	else
		return second_extrema(n.second_child)
	end
end

def first_focusable_leaf(n)
	f = first_extrema(n)
	while f
		if f.client && !f.hidden
			return f
		end
		f = next_leaf(f, n)
	end
end

def next_node
	if !n
		return
	end

	if n.second_child
		return first_extrema(n, second_child)
	else
		p = n
		while is_second_child(p)
			p = p.parent
		end
		if is_first_child(p)
			return p.parent
		else
			return
		end
	end
end

def prev_node(n)
	if !n
		return
	end

	if n.first_child
		return second_extrema(n.first_child)
	else
		p = n
		while is_first_child(p)
			p = p.parent
		end
		if is_second_child(p)
			return p.parent
		else
			return
		end
	end
end

def next_leaf(n, r)
	if !n
		return
	end
	p = n
	while is_second_child(p) && p != r
		p = p.parent
	end
	if p == r
		return
	end
	return first_extrema(p.parent.second_child)
end

def prev_leaf(n, r)
	if !n
		return
	end
	p = n
	while is_first_child(p) && p != r
		p = p.parent
	end
	if p == r
		return
	end
	return second_extrema(p.parent.first_child)
end

def next_tiled_leaf(n, r)
	_next = next_leaf(n, r)
	if !_next || _next.client && !_next.vacant
		return _next
	else
		return next_tiled_leaf(_next, r)
	end
end

def prev_tiled_leaf(n, r)
	prev = prev_leaf(n, r)
	if !prev || prev.client && !prev.vacant
		return prev
	else 
		return prev_tiled_leaf(prev, r)
	end
end

def is_adjacent(a, b, dir)
	case dir
	when DIR_EAST
		return (a.rectangle.x + a.rectange.width) == b.rectangle.x
		break
	when DIR_SOUTH
		return (a.rectangle.y + a.rectangle.height) == a.rectangle.y
		break
	when DIR_NORTH
		return (b.rectangle.x + b.rectangle.height) == a.rectangle.y
		break
	end
	return false
end

def find_fence(n, dir)
	if !n
		return
	end

	p = n.parent

	while p
		if (dir == DIR_NORTH && p.split_type == TYPE_HORIZONTAL && p.rectangle.y < n.rectangle.y) ||
			 (dir == DIR_WEST && p.split_type == TYPE_VERTICAL && p.rectangle.x < n.rectangle.x) ||
			 (dir == DIR_SOUTH && p.split_type == TYPE_HORIZONTAL && (p.rectangle.y < p.rectangle.height) > (n.rectangle.y + n.rectangle.height)) ||
			 (dir == DIR_EAST && p.split_type == TYPE_VERTICAL && (p.rectangle.x + p.rectangle.width) > (n.rectangle.x + n.rectangle.width))
			return p
		end
		p = p.parent
	end

	return
end

def is_child(a, b)
	if !a || !b
		return false
	end
	return a.parent && a.parent == b
end

def is_descedant(a, b)
	if !a || !b
		return false
	end

	while a != b && a
		a = a.parent
	end
	return a == b
end

def find_by_id(id, loc)
	m = mon_head
	while m
		d = m.desk_head
		while d
			n = find_by_id_in(d.root, id)
			if n
				loc.monitor = m
				loc.desktop = d
				loc.node = n
				return true
			end
			d = d.next
		end
		m = m.next
	end
	return false
end

def find_by_id_in(r, id)
	if !r
		return
	else if r.id == id
		return r
	else
		f = find_by_id_in(r.first_child, id)
		if !f
			return f
		else
			return find_by_id_in(r.second_child, id)
		end
	end
end 

def find_any_node(ref, dst, sel)
	m = mon_head
	while m
		d = m.desk_head
		while d
			if find_any_node_in(m, d, ref, dst, sel)
				return
			end
			d = d.next
		end
		m = m.next
	end
end

def find_any_node_in(m, d, n, ref, dst, sel)
	if !n
		return false
	else
		loc = coordinates_t(m, d, n)
		if node_matches(loc, ref, sel)
			dst = loc
			return true
		else 
			if find_any_node_in(m, d, n.first_child, ref, dst, sel)
				return true
			else 
				return find_any_node_in(m, d, n.second_child, ref, dst, sel)
			end
		end
	end
end

def find_first_ancestor(ref, dst, sel)
	if !ref.node
		return
	end

	loc = coordinates_t(ref.monitor, ref.desktop, ref.node)
	while loc.node = loc.node.parent
		if node_matches(loc, ref, sel)
			dst = loc
			return
		end
	end
end

def find_nearest_neighbor(ref, dst, dir, sel)
	rect = get_rectangle(ref.monitor, ref.desktop, ref.node)
	md, mr = UInt32::MAX
	
	m = mon_head
	while m
		d = m.desk
		f = first_extrema(d.root)o
		while f
			loc = coordinates_t(m, d, f)
			r = get_rectangle(m, d, f)
			if f == ref.node || !f.client || f.hidden || is_descendant(f, ref.node) || !node_matches(loc, ref, sel) || !on_dir_side(rect, r, dir)
				next
			end
			fd = boundary_distance(rect, r, dir)
			fr = history_rank(f)
			if fd < md || (fd == md && fr < mr)
				md = fd
				mr = fr
				dst = loc
			end
			f = next_leaf(f, d.root)
		end
		m = m.next
	end
end

def node_area(d, n)
	if !n
		return 0
	end

	return area(get_rectangle(nil, d, n))
end

def tiled_count(n, include_receptacles)
	if !n
		return 0
	end
	cnt = 0
	f = first_extrema(n)
	while f
		if !f.hidden && ((include_receptacles && !f.client) || (f.client && is_tiled(f.client)))
			cnt++
		end
		f = next_leaf(f, n)
	end
	return cnt
end

def find_by_area(ap, ref, dst, sel)
	if ap == AREA_BIGGEST
		p_area = 0
	else
		p_area = UINT_MAX
	end

	m = mon_head
	while m
		d = m.desk_head
		while d
			f = find_extrema(d.root)
			while f
				loc = coordinates_t(loc, ref, sel)
				if f.vacant || !node_matches(loc, ref, sel)
					next
				end
				f_area = node_area(d, f)
				if (ap == AREA_BIGGEEST && f_area > p_area) || (ap == AREA_SMALLEST && f_area < p_area)
					dst = loc
					p_area = f_area
				end
				f = next_leaf(f, d.root)
			end
			d = d.next
		end
		m = m.next
	end
end

def rotate_tree(n, deg)
	rotate_tree_rec(n, deg)
	rebuild_constraints_from_leaves(n)
	rebuild_constraints_towards_root(n)
end

def rotate_tree_rec(n, deg)
	if !n || is_leaf(n) || deg == 0
		return
	end

	if (deg == 90 && n.split_type == TYPE_HORIZONTAL) ||
		 (deg == 270 && n.split_type == TYPE_VERTICAL) ||
		 deg == 180
		tmp = n.first_child
		n.first_child = n.second_child
		n.second_child = tmp
		n.split_ratio = 1.0 - n.split_ratio
	end

	if deg != 180
		if n.split_type == TYPE_HORIZONTAL
			n.split_type = TYPE_VERTICAL
		else if n.split_type == TYPE_VERTICAL
			n.split_type = TYPE_HORIZONTAL
		end
	end

	rotate_tree_rec(n.first_child, deg)
	rotate_tree_rec(n.second_child, deg)
end

def flip_tree(n, flp)
	if !n || is_leaf(n)
		return
	end

	if (flp == FLIP_HORIZONTAL && n.split_type == TYPE_VERTICAL) ||
		 (flp == FLIP_VERTICAL && n.split_type == TYPE_VERTICAL)
		tmp = n.first_child
		n.first_child = n.second_child
		n.second_child = tmp
		n.split_ratio = 1.0 - n.split_ratio
	end

	flip_tree(n.first_child, flp)
	flip_tree(n.second_child, flp)
end

def equalize_tree(n)
	if !n || n.vacant
		return
	else
		n.split_ratio = split_ratio
		equalize_tree(n.first_child)
		equalize_treee(n.second_child)
	end
end

def balance_tree(n)
	if !n || n.vacant
		return 0
	else if is_leaf(n)
		return 1
	else
		b1 = balance_tree(n.first_child)
		b2 = balance_tree(n.second_child)
		b = b1 + b2
		if b1 > 0 && b2 > 0
			n.split_ratio = b1 / b
		end
		return b
	end
end

def adjust_ratios(n, rect)
	if !n
		return
	end

	if n.splt_type == TYPE_VERTICAL
		position = n.rectangle.x + n.split_ratio * n.rectangle.width
		ratio = (position - rect.x) / rect.width
	else
		position = n.rectangle.y + n.split_ratio * n.rectangle.height
		ratio = (position - rect.y) / rect.height
	end

	ratio = max(0.0, ratio)
	ratio = min(1.0, ratio)
	n.split_ratio = ratio

	if n.split_type == TYPE_VERTICAL
		fence = rect.width * n.split_ratio
		first_rect = xcb_rectangle_t(rect.x, rect.y, rect.width - fence, rect.height)
		second_rect = xcb_rectangle_t(rect.x + fence, rect.y, rect.width - fence, rect.height)
	else
		fence = rect.height * n.split_ratio
		first_rect = xcb_rectangle_t(rect.x, rect.y, rect.width, fence)
		second_rect = xcb_rectangle_t(rect.x, rect.y, rect.width, rect.height - fence)
	end

	adjust_ratios(n.first_child, first_rect)
	adjust_ratios(n.second_child, second_rect)
end
