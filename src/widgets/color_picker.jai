color_picker_dialog : struct {
    mode := Gradient_Mode.hue_controlled_2d;
    value: float;
    point: Vector2;

    rgba: Vector4;
    hsl:  Vector3;

    color_change_callback: #type (rgba: Vector4, hsl: Vector3, finalize: bool);
    color_change_callback_data: *void;
}

Gradient_Mode :: enum u8 {
    // DO NOT CHANGE THESE VALUES (unless you also update the switch statement in the shader)
    red_controlled_2d        :: 0x00;
    green_controlled_2d      :: 0x01;
    blue_controlled_2d       :: 0x02;
    hue_controlled_2d        :: 0x03;
    saturation_controlled_2d :: 0x04;
    lightness_controlled_2d  :: 0x05;

    vertical_1d              :: 0x10;
    red_vertical_1d          :: 0x10;
    green_vertical_1d        :: 0x11;
    blue_vertical_1d         :: 0x12;
    hue_vertical_1d          :: 0x13;
    saturation_vertical_1d   :: 0x14;
    lightness_vertical_1d    :: 0x15;
    alpha_vertical_1d        :: 0x16;

    horizontal_1d            :: 0x20;
    red_horizontal_1d        :: 0x20;
    green_horizontal_1d      :: 0x21;
    blue_horizontal_1d       :: 0x22;
    hue_horizontal_1d        :: 0x23;
    saturation_horizontal_1d :: 0x24;
    lightness_horizontal_1d  :: 0x25;
    alpha_horizontal_1d      :: 0x26;
}

color_picker_set_mode :: (mode: Gradient_Mode) {
    color_picker_dialog.mode = mode % (Gradient_Mode.lightness_controlled_2d + 1);
    color_picker_set_color(color_picker_dialog.rgba);
}

color_picker_set_value :: (new_value: float, finalize: bool) {
    using color_picker_dialog;
    changed := value != new_value;
    value = new_value;

    if mode == {
        case .red_controlled_2d;
            rgba.x = value;

        case .green_controlled_2d;
            rgba.y = value;

        case .blue_controlled_2d;
            rgba.z = value;

        case .hue_controlled_2d;
            hsl.x = value;
            rgba.xyz = rgb_from_hsl(hsl);

        case .saturation_controlled_2d;
            hsl.y = value;
            rgba.xyz = rgb_from_hsl(hsl);

        case .lightness_controlled_2d;
            hsl.z = value;
            rgba.xyz = rgb_from_hsl(hsl);
    }

    if color_change_callback && (changed || finalize) then color_change_callback(rgba, hsl, finalize);
}

color_picker_set_point :: (new_point: Vector2, finalize: bool) {
    using color_picker_dialog;
    changed := new_point != point;
    point = new_point;

    if mode == {
        case .red_controlled_2d;
            rgba.yz = point;

        case .green_controlled_2d;
            rgba.x = point.x;
            rgba.z = point.y;

        case .blue_controlled_2d;
            rgba.xy = point;

        case .hue_controlled_2d;
            hsl.yz = point;
            rgba.xyz = rgb_from_hsl(hsl);

        case .saturation_controlled_2d;
            hsl.x = point.x;
            hsl.z = point.y;
            rgba.xyz = rgb_from_hsl(hsl);

        case .lightness_controlled_2d;
            hsl.xy = point;
            rgba.xyz = rgb_from_hsl(hsl);
    }

    if color_change_callback && (changed || finalize) then color_change_callback(rgba, hsl, finalize);
}

color_picker_set_alpha :: (alpha: float, finalize: bool) {
    using color_picker_dialog;
    changed := rgba.w != alpha;

    rgba.w = alpha;

    if color_change_callback && (changed || finalize) then color_change_callback(rgba, hsl, finalize);
}

color_picker_set_color :: (buffer: *Buffer, range: Offset_Range) {
    s := get_range_as_string(buffer, range);
    rgba, ok := hex_to_color_vec4(s);
    if !ok  return;

    if color_picker_dialog.rgba != rgba then color_picker_set_color(rgba);
}

color_picker_set_color :: (color: Vector4, finalize := false) {
    using color_picker_dialog;
    changed := rgba != color;
    rgba = color;
    hsl = hsl_from_rgb(color.xyz);
    if mode == {
        case .red_controlled_2d;
            value = rgba.x;
            point = rgba.yz;

        case .green_controlled_2d;
            value = rgba.y;
            point.x = rgba.x;
            point.y = rgba.z;

        case .blue_controlled_2d;
            value = rgba.z;
            point = rgba.xy;

        case .hue_controlled_2d;
            value = hsl.x;
            point = hsl.yz;

        case .saturation_controlled_2d;
            value = hsl.y;
            point.x = hsl.x;
            point.y = hsl.z;

        case .lightness_controlled_2d;
            value = hsl.z;
            point = hsl.xy;
    }

    if color_change_callback && (changed || finalize) then color_change_callback(rgba, hsl, finalize);
}


Color_Change_Buffer_Info :: struct {
    editor_id: s64;
    editor: *Editor;
    buffer: *Buffer;
    range: Offset_Range;
}
