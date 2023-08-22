#if OS == .WINDOWS {
    // @Cleanup: Don't export these?!
    #import "Windows";
    #import "Basic";  // For alloc.

    // Clipboard functions.

    os_clipboard_get_text :: () -> string {
        hwnd := GetActiveWindow();  // @Robustness: We probably want something better than this.
        return os_clipboard_get_text(hwnd);
    }

    os_clipboard_set_text :: (text: string) {
        hwnd := GetActiveWindow();  // @Robustness: We probably want something better than this.
        os_clipboard_set_text(hwnd, text);
    }

    os_clipboard_set_bitmap :: (width: s32, height: s32, rgb: *u8) {
        hwnd := GetActiveWindow();  // @Robustness: We probably want something better than this.
        os_clipboard_set_bitmap(hwnd, width, height, rgb);
    }

    os_clipboard_empty :: () {
        hwnd := GetActiveWindow();  // @Robustness: We probably want something better than this.
        os_clipboard_empty(hwnd);
    }


    #scope_file

    os_clipboard_get_text :: (hwnd: HWND) -> string {  // Allocated via alloc; should be manually freed.
        text: string;

        if OpenClipboard(hwnd) {
            hData := GetClipboardData(CF_UNICODETEXT);

            buffer := cast(*u8)GlobalLock(hData);
            {
                CP :: CP_UTF8;
                WC :: 0;

                // Phase 1: Figure out how long this is.
                length := WideCharToMultiByte(CP, 0, cast(*u16)hData, -1, null, 0, null, null);

                utf8 := alloc(length);
                WideCharToMultiByte(CP, WC, cast(*u16)hData, -1, utf8, length, null, null);

                if length {
                    text.count = length-1;  // Terminating zero.
                    text.data  = utf8;
                    assert(text.data[length-1] == 0);
                } else {
                    text = "";
                }
            }

            GlobalUnlock(hData);
            CloseClipboard();
        }

        return text;
    }

    os_clipboard_set_text :: (hwnd: HWND, text: string) {
        if !OpenClipboard(hwnd) return;

        EmptyClipboard();

        CP :: CP_UTF8;
        WC :: 0;

        length := MultiByteToWideChar(CP, WC, text.data, xx text.count, null, 0);

        utf16 := cast(*u16)alloc(length * 2 + 2);   // @@ Use temporary memory?
        defer free(utf16);

        new_length := MultiByteToWideChar(CP, WC, text.data, xx text.count, utf16, length);
        assert(new_length <= length);
        utf16[new_length] = 0;

        clipbuffer := GlobalAlloc(0, xx (new_length*2+2));
        buffer := cast(*u8)GlobalLock(clipbuffer);
        memcpy(buffer, utf16, new_length*2+2);
        GlobalUnlock(clipbuffer);

        SetClipboardData(CF_UNICODETEXT, clipbuffer);
        CloseClipboard();
    }


    os_clipboard_empty :: (hwnd: HWND) {
        if OpenClipboard(hwnd) {
            EmptyClipboard();
            CloseClipboard();
        }
    }



    #if 0 {
        // @@ Do not take a bitmap, but rgb pointer, 3/4 comp, width & height.
        //#import "Game/Bitmap";

        os_clipboard_set_bitmap :: (hwnd: HWND, bmp: Bitmap) -> bool {
            if bmp.format != Texture_Format_RGB8 return false;
            os_clipboard_set_bitmap(hwnd, bmp.width, bmp.height, bmp.data);
            return true;
        }
    }


    // This assumes input rows are 4-byte aligned.
    os_clipboard_set_bitmap :: (hwnd: HWND, width: s32, height: s32, rgb: *u8) {

        if !OpenClipboard(hwnd) return;

        EmptyClipboard();

		// Because of changes in rev. 25491 we are now capturing an RGBA bitmap.
		// We still store an RGB image in the clipboard so the pitch is different for src & dst.
        pitch_src := (width * 4 + 3) & -4;
		pitch_dst := (width * 3 + 3) & -4;
        dst_size := cast(u64)(pitch_dst * height);

        // create HGLOBAL storage for image
        hMem := GlobalAlloc(GMEM_SHARE, size_of(BITMAPINFOHEADER) + dst_size);
        mem := cast(*u8)GlobalLock(hMem);

        // fill in image info
        bmh: BITMAPINFOHEADER;
        bmh.biSize = size_of(BITMAPINFOHEADER);
        bmh.biWidth = width;
        bmh.biHeight = height;
        bmh.biPlanes = 1;
        bmh.biBitCount = 24;
        bmh.biCompression = BI_RGB;

        memcpy(mem, *bmh, size_of(BITMAPINFOHEADER));

        dst := mem + size_of(BITMAPINFOHEADER);

        // Flip image, swap channels and make sure it's word-aligned.
        for y: 0..height-1 {
            src := rgb + (height - 1 - y) * pitch_src;

            for x: 0..width-1 {
				// the stride between source and dst is 3 (rgb) vs 4 (rgba) bytes.
                dst[3*x+0] = src[4*x+2];
                dst[3*x+1] = src[4*x+1];
                dst[3*x+2] = src[4*x+0];
            }

            dst += pitch_dst;
        }

        GlobalUnlock(hMem);

        // Set clipboard data.
        SetClipboardData(CF_DIB, hMem);

        CloseClipboard();
    }

}

#if OS == .LINUX {
    #scope_file
    LD :: #import "Linux_Display";
    #assert(LD.JAI_STDLIB_INTEROP);

    #scope_export

    os_clipboard_get_text :: () -> string {
        return LD.clipboard_get_text();
    }

    os_clipboard_set_text :: (text: string) {
        LD.clipboard_set_text(text);
    }

    os_clipboard_set_bitmap :: (width: s32, height: s32, rgb: *u8) {
    }
}

#if OS == .MACOS {
    // @Cleanup: Don't export these?!
    #import "Basic";
    #import "Objective_C";
    #import "Objective_C/AppKit";

    os_clipboard_get_text :: () -> string {
        general := NSPasteboard.generalPasteboard();

        nsstring := general.stringForType(general, NSPasteboardTypeString);
        if !nsstring return "";

        out := copy_string(to_string(nsstring));
        return out;
    }

    os_clipboard_set_text :: (text: string) {
        general := NSPasteboard.generalPasteboard();

        nsstring := NSString.initWithString(objc_alloc(NSString), text);
        defer release(nsstring);

        general.clearContents(general);
        general.setString(general, nsstring, NSPasteboardTypeString);
    }

    os_clipboard_empty :: () {
        general := NSPasteboard.generalPasteboard();
        general.clearContents(general);
    }

    os_clipboard_set_bitmap :: (width: s32, height: s32, rgb: *u8) {
        general := NSPasteboard.generalPasteboard();
        general.clearContents(general);

        image_rep := NSBitmapImageRep.initWithBitmapDataPlanes(objc_alloc(NSBitmapImageRep), null, width, height, 8, 3, NO, NO, NSDeviceRGBColorSpace, 0, 0);
        defer release(image_rep);

        dst := image_rep.bitmapData(image_rep);

        dst_pitch := 2 * ((width * 3 + 1) >> 1);
        dst_size := cast(u64)(dst_pitch * height);

        // make sure it's word-aligned.
        for y: 0..height-1 {
            src := rgb + y * width * 3;

            for x: 0..width-1 {
                dst[3*x+0] = src[3*x+0];
                dst[3*x+1] = src[3*x+1];
                dst[3*x+2] = src[3*x+2];
            }

            dst += dst_pitch;
        }

        image := NSImage.initWithSize(objc_alloc(NSImage), image_rep.size(image_rep));
        image.addRepresentation(image, image_rep);
        defer release(image);

        nsarray := NSArray(id).arrayWithObjects(xx *image, 1);
        general.writeObjects(general, nsarray);
    }
}

