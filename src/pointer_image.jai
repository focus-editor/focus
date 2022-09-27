Pointer_Image :: enum u16 {
    NORMAL    :: 0;  // Normal arrow for pointing at stuff, or whatever.
    PRESSABLE :: 1;
    LOCKED    :: 2;  // No action can currently be performed.

    DRAGGING_HORIZONTAL   :: 3;
    DRAGGING_VERTICAL     :: 4;
    DRAGGING_FREE         :: 5;

    DRAGGING_NW_SE        :: 6;
    DRAGGING_NE_SW        :: 7;

    TEXT_SELECT           :: 8;
}

#if OS == .WINDOWS {
    Windows :: #import "Windows";

    set_pointer_image :: (image: Pointer_Image) {
        if !initted_pointers  init_pointers();

        if (image >= 0) && (image <= cast(Pointer_Image) NUM_POINTERS) {
            // Windows.SetCursor(pointers[image]);
            current_pointer_image = image;
            pointer_image_was_set_this_frame = true;
            already_reset_pointer_image = (image == .NORMAL);  // No need to reset the image if it was set to NORMAL.
        } else {
            log_error("Invalid pointer index %\n", image);
        }
    }

    init_pointers :: () {
        initted_pointers = true;

        using Pointer_Image;

        w :: Windows;

        pointers[NORMAL]                = w.LoadCursorW(null, w.IDC_ARROW);
        pointers[PRESSABLE]             = w.LoadCursorW(null, w.IDC_HAND);
        pointers[LOCKED]                = w.LoadCursorW(null, w.IDC_NO);
        pointers[DRAGGING_HORIZONTAL]   = w.LoadCursorW(null, w.IDC_SIZEWE);
        pointers[DRAGGING_VERTICAL]     = w.LoadCursorW(null, w.IDC_SIZENS);
        pointers[DRAGGING_FREE]         = w.LoadCursorW(null, w.IDC_SIZEALL);
        pointers[DRAGGING_NW_SE]        = w.LoadCursorW(null, w.IDC_SIZENWSE);
        pointers[DRAGGING_NE_SW]        = w.LoadCursorW(null, w.IDC_SIZENESW);
        pointers[TEXT_SELECT]           = w.LoadCursorW(null, w.IDC_IBEAM);
    }

    pointers: [NUM_POINTERS] Windows.HCURSOR;
} else #if OS == .MACOS {
    #import "Objective_C";
    set_pointer_image :: (image: Pointer_Image) {
        if !initted_pointers  init_pointers();

        if (image >= 0) && (image <= cast(Pointer_Image) NUM_POINTERS) {
            // NSCursor.set(pointers[image]);
            current_pointer_image = image;
            pointer_image_was_set_this_frame = true;
            already_reset_pointer_image = (image == .NORMAL);  // No need to reset the image if it was set to NORMAL.
        } else {
            log_error("Invalid pointer index %\n", image);
        }
    }

    init_pointers :: () {
        initted_pointers = true;

        using Pointer_Image;
        pointers[NORMAL]                = NSCursor.arrowCursor();
        pointers[PRESSABLE]             = NSCursor.pointingHandCursor();
        pointers[LOCKED]                = NSCursor.operationNotAllowedCursor();
        pointers[DRAGGING_HORIZONTAL]   = NSCursor.resizeLeftRightCursor();
        pointers[DRAGGING_VERTICAL]     = NSCursor.resizeUpDownCursor();
        pointers[DRAGGING_FREE]         = NSCursor.openHandCursor(); // @Hack: There are no publicly available cursors for this.
        pointers[DRAGGING_NW_SE]        = NSCursor.openHandCursor(); // @Hack: There are no publicly available cursors for this.
        pointers[DRAGGING_NE_SW]        = NSCursor.openHandCursor(); // @Hack: There are no publicly available cursors for this.
        pointers[TEXT_SELECT]           = NSCursor.openHandCursor(); // @Hack: There are no publicly available cursors for this.
    }

    pointers: [NUM_POINTERS] *NSCursor;
} else {
    set_pointer_image :: (image: Pointer_Image) {
        if !initted_pointers  init_pointers();

        unimplemented();
    }

    init_pointers :: () {
        initted_pointers = true;

        using Pointer_Image;
        unimplemented();
    }
}


NUM_POINTERS :: #run enum_highest_value(Pointer_Image)+1;

pointer_end_frame :: () {
    if !pointer_image_was_set_this_frame {
        if !already_reset_pointer_image {
            set_pointer_image(.NORMAL); // This itself sets pointer_image* and already_reset*, so don't assume anything!
            already_reset_pointer_image = true;
        }
    } else {
        #if OS == .WINDOWS {
            Windows.SetCursor(pointers[current_pointer_image]);
        } else if OS == .MACOS {
            NSCursor.set(pointers[current_pointer_image]);
        } else {
            unimplemented();
        }
    }

    // Pointer-handling contribution by Rafał "Veeq7" Jurkiewicz.
    // We change custom cursor handling each frame, depending on whether we set the cursor or not.
    // The reason is, if we did set the cursor, we don't want Windows to set it back, which it seems
    // to do, every frame. But if we didn't want to set the cursor, we do want to pay attention
    // to Windows cursor changes, for example, as the user mouses over the window's resize frame.
    Input.set_custom_cursor_handling(pointer_image_was_set_this_frame);
    pointer_image_was_set_this_frame = false;
}

#scope_file

current_pointer_image: Pointer_Image;

initted_pointers                 := false;
pointer_image_was_set_this_frame := false;
already_reset_pointer_image      := false;
