//
// C API
//

___tracy_source_location_data :: struct {
	name:  *u8;
	function: *u8;
	file:  *u8;
	line:  u32;
	color: u32;
}

___tracy_c_zone_context :: struct {
	id: u32;
	active: s32;
}

___tracy_gpu_time_data :: struct {
	gpuTime: s64;
	queryId: s64;
	_context: u8;
}

___tracy_gpu_zone_begin_data :: struct {
	srcloc:  u64;
	queryId: u16;
	_context: u8;
}

___tracy_gpu_zone_begin_callstack_data :: struct {
	srcloc:  u64;
	depth:   s32;
	queryId: u16;
	_context: u8;
}

___tracy_gpu_zone_end_data :: struct {
	queryId: u16;
	_context: u8;
}

___tracy_gpu_new_context_data :: struct {
	gpuTime: s64;
	period:  float32;
	_context: u8;
	flags:   u8;
	type:    u8;
}

___tracy_gpu_context_name_data :: struct {
	_context: u8;
	name:    *u8;
	len:     u16;
}

___tracy_gpu_calibration_data :: struct {
	gpuTime:  s64;
	cpuDelta: s64;
	_context:  u8;
}

TracyCZoneCtx :: ___tracy_c_zone_context;

#if false { // Incomplete: These are only usable when tracy is compiled with TRACY_MANUAL_LIFETIME.
	___tracy_startup_profiler :: () #foreign TracyClientLib;
	___tracy_shutdown_profiler :: () #foreign TracyClientLib;
}

___tracy_alloc_srcloc :: (line: u32, source: *u8, sourceSz: u64, function: *u8, functionSz: u64) -> u64 #foreign TracyClientLib;
___tracy_alloc_srcloc_name :: (line: u32, source: *u8, sourceSz: u64, function: *u8, functionSz: u64, name: *u8, nameSz: u64) -> u64 #foreign TracyClientLib;

___tracy_emit_zone_begin :: (srcloc: *___tracy_source_location_data, active: s32) -> TracyCZoneCtx #foreign TracyClientLib;
___tracy_emit_zone_begin_callstack :: (srcloc: *___tracy_source_location_data, depth: s32, active: s32) -> TracyCZoneCtx #foreign TracyClientLib;
___tracy_emit_zone_begin_alloc :: (srcloc: u64, active: s32) -> TracyCZoneCtx #foreign TracyClientLib;
___tracy_emit_zone_begin_alloc_callstack :: (srcloc: u64, depth: s32, active: s32) -> TracyCZoneCtx #foreign TracyClientLib;
___tracy_emit_zone_end :: (ctx: TracyCZoneCtx) #foreign TracyClientLib;
___tracy_emit_zone_text :: (ctx: TracyCZoneCtx, txt: *u8, size: u64) #foreign TracyClientLib;
___tracy_emit_zone_name :: (ctx: TracyCZoneCtx, txt: *u8, size: u64) #foreign TracyClientLib;
___tracy_emit_zone_color :: (ctx: TracyCZoneCtx, color: u32) #foreign TracyClientLib;
___tracy_emit_zone_value :: (ctx: TracyCZoneCtx, value: u64) #foreign TracyClientLib;

___tracy_emit_gpu_zone_begin :: (data: ___tracy_gpu_zone_begin_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_begin_callstack :: (data: ___tracy_gpu_zone_begin_callstack_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_begin_alloc :: (data: ___tracy_gpu_zone_begin_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_begin_alloc_callstack :: (data: ___tracy_gpu_zone_begin_callstack_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_end :: (data: ___tracy_gpu_zone_end_data) #foreign TracyClientLib;
___tracy_emit_gpu_time :: (data: ___tracy_gpu_time_data) #foreign TracyClientLib;
___tracy_emit_gpu_new_context :: (data: ___tracy_gpu_new_context_data) #foreign TracyClientLib;
___tracy_emit_gpu_context_name :: (data: ___tracy_gpu_context_name_data) #foreign TracyClientLib;
___tracy_emit_gpu_calibration :: (data: ___tracy_gpu_calibration_data) #foreign TracyClientLib;

___tracy_emit_gpu_zone_begin_serial :: (data: ___tracy_gpu_zone_begin_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_begin_callstack_serial :: (data: ___tracy_gpu_zone_begin_callstack_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_begin_alloc_serial :: (data: ___tracy_gpu_zone_begin_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_begin_alloc_callstack_serial :: (data: ___tracy_gpu_zone_begin_callstack_data) #foreign TracyClientLib;
___tracy_emit_gpu_zone_end_serial :: (data: ___tracy_gpu_zone_end_data) #foreign TracyClientLib;
___tracy_emit_gpu_time_serial :: (data: ___tracy_gpu_time_data) #foreign TracyClientLib;
___tracy_emit_gpu_new_context_serial :: (data: ___tracy_gpu_new_context_data) #foreign TracyClientLib;
___tracy_emit_gpu_context_name_serial :: (data: ___tracy_gpu_context_name_data) #foreign TracyClientLib;
___tracy_emit_gpu_calibration_serial :: (data: ___tracy_gpu_calibration_data) #foreign TracyClientLib;

___tracy_connected :: () -> s32 #foreign TracyClientLib;

#if false { // Incomplete: These are only usable when tracy is compiled with TRACY_FIBERS.
	___tracy_fiber_enter :: (fiber: *u8) #foreign TracyClientLib;
	___tracy_fiber_leave :: () #foreign TracyClientLib;
}

___tracy_emit_memory_alloc :: (ptr: *void, size: u64, secure: s32) #foreign TracyClientLib;
___tracy_emit_memory_alloc_callstack :: (ptr: *void, size: u64, depth: s32, secure: s32) #foreign TracyClientLib;
___tracy_emit_memory_free :: (ptr: *void, secure: s32) #foreign TracyClientLib;
___tracy_emit_memory_free_callstack :: (ptr: *void, depth: s32, secure: s32) #foreign TracyClientLib;
___tracy_emit_memory_alloc_named :: (ptr: *void, size: u64, secure: s32, name: *u8) #foreign TracyClientLib;
___tracy_emit_memory_alloc_callstack_named :: (ptr: *void, size: u64, depth: s32, secure: s32, name: *u8) #foreign TracyClientLib;
___tracy_emit_memory_free_named :: (ptr: *void, secure: s32, name: *u8) #foreign TracyClientLib;
___tracy_emit_memory_free_callstack_named :: (ptr: *void, depth: s32, secure: s32, name: *u8) #foreign TracyClientLib;

___tracy_emit_message   :: (txt: *u8, size: u64, callstack: s32) #foreign TracyClientLib;
___tracy_emit_messageL  :: (txt: *u8, callstack: s32) #foreign TracyClientLib;
___tracy_emit_messageC  :: (txt: *u8, size: u64, color: u32, callstack: s32) #foreign TracyClientLib;
___tracy_emit_messageLC :: (txt: *u8, color: u32, callstack: s32) #foreign TracyClientLib;

___tracy_emit_frame_mark :: (name: *u8) #foreign TracyClientLib;
___tracy_emit_frame_mark_start :: (name: *u8) #foreign TracyClientLib;
___tracy_emit_frame_mark_end :: (name: *u8) #foreign TracyClientLib;
___tracy_emit_frame_image :: (image: *void, w: u16, h: u16, offset: u8, flip: s32) #foreign TracyClientLib;

___tracy_emit_plot :: (name: *u8, val: float64) #foreign TracyClientLib;
___tracy_emit_message_appinfo :: (txt: *u8, size: u64) #foreign TracyClientLib;

#scope_module

// If you get an error here, run 'jai build.jai' to build the shared and dynamic libraries.
TracyClientLib :: #library "TracyClient";

#run {
	// Tracy requires these libs to work.
	Compiler :: #import "Compiler";
	Compiler.set_build_options_dc(.{append_linker_arguments=.["ws2_32.lib", "msvcprtd.lib"]});
}