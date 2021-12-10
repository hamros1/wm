def setup
	ewmh_init
	
	screen = xcb_setup_roots_iterator(xcb_get_setup(dpy)).data

	root = screen.root
	
	screen_width = screen.width_in_pixels
	screen_height = screen.height_in_pixels

	meta_window = xcb_generate_id(dpy)
	xcb_create_window(dpy, COPY_FROM_PARENT, meta_window, root, -1, -1, 1, 1, 0, XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT, XCB_NONE, nil)
	xcb_icccm_set_wm_class(dpy, meta_window, sizeof(META_WINDOW_IC), META_WINDOW_IC)

	motion_recorder.id = xcb_generate_id(dpy)
	motion_recorder.sequence = 0
	motion_recorder.enabled = false
	values = [XCB_EVENT_MASK_STRUCTURE_NOTIFY | XCB_EVENT_MASK_POINTER_MOTION]
	xcb_create_window(dpy, XCB_COPY_FROM_PARENT, motion_recorder.id, root, 0, 0, 1, 1, 0, XCB_WINDOW_CLASS_INPUT_ONLY, XCB_COPY_FROM_PARENT, XCB_CW_EVENT_MASK, values)
	xcb_iccm_set_wm_class(dpy, motion_recorder.id, sizeof(MOTION_RECORDER_IC), MOTION_RECORDER_IC)

	net_atoms = [ewmh._NET_SUPPORTED,
							 ewmh._NET_SUPPORTING_WM_CHECK,
							 ewmh._NET_DESKTOP_NAMES,
							 ewmh._NET_DESKTOP_VIEWPORT,
							 ewmh._NET_NUMBER_OF_DESKTOPS,
							 ewmh._NET_CURRENT_DESKTOP,
							 ewmh._NET_CLIENT_LIST,
							 ewmh._NET_ACTIVE_WINDOW,
							 ewmh._NET_CLOSE_WINDOW,
							 ewmh._NET_WM_STRUT_PARTIAL,
							 ewmh._NET_WM_DESKTOP,
							 ewmh._NET_WM_STATE,
							 ewmh._NET_WM_STATE_HIDDEN,
							 ewmh._NET_WM_STATE_FULLSCREEN,
							 ewmh._NET_WM_STATE_BELOW,
							 ewmh._NET_WM_STATE_ABOVE,
						   ewmh._NET_WM_STATE_STICKY,
							 ewmh._NET_WM_STATE_DEMANDS_ATTENTION,
							 ewmh._NET_WM_STATE_WINDOW_TYPE,
							 ewmh._NET_WM_STATE_WINDOW_TYPE_DOCK,
							 ewmh._NET_WM_STATE_WINDOW_TYPE_DESKTOP,
							 ewmh._NET_WM_WINDOW_TYPE_NOTIFICATION,
							 ewmh._NET_WM_WINDOW_TYPE_DIALOG,
							 ewmh._NET_WM_WINDOW_TYPE_UTILITY,
							 ewmh._NET_WM_WINDOW_TYPE_TOOLBAR]

	xcb_ewmh_set_supported(ewmh, default_screen, net_atoms.size, net.atoms)
	ewmh_set_supporting(meta_window)

	qep = Pointer(xcb_get_extension_data(dpy, pointerof(xcb_randr_id)))
	if qep.present && update_monitors
		randr = true
		randr_base = qep.first_event
		xcb_randr_select_input(dpy, root, XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE)
	else 
		randr = false

		rect = xcb_rectangle_t.new(0, 0, screen_width, screen_height)
		m = make_monitor(nil, pointerof(rect), XCB_NONE)
		add_monitor(m)
		add_desktop(m, make_desktop(nil, XCB_NONE))
	end

	ewmh_update_number_of_desktops
	ewmh_update_desktop_names
	ewmh_update_desktop_viewport
	ewmh_update_current_desktop
	ifo = xcb_get_input_focus_reply(dpy, xcb_get_input_focus(dpy), nil)
	if ifo && ifo.focus == XCB_INPUT_FOCUS_POINTER_ROOT || ifo.focus == XCB_NONE
		clear_input_focus
	end
	free(ifo)
end

def register_events
	values = [ROOT_EVENT_MASK]
	e = xcb_request_check(dpy, xcb_change_window_attributes_checked(dpy, root, XCB_CW_EVENT_MASK, values))
	if e
		free(e)
		xcb_ewmh_connection_wipe(ewmh)
		free(ewmh)
		xcb_disconnect(dpy)
	end
end

def check_connection(dpy)
	if xerr = xcb_connection_has_error(dpy)
		return false
	else
		return true
	end
end

