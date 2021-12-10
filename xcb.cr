struct xcb_get_text_property_reply_t
	reply : Pointer(xcb_get_property_reply)
	encoding : xcb_atom_t
	name_len : UInt32
	name : Char*
	format : UInt8
end

fun xcb_get_text_property(x0 : xcb_connection_t*, x1 : xcb_window_t, x2 : xcb_atom_t) : xbc_get_property_reply_t

fun xcb_get_text_property_unchecked(x0 : xcb_connection_t*, x1 : xcb_window_t, x2 : xcb_atom_t) : xcb_get_property_cookie_t

fun xcb_get_text_property_reply(x0 : xcb_connection_t*, x1 : xcb_property_cookie_t, x2 : xcb_get_text_property_reply_t*, x3 : xcb_generic_error_t**) : UInt8

fun xcb_get_text_property_reply_wipe(x0 : xcb_get_text_property_reply_t*) : Void

fun xcb_set_wm_name_checked(x0 : xcb_connection_t*, x1 : xcb_window_t, x2 : xcb_atom_t, x3 : UInt32, x4 : Char*) : Void

fun xcb_set_wm_name(x0 : xcb_connection_t*, x1 : xcb_window_t, x2 : xcb_atom_t, x3 : UInt32, x4 : Char*) : Void

fun xcb_get_wm_name(x0 : xcb_connection_t*, x1 : xcb_window_t) : xcb_get_property_cookie_t

fun xcb_get_wm_name_unchecked(x0 : xcb_connection_t*, x1 : xcb_window_t) : xcb_get_property_cookie_t

fun xcb_get_wm_name_reply(x0 : xcb_connection_t*, x1 : xcb_get_property_cookie_t, x2 : xcb_get_text_property_reply_t*, x3 : xcb_generic_error_t**)

fun xcb_watch_wm_name(x0 : xcb_property_handlers_t*, x1 : UInt32, x2 : xcb_generic_property_handler, data : Void*) : Void

fun xcb_set_wm_icon_name_checked(x0 : xcb_connection_t*, x1 : xcb_window_t, x2 : xcb_atom_t, x3 : UInt32, x4 : Char*) : Void

fun xcb_set_wm_icon_name(x0 : xcb_connection_t*, x1 : xcb_window_t, x2 : xcb_atom_t, x3 : UInt32, x4 : Char*) : Void

fun xcb_get_wm_icon_name(x0 : xcb_connection_t*, x1 : xcb_window_t) : xcb_get_property_cookie
