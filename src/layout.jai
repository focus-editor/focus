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

shrink :: (rect: Rect, amount: float) -> Rect {
    return expand(rect, -amount);
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

Rect :: struct {
    x, y : float;
    w, h : float;
}
