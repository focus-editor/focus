#module_parameters(enabled := true);

//
// Helpful macros to interface with the C api
//

#if enabled {
	#load "c_bindings.jai";
	
	// Call this every frame.
	FrameMark :: () #expand {
		___tracy_emit_frame_mark(null);
	}
	
	// Call this at the start of the scope you want to profile.
	ZoneScoped :: ($name := "", text := "", color: u32 = 0, value: u64 = 0, location := #caller_location) #expand {
		
		#if name {
			zone_name :: name;
		} else {
			zone_name :: #procedure_name(#this);
		}
		
		tracy_loc := ___tracy_alloc_srcloc(xx location.line_number, location.fully_pathed_filename.data, xx location.fully_pathed_filename.count, zone_name.data, zone_name.count);
		tracy_ctx := ___tracy_emit_zone_begin_alloc(tracy_loc, 1);
		
		if text  ___tracy_emit_zone_text(tracy_ctx, text.data, text.count);
		if color ___tracy_emit_zone_color(tracy_ctx, color);
		if value ___tracy_emit_zone_value(tracy_ctx, value);
		
		`defer ___tracy_emit_zone_end(tracy_ctx);
	}
} else {
	FrameMark :: () #expand {}
	ZoneScoped :: ($name := "", text := "", color: u32 = 0, value: u64 = 0, location := #caller_location) #expand {}
}
