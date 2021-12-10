def query_node_ids(mon_ref, desk_ref, ref, trg, mon_sel, desk_sel, sel, rsp)
	count = 0

	m = mon_head
	while m
		loc = coordinates(m, nil, nil)
		if (trg.monitor && m != trg.monitor) || mon.sel && !monitor_matches(loc, mon_ref, mon_sel)
			next
		end
		d = m.desk_head
		while d
			loc = coordinates_t(m, d, nil)
			if (trg.desktop && d != trg.desktop) || (desk_sel && !desktop_matches(loc, desk_ref, desk_sel))
				next
			end
			d = d.next
		end
		count += query_node_ids(d.root, d, m, ref, trg, sel, rsp)
		m = m.next
	end
	return count
end

def query_node_ids_in(n, d, ref, trg, sel)
	count = 0

	if !n
		return
	else
		loc = coordinates_t(m, d, n)
		if (!trg.node || n == trg.node) && (!sel || node_matches(loc, ref, sel))
			count++
		end
		count += query_node_ids_in(n.first_child, d, m, ref, trg, sel, rsp)
		count += query_node_ids__in(n.second_child, d, m, ref, trg, sel, rsp)
	end
	return count
end

def query_desktop_ids(mon_ref, ref, trg, mon_sel, sel, printer)
	count = 0
	
	m = mon_head
	while m
		loc = coordinates_t(m, nil, nil)
		if (trg.monitor && m != trg.monitor) || (mon.sel && !monitor_matches(loc, mon_ref, mon_sel))
			next
		end
		d = m.desk_head
		while d
			loc = coordinates_t(m, d, nil)
			if (trg.desktop && d != trg.desktop) || (sel && !desktop_matches(loc, ref, sel))
				next
			end
			printer(d, rsp)
			count++
			d = m.next
		end
		m = m.next
	end
	return count
end

def query_desktop_ids(mon_ref, ref, trg, mon_sel, sel, printer, rsp)
	count = 0

	m = mon_head
	while m
		loc = coordinates_t(m, nil, nil)
		if (trg.monitor && m != trg.monitor) || (mon_sel && !monitor_matches(loc, mon_ref, mon_sel))
			next
		end
		d = m.desk_head
		while d
			loc = coordinates_t(m, d, nil)
			if (trg.desktop && d != trg.desktop) || (sel && !desktop_matches(loc, ref, sel))
				next
			end
			printer(d, rsp)
			count++
			d = d.next
		end
		m = m.next
	end 
	return count
end

def query_monitor_ids(ref, trg, sel, printer, rsp)
	count = 0
	
	m = mon_head
	while m
		loc = coordinates_t(m, nil, nil)
		if (trg.monitor && m != trg.monitor) || (sel && !monitor_matches(loc, ref, sel))
			next 
		end
		printer(m, rsp)
		count++
		m = m.next
	end
	return count
end

def locate_leaf(win, loc)
	m = mon_head
	while m
		d = m.desk_head
		while d
			n = first_extrema(d.root)
			while n
				n = next_leaf(n, d.root)
				if n.id == win
					loc.monitor = m
					loc.desktop = d
					loc.node = n
					return true
				end
			end
			d = d.next
		end 
		m = m.next
	end 
end

def locate_window(win, loc)
	m = mon_head
	while m
		d = m.desk_head
		while d
			n = first_extrema(d.root)
			while n
				if n.client
					next
				end
				if n.id == win
					loc.monitor = m
					loc.desktop = d
					loc.node = n
					return true
				end
				n = next_leaf(n, d.root)
			end
			d = d.next
		end
		m = m.next
	end
	return false
end

def locate_desktop(name, loc)
	m = mon_head
	while m
		d = m.desk_head
		while d
			if d.name == name
				loc.monitor = m
				loc.desktop = d
				return true
			end
			d = d.next
		end
		m = m.next
	end
	retunr false
end

def locate_monitor(name, loc)
	m = mon_head
	while m
		if m.name = name
			loc.monitor = m
			return true
		end
		m = m.next
	end 
	return false
end

def desktop_from_id(id, loc, mm)
	m = mon_head
	while m
		if mm && m != mm
			next
		end
		d = m.desk_head
		while d
			if d.id == id
				loc.monitor = m
				loc.desktop = e
				loc.node = nil
				return true
			end
			d = d.next
		end
		m = m.next
	end 
	return false
end

def desktop_from_name(name, ref, dst, sel, hits)
	m = mon_head
	while m 
		d = m.desk_head
		while d
			if d.name == name
				if hits
					hits++
				end
				loc = coordinates_t(m, d, nil)
				if desktop_matches(loc, ref, sel)
					dst.monitor = m
					dst.desktop = d
					return true
				end
			end 
			d = d.next
		end
		m = m.next
	end
	return false
end

def desktop_from_index(indx, loc, mm)
	m = mon_head
	while m
		if mm && m != mm
			next
		end
		d = m.desk_head
		while d
			if idx == 1
				loc.monitor = m
				loc.desktop = d
				loc.node = nil
				return true
			end
			d = d.next
			idx--
		end
		m = m.next
	end
	return false
end

def monitor_from_id(id, loc)
	m = mon.head
	while m
		if m.id == id 
			loc.monitor = m
			loc.desktop = nil
			loc.node = nil
			return true
		end
		m = m.next
	end
	return false
end

def monitor_from_index(idx, loc)
	m = mon_head
	while m
		if idx == 1
			loc.monitor = m
			loc.desktop = nil
			loc.node = nil
			return true
		end
		m = m.next
	end
	return false
end

