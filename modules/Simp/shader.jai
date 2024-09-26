#scope_export

Shader :: struct {
    using platform: Shader_Platform;
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

set_shader_for_color :: (enable_blend := false) {
    CheckInit();
    shader := ifx enable_blend then *shader_color_with_blend else *shader_color;
    if state.current_shader != shader {
        immediate_set_shader(shader);
        set_projection();
    }
}

set_shader_for_text :: () {
    CheckInit();
    if state.current_shader != *shader_text {
        immediate_set_shader(*shader_text);
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

set_shader_for_rects :: (is_background := false, background_permutator := 0.0, background_gradient_settings := Vector4.{}) {
    CheckInit();
    if state.current_shader != *shader_rounded_rect {
        immediate_set_shader(*shader_rounded_rect);
        set_projection();
    }
    if is_background {
        c := *context.simp.current_window_info;
        loc := glGetUniformLocation(shader_rounded_rect.gl_handle, "u_resolution");
        glUniform2f(loc, cast(float) c.window_width, cast(float) c.window_height);
        loc = glGetUniformLocation(shader_rounded_rect.gl_handle, "permutator");
        glUniform1f(loc, background_permutator);
        loc = glGetUniformLocation(shader_rounded_rect.gl_handle, "gradient_settings");
        glUniform4f(loc, background_gradient_settings.x, background_gradient_settings.y, background_gradient_settings.z, background_gradient_settings.w);
        loc = glGetUniformLocation(shader_rounded_rect.gl_handle, "is_background");
        glUniform1i(loc, 1);
    } else {
        loc := glGetUniformLocation(shader_rounded_rect.gl_handle, "is_background");
        glUniform1i(loc, 0);
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

set_shader_for_background :: (permutator: float, background_gradient_settings: Vector4, rect_for_fade_right := Vector4.{}) {
    CheckInit();
    immediate_set_shader(*shader_background);
    set_projection();
    c := *context.simp.current_window_info;
    loc := glGetUniformLocation(shader_background.gl_handle, "u_resolution");
    glUniform2f(loc, cast(float) c.window_width, cast(float) c.window_height);
    loc = glGetUniformLocation(shader_background.gl_handle, "permutator");
    glUniform1f(loc, permutator);
    loc = glGetUniformLocation(shader_background.gl_handle, "gradient_settings");
    glUniform4f(loc, background_gradient_settings.x, background_gradient_settings.y, background_gradient_settings.z, background_gradient_settings.w);
    loc = glGetUniformLocation(shader_background.gl_handle, "fade_rect");
    glUniform4f(loc, rect_for_fade_right.x, rect_for_fade_right.y, rect_for_fade_right.z, rect_for_fade_right.w);
}


shader_sprite: Shader;
shader_text:   Shader;
shader_color:  Shader;
shader_color_with_blend:  Shader;
shader_rounded_rect:      Shader;
shader_gradient: Shader;
shader_background: Shader;