/*
 * VALIDATE_USAGE: enable extra sanity checks in the top-level API
 * JAI_STDLIB_INTEROP: enable `global_display` and extra top-level calls that work directly on it.
 *                     Required for interop with the standard `Clipboard`, `Input` and `Simp` modules.
 */
#module_parameters () (VALIDATE_USAGE := false, JAI_STDLIB_INTEROP := true);

#if OS == .LINUX {
    #load "linux_display.jai";
}
