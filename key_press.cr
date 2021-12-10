def handle_key_press(event)
	key_release = event.response_type == XCB_KEY_RELEASE

	last_time = event.time

	bind = get_binding_from_xcb_event(event)

	if !bind
		return
	end

	result = run_binding(bind, nil)
	command_result_free(result)
end
