//
// So that immediate rendering is threadsafe, we add its state to the Context.
//

Immediate_State :: struct {
    current_window_info: Window_Info;

    current_shader: *Shader;
    texture_render_target: *Texture;
    num_vertices: s32;

    MAX_VERTICES :: 2400;
    vertices: [MAX_VERTICES] Immediate_Vertex;

    specific: Backend_Platform_Specific;
    // We may wish to add a user-data pointer here.
}

// We add a pointer to the context, so that we don't use much memory
// if that thread never does immediate rendering.
#add_context simp: *Immediate_State;

//
// Immediate_Vertex is meant to be flexible rather than efficient.
//
Immediate_Vertex :: struct {
    position:    Vector2;
    color_scale: Vector4;
    uv0:         Vector2;

    // The following values are for rendering rounded rects - most of the time they are not used, but it's ok
    // because it's simpler than the alternatives and the performance is good enough for our purposes
    rect_center: Vector2;
    rect_size:   Vector2;
    rect_corner_radius: float;
    rect_edge_softness: float = 1.0;
}

immediate_reset :: () {
    CheckInit();

    state.current_shader = null;
}

immediate_set_texture :: (texture: *Texture) {
    CheckInit();
    shader := state.current_shader;
    if !shader {
        log_error("Attempted to immediate_set_texture when no shader was set.");
        return;
    }

    backend_set_texture(shader, texture);
}

immediate_set_shader :: (s: *Shader) {
    CheckInit();

    if state.current_shader && (state.current_shader != s) {
        immediate_flush();
    }

    state.current_shader = s;
    backend_use_shader(s);
}

immediate_flush :: () {
    CheckInit();
    if !state.num_vertices return;

    if !state.current_shader {
        assert(false, "Tried to immediate_flush when no shader was set.\n");
        state.num_vertices = 0;
        return;
    }

    //
    // In the long run, we want to send this buffer off to the main thread, probably.
    // But for now, we just say you can only do this from the main thread, because.
    //

    shader := state.current_shader;
    count  := state.num_vertices;
    state.num_vertices = 0;

    glBindVertexArray(opengl_is_stupid_vao);
    glBindBuffer(GL_ARRAY_BUFFER, immediate_vbo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

    DumpGLErrors("glBindBuffer immediate_vbo");
    glBufferData(GL_ARRAY_BUFFER, size_of(Immediate_Vertex) * count, state.vertices.data, GL_STREAM_DRAW);
    DumpGLErrors("glBufferData immediate_vertices");

    // glCullMode(GL_NONE);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    // @Speed: for some reason we have to set vertex format every time, otherwise the text is not rendered correctly
    set_vertex_format(shader);
    DumpGLErrors("set_vertex_format");

    glDrawArrays(GL_TRIANGLES, 0, xx count);

    DumpGLErrors("out");
}


#scope_file

set_vertex_format :: (shader: *Shader) {
    T :: Immediate_Vertex;
    stride : u32 = size_of(T);
    offset: *T: null;

    if shader.position_loc != -1 {
        DumpGLErrors("position - beforehand abc");
        // ArrayAttrib is GL 4.5 and some Intel chips don't have it.
        // glEnableVertexArrayAttrib(opengl_is_stupid_vao, xx shader.position_loc);
        glEnableVertexAttribArray(xx shader.position_loc);
        DumpGLErrors("position - mid");
        glVertexAttribPointer(xx shader.position_loc, 2, GL_FLOAT, xx false, stride, xx *offset.position);
        DumpGLErrors("position - After");
    }

    DumpGLErrors("position - VertexAttribArray");

    if shader.color_scale_loc != -1 {
        glVertexAttribPointer(xx shader.color_scale_loc, 4, GL_FLOAT, xx true, stride, xx *offset.color_scale);
        glEnableVertexAttribArray(xx shader.color_scale_loc);
        DumpGLErrors("color");
    }

    if shader.uv_0_loc != -1 {
        glVertexAttribPointer(xx shader.uv_0_loc, 2, GL_FLOAT, xx false, stride, xx *offset.uv0);
        glEnableVertexAttribArray(xx shader.uv_0_loc);
        DumpGLErrors("uv0");
    }

    if shader.rect_center_loc != -1 {
        glVertexAttribPointer(xx shader.rect_center_loc, 2, GL_FLOAT, xx false, stride, xx *offset.rect_center);
        glEnableVertexAttribArray(xx shader.rect_center_loc);
        DumpGLErrors("rect_center");
    }

    if shader.rect_size_loc != -1 {
        glVertexAttribPointer(xx shader.rect_size_loc, 2, GL_FLOAT, xx false, stride, xx *offset.rect_size);
        glEnableVertexAttribArray(xx shader.rect_size_loc);
        DumpGLErrors("rect_size");
    }

    if shader.rect_corner_radius_loc != -1 {
        glVertexAttribPointer(xx shader.rect_corner_radius_loc, 1, GL_FLOAT, xx false, stride, xx *offset.rect_corner_radius);
        glEnableVertexAttribArray(xx shader.rect_corner_radius_loc);
        DumpGLErrors("rect_corner_radius");
    }

    if shader.rect_edge_softness_loc != -1 {
        glVertexAttribPointer(xx shader.rect_edge_softness_loc, 1, GL_FLOAT, xx false, stride, xx *offset.rect_edge_softness);
        glEnableVertexAttribArray(xx shader.rect_edge_softness_loc);
        DumpGLErrors("rect_edge_softness");
    }
}

//
// These are just different utility functions that we use to fill out the vertex array.
//

put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector2, color: Vector4, u: float, v: float) {
    position     = p;
    color_scale  = color;
    uv0.x        = u;
    uv0.y        = v;
}

put_vertex :: inline (using vertex: *Immediate_Vertex, p: Vector2, color: Vector4, center: Vector2, size: Vector2, radius: float, softness: float) {
    position     = p;
    color_scale  = color;
    rect_center  = center;
    rect_size    = size;
    rect_corner_radius = radius;
    rect_edge_softness = softness;
}

#scope_export

//
// These are the routines that you, as a user, would call, depending
// on what is more convenient to you. We don't provide all permutations,
// but, we do provide a lot.
//

//
// First, here are some routines for outputting one vertex at a time.
// This API only does triangles, so, every 3 vertices indicates one triangle.
//

//
// Most of the time, you want to output quads: quadrilaterals, where the 4 points
// don't need to be in any particular relation. (The sides don't have to be the same length,
// the angles don't have to be the same). We do assume that this quad represents
// a convex positive area.
//
// We output quads just by outputting two triangles, as 6 vertices.
//

// But first we'll start with the simplest, an axis-aligned quad where you just
// want to declare the two corners (x0, y0) and (x1, y1):
immediate_quad :: (x0: float, y0: float, x1: float, y1: float, color: Vector4) {
    CheckSpace(6);

    put_vertex(*v[0], .{x1, y0}, color,  1, 0);
    put_vertex(*v[1], .{x0, y0}, color,  0, 0);
    put_vertex(*v[2], .{x1, y1}, color,  1, 1);

    put_vertex(*v[3], .{x1, y1}, color,  1, 1);
    put_vertex(*v[4], .{x0, y0}, color,  0, 0);
    put_vertex(*v[5], .{x0, y1}, color,  0, 1);
}

// Four 2D points making an arbitrary quad, plus a color,
// and optional uv coordinates for mapping a texture:
immediate_quad :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, color := Vector4.{1,1,1,1},
                   uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}) {
    CheckSpace(6);

    put_vertex(*v[0], p0, color,  uv0.x, uv0.y);
    put_vertex(*v[1], p1, color,  uv1.x, uv1.y);
    put_vertex(*v[2], p2, color,  uv2.x, uv2.y);

    put_vertex(*v[3], p0, color,  uv0.x, uv0.y);
    put_vertex(*v[4], p2, color,  uv2.x, uv2.y);
    put_vertex(*v[5], p3, color,  uv3.x, uv3.y);
}

// A 2D quad with different colors at each vertex:
immediate_quad :: (p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
                   c0: Vector4, c1: Vector4, c2: Vector4, c3: Vector4,
                   uv0 := Vector2.{0,0}, uv1 := Vector2.{1,0}, uv2 := Vector2.{1,1}, uv3 := Vector2.{0, 1}) {
    CheckSpace(6);

    put_vertex(*v[0], p0, c0,  uv0.x, uv0.y);
    put_vertex(*v[1], p1, c1,  uv1.x, uv1.y);
    put_vertex(*v[2], p2, c2,  uv2.x, uv2.y);

    put_vertex(*v[3], p0, c0,  uv0.x, uv0.y);
    put_vertex(*v[4], p2, c2,  uv2.x, uv2.y);
    put_vertex(*v[5], p3, c3,  uv3.x, uv3.y);
}

// A rectangular quad (x0, y0) - (x1, y1), but with colors at each vertex
immediate_quad :: (x0: float, y0: float, x1: float, y1: float,
                   c00: Vector4, c01: Vector4, c10: Vector4, c11: Vector4) {
    CheckSpace(6);

    put_vertex(*v[0], .{x1, y0}, c10,  1, 0);
    put_vertex(*v[1], .{x0, y0}, c00,  0, 0);
    put_vertex(*v[2], .{x1, y1}, c11,  1, 1);

    put_vertex(*v[3], .{x1, y1}, c11,  1, 1);
    put_vertex(*v[4], .{x0, y0}, c00,  0, 0);
    put_vertex(*v[5], .{x0, y1}, c01,  0, 1);
}

// p0 = bottom left, p2 = top right
immediate_rounded_rect :: (p0: Vector2, p2: Vector2, color: Vector4, center: Vector2, size: Vector2, radius: float, softness := 1.0) {
    CheckSpace(6);

    p1 := Vector2.{ x = p0.x, y = p2.y };
    p3 := Vector2.{ x = p2.x, y = p0.y };

    put_vertex(*v[0], p0, color, center, size, radius, softness);
    put_vertex(*v[1], p1, color, center, size, radius, softness);
    put_vertex(*v[2], p2, color, center, size, radius, softness);

    put_vertex(*v[3], p0, color, center, size, radius, softness);
    put_vertex(*v[4], p2, color, center, size, radius, softness);
    put_vertex(*v[5], p3, color, center, size, radius, softness);
}

immediate_triangle_fan :: (base: Vector2, points: [] Vector2, color: Vector4, base_color: Vector4) {
    assert(points.count >= 2);
    num_triangles := points.count - 1;
    CheckSpace(cast(s32) num_triangles * 3);
    for i : 0..num_triangles-1 {
        put_vertex(*v[i*3],     base,          base_color, 0, 0);
        put_vertex(*v[i*3 + 1], points[i],     color,      0, 0);
        put_vertex(*v[i*3 + 2], points[i + 1], color,      0, 0);
    }
}

immediate_set_2d_projection :: (render_target_width: s32, render_target_height: s32) {
    CheckInit();

    shader := state.current_shader;
    if !shader {
        assert(false, "Tried to immediate_set_2d_projection when no shader was set.\n");
        state.num_vertices = 0;
        return;
    }

    // @Cleanup: This matrix is GL-specific. We will want some way to customize this.
    m := orthographic_projection_matrix(0, cast(float) render_target_width*1, 0, cast(float) render_target_height, -1.0, 1.0);
    backend_tweak_projection_matrix(*m);

    set_parameter(shader, "projection", m);
}

immediate_letter_quad :: (using quad: Font_Quad, color: Vector4) {
    CheckSpace(6);

    put_vertex(*v[0], p0, color,  u0, v0);
    put_vertex(*v[1], p1, color,  u1, v0);
    put_vertex(*v[2], p2, color,  u1, v1);

    put_vertex(*v[3], p0, color,  u0, v0);
    put_vertex(*v[4], p2, color,  u1, v1);
    put_vertex(*v[5], p3, color,  u0, v1);
}


#scope_module

// Every entry point must call CheckInit to make sure we are initialized.
// That way nobody needs to call an init function.
CheckInit :: () #expand {
    if !context.simp  per_thread_init();
    `state := context.simp;
}

// Or you can call CheckSpace, to do a CheckInit but also
// ensure n vertices are available in the buffer.
// And when we return, bump the number of occupied vertices by n.
// So anyone calling CheckSpace had better fill those vertices out!

CheckSpace :: (n: s32) #expand {
    if !context.simp  per_thread_init();
    `state := context.simp;
    if state.num_vertices >= state.vertices.count-(n-1)  immediate_flush();
    `v := state.vertices.data + state.num_vertices;  // vertex pointer
    state.num_vertices += n;
}

per_thread_init :: () {
    // Actually, init all Simp stuff here.
    context.simp = New(Immediate_State);
}


#import "Window_Type";
