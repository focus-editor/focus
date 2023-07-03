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

is_valid :: inline (using rect: Rect) -> bool {
    return w >= 0 && h >= 0;
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

cut_left :: (rect: Rect, amount: float, $margin := 0) -> (left: Rect,  remainder: Rect) {
    amount = floor(amount);

    remainder := rect;

    remainder.w -= amount;
    remainder.x += amount;

    left := rect;
    left.w = amount;

    #if margin > 0 {
        #assert margin % 2 == 0;
        half_margin := margin / 2;
        remainder.x += margin;
        remainder.w -= half_margin;
        left.w      -= half_margin;
    }

    return left, remainder;
}

cut_right :: (rect: Rect, amount: float) -> (right: Rect, remainder: Rect) {
    amount = floor(amount);

    remainder := rect;

    remainder.w -= amount;

    right := rect;
    right.x = remainder.x + remainder.w;
    right.w = amount;

    return right, remainder;
}

cut_bottom :: (rect: Rect, amount: float) -> (bottom: Rect, remainder: Rect) {
    amount = floor(amount);

    remainder := rect;

    remainder.h -= amount;
    remainder.y += amount;

    bottom := rect;
    bottom.h = amount;

    return bottom, remainder;
}

cut_top :: (rect: Rect, amount: float) -> (top: Rect, remainder: Rect) {
    amount = floor(amount);

    remainder := rect;

    remainder.h -= amount;

    top := rect;
    top.h = amount;
    top.y = remainder.y + remainder.h;

    return top, remainder;
}

bottom_left :: inline (using rect: Rect) -> Vector2 {
    assert(is_valid(rect));
    return make_vector2(x, y);
}

bottom_right :: inline (using rect: Rect) -> Vector2 {
    assert(is_valid(rect));
    return make_vector2(x + w, y);
}

top_left :: inline (using rect: Rect) -> Vector2 {
    assert(is_valid(rect));
    return make_vector2(x, y + h);
}

top_right :: inline (using rect: Rect) -> Vector2 {
    assert(is_valid(rect));
    return make_vector2(x + w, y + h);
}

center_of :: inline (using rect: Rect) -> Vector2 {
    assert(is_valid(rect));
    return make_vector2(x + w / 2, y + h / 2);
}

get_rect_sides :: (using rect: Rect) -> (left: float, top: float, right: float, bottom: float) {
    left   := x;
    top    := y + h;
    right  := x + w;
    bottom := y;
    return left, top, right, bottom;
}

point_within :: (p: Vector2, using rect: Rect) -> bool {
    if w < 0 || h < 0 return false;
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

align_to_grid :: (rect: Rect) -> Rect {
    r := rect;

    r.x = floor(r.x);
    r.y = floor(r.y);
    r.w = floor(r.w);
    r.h = floor(r.h);

    return r;
}

Rect :: struct {
    x, y : float;
    w, h : float;
}

operator == :: (r1: Rect, r2: Rect) -> bool {
    return r1.x == r2.x && r1.y == r2.y && r1.w == r2.w && r1.h == r2.h;
}
