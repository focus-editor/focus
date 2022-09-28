make_rect :: (x: int, y: int, w: int, h: int) -> Rect {
    r: Rect = ---;

    r.x = xx x;
    r.y = xx y;
    r.w = xx w;
    r.h = xx h;

    return r;
}

make_rect :: (x: float, y: float, w: float, h: float) -> Rect {
    r: Rect = ---;

    r.x = x;
    r.y = y;
    r.w = w;
    r.h = h;

    return r;
}

expand :: (rect: Rect, amount: float) -> Rect {
    r := rect;

    r.x -= amount;
    r.y -= amount;
    r.w += 2 * amount;
    r.h += 2 * amount;

    return r;
}

expand_x :: (rect: Rect, amount: float) -> Rect {
    r := rect;

    r.x -= amount;
    r.w += 2 * amount;

    return r;
}

expand_y :: (rect: Rect, amount: float) -> Rect {
    r := rect;

    r.y -= amount;
    r.h += 2 * amount;

    return r;
}

shrink :: (rect: Rect, amount: float) -> Rect {
    return expand(rect, -amount);
}

shrink_x :: (rect: Rect, amount: float) -> Rect {
    return expand_x(rect, -amount);
}

shrink_y :: (rect: Rect, amount: float) -> Rect {
    return expand_y(rect, -amount);
}

cut_left :: (rect: Rect, amount: float) -> (left: Rect,  remainder: Rect) {
    remainder := rect;

    remainder.w -= amount;
    remainder.x += amount;

    left := rect;
    left.w = amount;

    return left, remainder;
}

cut_right :: (rect: Rect, amount: float) -> (right: Rect, remainder: Rect) {
    remainder := rect;

    remainder.w -= amount;

    right := rect;
    right.x = remainder.x + remainder.w;
    right.w = amount;

    return right, remainder;
}

cut_bottom :: (rect: Rect, amount: float) -> (bottom: Rect, remainder: Rect) {
    remainder := rect;

    remainder.h -= amount;
    remainder.y += amount;

    bottom := rect;
    bottom.h = amount;

    return bottom, remainder;
}

cut_top :: (rect: Rect, amount: float) -> (top: Rect, remainder: Rect) {
    remainder := rect;

    remainder.h -= amount;

    top := rect;
    top.h = amount;
    top.y = remainder.y + remainder.h;

    return top, remainder;
}

bottom_left :: inline (using rect: Rect) -> Vector2 {
    assert(w >= 0 && h >= 0);
    return make_vector2(x, y);
}

bottom_right :: inline (using rect: Rect) -> Vector2 {
    assert(w >= 0 && h >= 0);
    return make_vector2(x + w, y);
}

top_left :: inline (using rect: Rect) -> Vector2 {
    assert(w >= 0 && h >= 0);
    return make_vector2(x, y + h);
}

top_right :: inline (using rect: Rect) -> Vector2 {
    assert(w >= 0 && h >= 0);
    return make_vector2(x + w, y + h);
}

get_rect_sides :: (using rect: Rect) -> (left: float, top: float, right: float, bottom: float) {
    left   := x;
    top    := y + h;
    right  := x + w;
    bottom := y;
    return left, top, right, bottom;
}

point_within :: (p: Vector2, using rect: Rect) -> bool {
    assert(w >= 0 && h >= 0);
    return x <= p.x && p.x < x + w && y <= p.y && p.y < y + h;
}

mouse_pointer_is_within :: inline (rect: Rect) -> bool {
    return point_within(mouse.pointer, rect);
}

snap_to_rect :: (point: Vector2, using rect: Rect) -> Vector2 {
    p := point;

    if p.x < x     then p.x = x;
    if p.x > x + w then p.x = x + w;
    if p.y < y     then p.y = y;
    if p.y > y + h then p.y = y + h;

    return p;
}

Rect :: struct {
    x, y : float;
    w, h : float;
}
