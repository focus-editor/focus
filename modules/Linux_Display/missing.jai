// A bunch of stuff that's missing from the standard modules

LC_ALL : s32 : 6;
setlocale :: (what: s32, loc: *u8) -> *u8 #foreign libc;

#scope_module

EFD_CLOEXEC : s32 : 0x80000;

#scope_file

libc :: #system_library "libc";
