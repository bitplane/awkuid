function liquid_trim(text) {
    sub(/^[ \t\r\n]+/, "", text)
    sub(/[ \t\r\n]+$/, "", text)
    return text
}

function liquid_unquote(text,    quote) {
    text = liquid_trim(text)
    quote = substr(text, 1, 1)
    if ((quote == "\"" || quote == "'") && substr(text, length(text), 1) == quote) {
        text = substr(text, 2, length(text) - 2)
    }
    return text
}

function liquid_expression_value(expr,    pipe, value, filter) {
    expr = liquid_trim(expr)
    pipe = index(expr, "|")
    if (pipe) {
        value = liquid_expression_value(substr(expr, 1, pipe - 1))
        filter = liquid_trim(substr(expr, pipe + 1))
        sub(/:.*/, "", filter)
        return liquid_apply_filter(value, filter)
    }
    if (expr == "blank" || expr == "empty" || expr == "nil" || expr == "null") {
        return ""
    }
    if (expr == "true") {
        return "true"
    }
    if (expr == "false") {
        return "false"
    }
    if (expr ~ /^["']/) {
        return liquid_unquote(expr)
    }
    return liquid_context_scalar(liquid_expression_path(expr))
}

function liquid_apply_filter(value, filter) {
    if (filter == "upcase") {
        return toupper(value)
    }
    if (filter == "downcase") {
        return tolower(value)
    }
    if (filter == "strip") {
        return liquid_trim(value)
    }
    return value
}

function liquid_expression_path(expr,    i, ch, segment, path, quote, end, inner) {
    expr = liquid_trim(expr)
    path = ""
    segment = ""
    for (i = 1; i <= length(expr); i++) {
        ch = substr(expr, i, 1)
        if (ch == "." || ch == "[" || ch ~ /[ \t\r\n]/) {
            if (segment != "") {
                path = liquid_context_child(path, segment)
                segment = ""
            }
            if (ch == "[") {
                i++
                inner = ""
                quote = substr(expr, i, 1)
                if (quote == "\"" || quote == "'") {
                    i++
                    while (i <= length(expr) && substr(expr, i, 1) != quote) {
                        inner = inner substr(expr, i, 1)
                        i++
                    }
                    while (i <= length(expr) && substr(expr, i, 1) != "]") {
                        i++
                    }
                } else {
                    while (i <= length(expr) && substr(expr, i, 1) != "]") {
                        inner = inner substr(expr, i, 1)
                        i++
                    }
                    inner = liquid_expression_value(inner)
                }
                path = liquid_context_child(path, inner)
            }
        } else {
            segment = segment ch
        }
    }
    if (segment != "") {
        path = liquid_context_child(path, segment)
    }
    return path
}
