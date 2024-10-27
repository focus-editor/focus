#scope_export

Shader :: struct {
    using platform: Shader_Platform;
}

Extra_Draw_Info :: struct {
    is_background := false;  // This doesn't currently have any effect on drawing, but could be extended in future.
    is_translucent_on_the_right := false;
}

set_projection :: () {
    t := context.simp.texture_render_target;
    if t {
        immediate_set_2d_projection(t.width, t.height);
    } else {
        c := *context.simp.current_window_info;
        immediate_set_2d_projection(c.window_width, c.window_height);
    }
}

set_shader_for_color :: (enable_blend := false, $extra_draw_info := Extra_Draw_Info.{}) {
    CheckInit();
    shader := ifx enable_blend then *shader_color_with_blend else *shader_color;
    if state.current_shader != shader {
        immediate_set_shader(shader);
        set_projection();
    }
}

set_shader_for_text :: () {
    CheckInit();
    target_shader: *Shader = ---;
    if #complete font_anti_aliasing == {
        case .lcd;      target_shader = *shader_text_lcd;
        case .normal;   target_shader = *shader_text_normal;
    }
    if state.current_shader != target_shader {
        immediate_set_shader(target_shader);
        set_projection();
    }
}

set_shader_for_images :: (texture: *Texture) {
    CheckInit();
    immediate_flush();
    if state.current_shader != *shader_sprite {
        immediate_set_shader(*shader_sprite);
        set_projection();
    }

    immediate_set_texture(texture);
}

set_shader_for_rects :: ($extra_draw_info := Extra_Draw_Info.{}) {
    CheckInit();
    if state.current_shader != *shader_rounded_rect {
        immediate_set_shader(*shader_rounded_rect);
        set_projection();
    }
}

set_shader_for_gradient :: (rect: Vector4, mode: u8, value: float) {
    CheckInit();
    immediate_set_shader(*shader_gradient);
    set_projection();
    loc := get_uniform_location(shader_gradient.gl_handle, "rect");
    glUniform4f(loc, rect.x, rect.y, rect.z, rect.w);
    loc = get_uniform_location(shader_gradient.gl_handle, "mode");
    glUniform1i(loc, mode);
    loc = get_uniform_location(shader_gradient.gl_handle, "value");
    glUniform1f(loc, value);
}


shader_sprite:            Shader;
shader_text_lcd:          Shader;
shader_text_normal:       Shader;
shader_color:             Shader;
shader_color_with_blend:  Shader;
shader_rounded_rect:      Shader;
shader_gradient:          Shader;
