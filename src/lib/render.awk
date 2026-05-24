function liquid_render(template,    out, rest, open_pos, close_pos, expr) {
    out = ""
    rest = template
    while ((open_pos = index(rest, "{{")) > 0) {
        out = out substr(rest, 1, open_pos - 1)
        rest = substr(rest, open_pos + 2)
        close_pos = index(rest, "}}")
        if (!close_pos) {
            out = out "{{" rest
            rest = ""
            break
        }
        expr = substr(rest, 1, close_pos - 1)
        out = out liquid_expression_value(expr)
        rest = substr(rest, close_pos + 2)
    }
    return out rest
}
