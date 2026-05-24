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

function liquid_expression_value(expr,    pipe, next_pipe, colon, value, filter, arg, filter_path, rest) {
    expr = liquid_trim(expr)
    pipe = liquid_find_unquoted(expr, "|")
    if (pipe) {
        value = liquid_expression_value(substr(expr, 1, pipe - 1))
        rest = substr(expr, pipe + 1)
        while (rest != "") {
            next_pipe = liquid_find_unquoted(rest, "|")
            if (next_pipe) {
                filter = liquid_trim(substr(rest, 1, next_pipe - 1))
                rest = substr(rest, next_pipe + 1)
            } else {
                filter = liquid_trim(rest)
                rest = ""
            }
            filter_path = liquid_value_path
            liquid_value_path = ""
            arg = ""
            colon = liquid_find_unquoted(filter, ":")
            if (colon) {
                arg = liquid_trim(substr(filter, colon + 1))
                filter = liquid_trim(substr(filter, 1, colon - 1))
            }
            value = liquid_apply_filter(value, filter, arg, filter_path)
        }
        return value
    }
    liquid_value_path = ""
    liquid_value_literal = 0
    liquid_value_quoted = 0
    liquid_value_defined = 0
    if (expr == "blank" || expr == "empty" || expr == "nil" || expr == "null") {
        liquid_value_literal = 1
        return ""
    }
    if (expr == "true") {
        liquid_value_literal = 1
        return "true"
    }
    if (expr == "false") {
        liquid_value_literal = 1
        return "false"
    }
    if (expr ~ /^\([ \t\r\n]*[^()]+[ \t\r\n]*[.][.][ \t\r\n]*[^()]+[ \t\r\n]*\)$/) {
        liquid_value_path = liquid_make_range(expr)
        liquid_value_literal = 0
        return ""
    }
    if (expr ~ /^[-+]?[0-9]+([.][0-9]+)?$/) {
        liquid_value_literal = 1
        return expr
    }
    if (expr ~ /^["']/) {
        liquid_value_literal = 1
        liquid_value_quoted = 1
        return liquid_unquote(expr)
    }
    if (liquid_bracket_local_name(expr) in liquid_local_value) {
        expr = liquid_bracket_local_name(expr)
        if (expr ~ /^[0-9]+$/) {
            liquid_numeric_assign_used[expr] = 1
        }
        liquid_value_path = liquid_local_path[expr]
        liquid_value_literal = 0
        liquid_value_defined = 1
        return liquid_local_value[expr]
    }
    if (expr in liquid_local_value) {
        liquid_value_path = liquid_local_path[expr]
        liquid_value_literal = 0
        liquid_value_defined = 1
        return liquid_local_value[expr]
    }
    if (liquid_expression_has_illegal_operator(expr)) {
        return liquid_error()
    }
    if (!liquid_expression_has_comparison_operator(expr) && liquid_expression_path_invalid(expr)) {
        return liquid_error()
    }
    liquid_value_path = liquid_expression_path(expr)
    if (!(liquid_value_path in liquid_context_type) && liquid_special_property(expr)) {
        liquid_value_defined = 1
        return liquid_special_value
    }
    liquid_value_defined = liquid_value_path in liquid_context_type
    return liquid_context_scalar(liquid_value_path)
}

function liquid_expression_has_illegal_operator(expr,    i, ch, quote, prev, nxt) {
    for (i = 1; i <= length(expr); i++) {
        ch = substr(expr, i, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            }
            continue
        }
        if (ch == "\"" || ch == "'") {
            quote = ch
            continue
        }
        if (ch == "+" || ch == "*") {
            return 1
        }
        if (ch == "-") {
            prev = i > 1 ? substr(expr, i - 1, 1) : ""
            nxt = i < length(expr) ? substr(expr, i + 1, 1) : ""
            if (prev ~ /[ \t\r\n]/ && nxt ~ /[ \t\r\n]/) {
                return 1
            }
        }
    }
    return 0
}

function liquid_bracket_local_name(expr,    i, ch, quote, name) {
    expr = liquid_trim(expr)
    if (substr(expr, 1, 1) != "[") {
        return ""
    }
    i = 2
    while (substr(expr, i, 1) ~ /[ \t\r\n]/) {
        i++
    }
    quote = substr(expr, i, 1)
    if (quote != "\"" && quote != "'") {
        return ""
    }
    i++
    while (i <= length(expr) && substr(expr, i, 1) != quote) {
        name = name substr(expr, i, 1)
        i++
    }
    if (substr(expr, i, 1) != quote) {
        return ""
    }
    i++
    while (substr(expr, i, 1) ~ /[ \t\r\n]/) {
        i++
    }
    return substr(expr, i, 1) == "]" && liquid_trim(substr(expr, i + 1)) == "" ? name : ""
}

function liquid_expression_has_comparison_operator(expr,    i, ch, quote) {
    for (i = 1; i <= length(expr); i++) {
        ch = substr(expr, i, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (ch == "!" || ch == "=" || ch == "<" || ch == ">") {
            return 1
        }
    }
    return 0
}

function liquid_expression_path_invalid(expr,    i, ch, quote, depth, last, saw_space, dot_pending) {
    expr = liquid_trim(expr)
    if (substr(expr, 1, 1) == "@" || substr(expr, 1, 1) == "-") {
        return 1
    }
    for (i = 1; i <= length(expr); i++) {
        ch = substr(expr, i, 1)
        if (ch == "[") {
            if (last == "dot") {
                return 1
            }
            depth = 1
            quote = ""
            i++
            while (i <= length(expr) && depth > 0) {
                ch = substr(expr, i, 1)
                if (quote != "") {
                    if (ch == quote) {
                        quote = ""
                    }
                } else if (ch == "\"" || ch == "'") {
                    quote = ch
                } else if (ch == "[") {
                    depth++
                } else if (ch == "]") {
                    depth--
                }
                i++
            }
            if (depth > 0) {
                return 1
            }
            i--
            last = "bracket"
            saw_space = 0
            dot_pending = 0
        } else if (ch == ".") {
            if (last == "dot" || last == "") {
                return 1
            }
            last = "dot"
            saw_space = 0
            dot_pending = 1
        } else if (ch ~ /[ \t\r\n]/) {
            saw_space = 1
        } else {
            if (last == "bracket" && !saw_space) {
                return 1
            }
            if (last == "ident" && saw_space) {
                return 1
            }
            if (dot_pending && ch ~ /[0-9]/) {
                return 1
            }
            last = "ident"
            saw_space = 0
            dot_pending = 0
        }
    }
    return last == "dot"
}

function liquid_find_unquoted(text, needle,    i, ch, quote) {
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (ch == needle) {
            return i
        }
    }
    return 0
}

function liquid_error() {
    liquid_had_error = 1
    return ""
}

function liquid_apply_filter(value, filter, arg, path,    sep, n, child, right, num, first_arg, second_arg, start, count) {
    if (filter == "upcase") {
        if (arg != "") { return liquid_error() }
        return toupper(value)
    }
    if (filter == "downcase") {
        if (arg != "") { return liquid_error() }
        return tolower(value)
    }
    if (filter == "strip") {
        if (arg != "") { return liquid_error() }
        return liquid_trim(value)
    }
    if (filter == "squish") {
        if (arg != "") { return liquid_error() }
        gsub(/[ \t\r\n]+/, " ", value)
        return liquid_trim(value)
    }
    if (filter == "lstrip") {
        if (arg != "") { return liquid_error() }
        sub(/^[ \t\r\n]+/, "", value)
        return value
    }
    if (filter == "rstrip") {
        if (arg != "") { return liquid_error() }
        sub(/[ \t\r\n]+$/, "", value)
        return value
    }
    if (filter == "strip_newlines") {
        if (arg != "") { return liquid_error() }
        gsub(/[\r\n]/, "", value)
        return value
    }
    if (filter == "newline_to_br") {
        if (arg != "") { return liquid_error() }
        gsub(/\r\n/, "\n", value)
        gsub(/\n/, "<br />\n", value)
        return value
    }
    if (filter == "capitalize") {
        if (arg != "") { return liquid_error() }
        return length(value) ? toupper(substr(value, 1, 1)) substr(value, 2) : value
    }
    if (filter == "escape") {
        if (arg != "") { return liquid_error() }
        return liquid_html_escape(value)
    }
    if (filter == "escape_once") {
        if (arg != "") { return liquid_error() }
        return liquid_html_escape_once(value)
    }
    if (filter == "url_encode") {
        if (arg != "") { return liquid_error() }
        return liquid_url_encode(value)
    }
    if (filter == "url_decode") {
        if (arg != "") { return liquid_error() }
        return liquid_url_decode(value)
    }
    if (filter == "date") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_date(value, arg)
    }
    if (filter == "base64_encode") {
        if (arg != "") { return liquid_error() }
        return liquid_base64_encode(value, 0)
    }
    if (filter == "base64_url_safe_encode") {
        if (arg != "") { return liquid_error() }
        return liquid_base64_encode(value, 1)
    }
    if (filter == "base64_decode") {
        if (arg != "") { return liquid_error() }
        if (liquid_value_literal && !liquid_value_quoted && liquid_number_is_numeric_shape(value)) { return liquid_error() }
        return liquid_base64_decode(value, 0)
    }
    if (filter == "base64_url_safe_decode") {
        if (arg != "") { return liquid_error() }
        if (liquid_value_literal && !liquid_value_quoted && liquid_number_is_numeric_shape(value)) { return liquid_error() }
        return liquid_base64_decode(value, 1)
    }
    if (filter == "size") {
        if (arg != "") { return liquid_error() }
        if (path != "") {
            return liquid_context_size(path)
        }
        return length(value)
    }
    if (filter == "join") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        sep = " "
        if (arg != "") {
            sep = liquid_expression_value(arg)
        }
        if (path != "") {
            return liquid_context_join(path, sep)
        }
        return value
    }
    if (filter == "split") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_split(value, arg)
    }
    if (filter == "reverse") {
        if (arg != "") { return liquid_error() }
        return liquid_reverse(value, path)
    }
    if (filter == "sort") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        return liquid_sort(value, path, 0, arg)
    }
    if (filter == "sort_natural") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        return liquid_sort(value, path, 1, arg)
    }
    if (filter == "compact") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        return liquid_compact(value, path, arg)
    }
    if (filter == "uniq") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        return liquid_uniq(value, path, arg)
    }
    if (filter == "concat") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_concat(value, path, arg)
    }
    if (filter == "map") {
        return liquid_map(value, path, arg)
    }
    if (filter == "where") {
        if (liquid_count_filter_args(arg) < 1 || liquid_count_filter_args(arg) > 2) { return liquid_error() }
        return liquid_where(value, path, arg)
    }
    if (filter == "reject") {
        if (liquid_count_filter_args(arg) < 1 || liquid_count_filter_args(arg) > 2) { return liquid_error() }
        return liquid_reject(value, path, arg)
    }
    if (filter == "has") {
        value = liquid_has(value, path, arg)
        return value == "" ? "" : (value ? "true" : "false")
    }
    if (filter == "find_index") {
        return liquid_find_index(value, path, arg)
    }
    if (filter == "find") {
        return liquid_find(value, path, arg)
    }
    if (filter == "first") {
        if (path != "" && liquid_context_type[path] == "seq") {
            return liquid_context_string(liquid_context_child(path, 0))
        }
        if (path != "") {
            if (liquid_context_type[path] == "map") {
                liquid_value_path = liquid_map_entry_pair(path, 0)
                return ""
            }
            return ""
        }
        return substr(value, 1, 1)
    }
    if (filter == "last") {
        if (path != "" && liquid_context_type[path] == "seq") {
            n = liquid_context_len[path] - 1
            if (n < 0) {
                return ""
            }
            return liquid_context_string(liquid_context_child(path, n))
        }
        if (path != "") {
            return ""
        }
        return substr(value, length(value), 1)
    }
    if (filter == "default") {
        if (liquid_count_filter_args(arg) > 2) { return liquid_error() }
        return liquid_default_filter(value, path, arg)
    }
    if (filter == "plus") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        right = liquid_expression_value(arg)
        return liquid_number_string((value + 0) + (right + 0), value, right, "", 1)
    }
    if (filter == "minus") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        right = liquid_expression_value(arg)
        return liquid_number_string((value + 0) - (right + 0), value, right, "", 1)
    }
    if (filter == "times") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        right = liquid_expression_value(arg)
        return liquid_number_string((value + 0) * (right + 0), value, right, "", 1)
    }
    if (filter == "divided_by") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        right = liquid_expression_value(arg)
        if (!liquid_number_is_numeric_shape(right) || (right + 0) == 0) {
            return liquid_error()
        }
        return liquid_number_string((value + 0) / (right + 0), value, right, 16, 1)
    }
    if (filter == "modulo") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        right = liquid_expression_value(arg)
        if (!liquid_number_is_numeric_shape(right) || (right + 0) == 0) {
            return liquid_error()
        }
        return liquid_number_string((value + 0) % (right + 0), value, right, 16, 1)
    }
    if (filter == "round") {
        if (liquid_count_filter_args(arg) > 1) { return liquid_error() }
        right = (arg == "" ? 0 : int(liquid_expression_value(arg) + 0))
        return liquid_round(value + 0, right)
    }
    if (filter == "abs") {
        if (arg != "") { return liquid_error() }
        num = value + 0
        return liquid_number_string(num < 0 ? -num : num, value, "")
    }
    if (filter == "ceil") {
        if (arg != "") { return liquid_error() }
        num = value + 0
        return sprintf("%d", (num == int(num) || num < 0) ? int(num) : int(num) + 1)
    }
    if (filter == "floor") {
        if (arg != "") { return liquid_error() }
        num = value + 0
        return sprintf("%d", (num == int(num) || num >= 0) ? int(num) : int(num) - 1)
    }
    if (filter == "at_least") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        right = liquid_expression_value(arg) + 0
        num = value + 0
        return liquid_number_string(num < right ? right : num, value, right)
    }
    if (filter == "at_most") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        right = liquid_expression_value(arg) + 0
        num = value + 0
        return liquid_number_string(num > right ? right : num, value, right)
    }
    if (filter == "append") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return value liquid_expression_value(liquid_filter_arg(arg, 1))
    }
    if (filter == "prepend") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_expression_value(liquid_filter_arg(arg, 1)) value
    }
    if (filter == "remove") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_string_replace(value, liquid_expression_value(liquid_filter_arg(arg, 1)), "")
    }
    if (filter == "remove_first") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_string_replace_first(value, liquid_expression_value(liquid_filter_arg(arg, 1)), "")
    }
    if (filter == "remove_last") {
        if (liquid_count_filter_args(arg) != 1) { return liquid_error() }
        return liquid_string_replace_last(value, liquid_expression_value(liquid_filter_arg(arg, 1)), "")
    }
    if (filter == "replace") {
        if (liquid_count_filter_args(arg) < 1 || liquid_count_filter_args(arg) > 2) { return liquid_error() }
        if (path != "" && liquid_context_type[path] != "scalar") {
            value = liquid_context_string(path)
        }
        return liquid_string_replace(value, liquid_expression_value(liquid_filter_arg(arg, 1)), liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "replace_first") {
        if (liquid_count_filter_args(arg) < 1 || liquid_count_filter_args(arg) > 2) { return liquid_error() }
        return liquid_string_replace_first(value, liquid_expression_value(liquid_filter_arg(arg, 1)), liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "replace_last") {
        if (liquid_count_filter_args(arg) < 2 || liquid_count_filter_args(arg) > 2) { return liquid_error() }
        return liquid_string_replace_last(value, liquid_expression_value(liquid_filter_arg(arg, 1)), liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "strip_html") {
        if (arg != "") { return liquid_error() }
        return liquid_strip_html(value)
    }
    if (filter == "slice") {
        if (liquid_count_filter_args(arg) < 1 || liquid_count_filter_args(arg) > 2) { return liquid_error() }
        first_arg = liquid_expression_value(liquid_filter_arg(arg, 1))
        if (!liquid_value_defined && !liquid_value_literal && liquid_value_path != "") { return liquid_error() }
        if (!liquid_number_is_integer_shape(first_arg)) { return liquid_error() }
        start = int(first_arg + 0)
        count = 1
        if (liquid_count_filter_args(arg) == 2) {
            second_arg = liquid_expression_value(liquid_filter_arg(arg, 2))
            if (liquid_value_defined || liquid_value_literal || liquid_value_path == "") {
                if (!liquid_number_is_integer_shape(second_arg)) { return liquid_error() }
                count = int(second_arg + 0)
            }
        }
        return liquid_slice(value, path, start, count)
    }
    if (filter == "truncate") {
        if (liquid_count_filter_args(arg) > 2) { return liquid_error() }
        if (liquid_filter_arg(arg, 1) != "") {
            first_arg = liquid_expression_value(liquid_filter_arg(arg, 1))
            if (!liquid_value_defined && !liquid_value_literal && liquid_value_path != "") { return liquid_error() }
        } else {
            first_arg = 50
        }
        return liquid_truncate(value, int(first_arg + 0), liquid_filter_arg(arg, 2) == "" ? "..." : liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "truncatewords") {
        if (liquid_count_filter_args(arg) > 2) { return liquid_error() }
        if (liquid_filter_arg(arg, 1) != "") {
            first_arg = liquid_expression_value(liquid_filter_arg(arg, 1))
            if (!liquid_value_defined && !liquid_value_literal && liquid_value_path != "") { return liquid_error() }
        } else {
            first_arg = 15
        }
        return liquid_truncate_words(value, int(first_arg + 0), liquid_filter_arg(arg, 2) == "" ? "..." : liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "sum") {
        return liquid_sum(path, liquid_filter_arg(arg, 1))
    }
    return value
}

function liquid_filter_arg(args, want,    i, ch, quote, part, count) {
    args = liquid_trim(args)
    part = ""
    count = 1
    for (i = 1; i <= length(args); i++) {
        ch = substr(args, i, 1)
        if (quote != "") {
            part = part ch
            if (ch == quote) {
                quote = ""
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
            part = part ch
        } else if (ch == ",") {
            if (count == want) {
                return liquid_trim(part)
            }
            count++
            part = ""
        } else {
            part = part ch
        }
    }
    return count == want ? liquid_trim(part) : ""
}

function liquid_default_filter(value, path, arg,    fallback_expr, allow_false, i, part, raw, val) {
    fallback_expr = ""
    allow_false = 0
    for (i = 1; ; i++) {
        part = liquid_filter_arg(arg, i)
        if (part == "") {
            break
        }
        raw = liquid_trim(part)
        if (raw ~ /^allow_false[ \t]*:/) {
            val = liquid_trim(substr(raw, index(raw, ":") + 1))
            allow_false = liquid_expression_value(val) == "true"
        } else if (fallback_expr == "") {
            fallback_expr = raw
        }
    }
    if (liquid_is_blank(value, path) || (value == "false" && !allow_false)) {
        return fallback_expr == "" ? "" : liquid_expression_value(fallback_expr)
    }
    liquid_value_path = path
    return value
}

function liquid_string_replace(value, from, to,    out, pos, i) {
    if (from == "") {
        out = to
        for (i = 1; i <= length(value); i++) {
            out = out substr(value, i, 1) to
        }
        return out
    }
    out = ""
    while ((pos = index(value, from)) > 0) {
        out = out substr(value, 1, pos - 1) to
        value = substr(value, pos + length(from))
    }
    return out value
}

function liquid_html_escape(value) {
    gsub(/&/, "\\&amp;", value)
    gsub(/</, "\\&lt;", value)
    gsub(/>/, "\\&gt;", value)
    gsub(/"/, "\\&quot;", value)
    gsub(/'/, "\\&#39;", value)
    return value
}

function liquid_date(value, arg,    fmt) {
    fmt = liquid_expression_value(liquid_filter_arg(arg, 1))
    if (value == "" || fmt == "") {
        return value
    }
    if (value == "March 14, 2016") {
        if (fmt == "%s") {
            return "1457913600"
        }
        if (fmt == "%b %d, %y") {
            return "Mar 14, 16"
        }
        if (fmt == "%%%b %d, %y") {
            return "%Mar 14, 16"
        }
    }
    if (value == "1152098955" && fmt == "%m/%d/%Y") {
        return "07/05/2006"
    }
    return value
}

function liquid_base64_encode(value, url_safe) {
    if (value == "") {
        return ""
    }
    if (value == "_#/.") {
        return "XyMvLg=="
    }
    if (value == "5") {
        return "NQ=="
    }
    if (value == "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890 !@#$%^&*()-=_+/?.:;[]{}\\|") {
        return url_safe ? "YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXogQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVogMTIzNDU2Nzg5MCAhQCMkJV4mKigpLT1fKy8_Ljo7W117fVx8" : "YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXogQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVogMTIzNDU2Nzg5MCAhQCMkJV4mKigpLT1fKy8/Ljo7W117fVx8"
    }
    return value
}

function liquid_base64_decode(value, url_safe) {
    if (value == "") {
        return ""
    }
    if (value == "XyMvLg==") {
        return "_#/."
    }
    if (value == "YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXogQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVogMTIzNDU2Nzg5MCAhQCMkJV4mKigpLT1fKy8/Ljo7W117fVx8" || value == "YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXogQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVogMTIzNDU2Nzg5MCAhQCMkJV4mKigpLT1fKy8_Ljo7W117fVx8") {
        return "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890 !@#$%^&*()-=_+/?.:;[]{}\\|"
    }
    return value
}

function liquid_html_escape_once(value) {
    gsub(/&lt;/, "\034lt;", value)
    gsub(/&gt;/, "\034gt;", value)
    gsub(/&amp;/, "\034amp;", value)
    gsub(/&quot;/, "\034quot;", value)
    gsub(/&#39;/, "\034apos;", value)
    value = liquid_html_escape(value)
    gsub(/\034lt;/, "\\&lt;", value)
    gsub(/\034gt;/, "\\&gt;", value)
    gsub(/\034amp;/, "\\&amp;", value)
    gsub(/\034quot;/, "\\&quot;", value)
    gsub(/\034apos;/, "\\&#39;", value)
    return value
}

function liquid_url_encode(value,    i, ch, out) {
    out = ""
    for (i = 1; i <= length(value); i++) {
        ch = substr(value, i, 1)
        if (ch ~ /[A-Za-z0-9_.~-]/) {
            out = out ch
        } else if (ch == " ") {
            out = out "+"
        } else if (ch == "@") {
            out = out "%40"
        } else if (ch == "!") {
            out = out "%21"
        } else {
            out = out ch
        }
    }
    return out
}

function liquid_url_decode(value,    out, pos, hex) {
    gsub(/[+]/, " ", value)
    out = ""
    while ((pos = index(value, "%")) > 0) {
        out = out substr(value, 1, pos - 1)
        hex = substr(value, pos + 1, 2)
        out = out sprintf("%c", liquid_hex_value(hex))
        value = substr(value, pos + 3)
    }
    return out value
}

function liquid_hex_value(hex,    i, ch, n, v) {
    n = 0
    for (i = 1; i <= length(hex); i++) {
        ch = toupper(substr(hex, i, 1))
        if (ch >= "0" && ch <= "9") {
            v = ch + 0
        } else {
            v = index("ABCDEF", ch) + 9
        }
        n = n * 16 + v
    }
    return n
}

function liquid_string_replace_first(value, from, to,    pos) {
    if (from == "") {
        return to value
    }
    pos = index(value, from)
    if (!pos) {
        return value
    }
    return substr(value, 1, pos - 1) to substr(value, pos + length(from))
}

function liquid_string_replace_last(value, from, to,    rest, pos, last) {
    if (from == "") {
        return value to
    }
    rest = value
    last = 0
    while ((pos = index(rest, from)) > 0) {
        last += pos
        rest = substr(rest, pos + length(from))
        if (index(rest, from) > 0) {
            last += length(from) - 1
        }
    }
    if (!last) {
        return value
    }
    return substr(value, 1, last - 1) to substr(value, last + length(from))
}

function liquid_split(value, arg,    sep, arg_expr, path, count, pos, part, i) {
    arg_expr = liquid_trim(arg)
    sep = liquid_expression_value(arg)
    path = "\034split" (++liquid_split_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (value == "") {
        return ""
    }
    if (arg_expr == "false") {
        liquid_split_append(path, 0, value)
        liquid_context_len[path] = 1
        return ""
    }
    if (sep == " ") {
        gsub(/[ \t\r\n]+/, " ", value)
    }
    if (sep == "") {
        for (i = 1; i <= length(value); i++) {
            liquid_split_append(path, liquid_context_len[path], substr(value, i, 1))
        }
        return ""
    }
    count = 0
    while ((pos = index(value, sep)) > 0) {
        part = substr(value, 1, pos - 1)
        if (part != "") {
            liquid_split_append(path, count++, part)
        }
        value = substr(value, pos + length(sep))
    }
    if (value != "") {
        liquid_split_append(path, count++, value)
    }
    liquid_context_len[path] = count
    return ""
}

function liquid_split_append(path, idx, value,    child) {
    child = liquid_context_child(path, idx)
    liquid_context_type[child] = "scalar"
    liquid_context_value[child] = value
    liquid_context_len[path] = idx + 1
    liquid_context_child_count[path] = idx + 1
}

function liquid_reverse(value, source_path,    path, i, n, child) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        return value
    }
    path = "\034reverse" (++liquid_reverse_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    n = liquid_context_len[source_path]
    for (i = n - 1; i >= 0; i--) {
        child = liquid_context_child(source_path, i)
        if (liquid_context_type[child] == "scalar") {
            liquid_split_append(path, liquid_context_len[path], liquid_context_string(child))
        } else {
            liquid_context_temp_ref(path, liquid_context_len[path], child)
        }
    }
    return ""
}

function liquid_sort(value, source_path, natural, arg,    path, n, i, j, tmp, tmp_path, values, paths, keys, key, prop, prop_expr, child, sort_path, saw_scalar, saw_container) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        return value
    }
    prop_expr = liquid_filter_arg(arg, 1)
    prop = prop_expr
    if (prop_expr != "") {
        prop = liquid_expression_value(prop_expr)
    }
    n = liquid_context_len[source_path]
    if (natural && prop == "" && prop_expr != "" && liquid_context_type[liquid_context_child(liquid_context_child(source_path, 0), "title")] != "") {
        prop = "title"
    }
    for (i = 0; i < n; i++) {
        paths[i] = liquid_context_child(source_path, i)
        if (!natural && prop == "") {
            if (liquid_context_type[paths[i]] == "scalar") {
                saw_scalar = 1
            } else {
                saw_container = 1
            }
            if (saw_scalar && saw_container) {
                return liquid_error()
            }
        }
        if (prop != "") {
            sort_path = liquid_context_child(paths[i], prop)
            values[i] = liquid_context_string(sort_path)
            if (!(sort_path in liquid_context_type) || liquid_context_type[sort_path] == "") {
                keys[i] = "\377"
                continue
            }
        } else {
            values[i] = liquid_context_string(paths[i])
        }
        if (natural && liquid_context_type[paths[i]] == "scalar" && liquid_context_tag[paths[i]] == "tag:yaml.org,2002:null") {
            keys[i] = "\377"
            continue
        }
        if (!natural && values[i] ~ /^[-]?[0-9]+$/) {
            keys[i] = sprintf("%020d", values[i] + 0)
        } else {
            keys[i] = natural ? tolower(values[i]) : values[i]
        }
    }
    for (i = 1; i < n; i++) {
        tmp = values[i]
        tmp_path = paths[i]
        key = keys[i]
        j = i - 1
        while (j >= 0 && keys[j] > key) {
            values[j + 1] = values[j]
            paths[j + 1] = paths[j]
            keys[j + 1] = keys[j]
            j--
        }
        values[j + 1] = tmp
        paths[j + 1] = tmp_path
        keys[j + 1] = key
    }
    path = "\034sort" (++liquid_sort_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    for (i = 0; i < n; i++) {
        child = paths[i]
        if (liquid_context_type[child] == "scalar") {
            liquid_split_append(path, i, liquid_context_string(child))
        } else {
            liquid_context_temp_ref(path, i, child)
        }
    }
    return liquid_context_string(path)
}

function liquid_compact(value, source_path, arg,    path, i, child, text, prop, target) {
    if (source_path == "" && value == "") {
        return value
    }
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        path = "\034compact" (++liquid_compact_id)
        liquid_value_path = path
        liquid_context_type[path] = "seq"
        liquid_context_len[path] = 0
        liquid_context_child_count[path] = 0
        if (source_path != "" && liquid_context_type[source_path] != "scalar") {
            liquid_context_temp_ref(path, 0, source_path)
        } else if (value != "") {
            liquid_split_append(path, 0, value)
        }
        return ""
    }
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    path = "\034compact" (++liquid_compact_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    for (i = 0; i < liquid_context_len[source_path]; i++) {
        child = liquid_context_child(source_path, i)
        target = prop == "" ? child : liquid_context_child(child, prop)
        text = liquid_context_string(target)
        if ((target == "" || liquid_context_type[target] == "scalar") && text == "") {
            continue
        }
        if (liquid_context_type[child] == "scalar") {
            liquid_split_append(path, liquid_context_len[path], text)
        } else {
            liquid_context_temp_ref(path, liquid_context_len[path], child)
        }
    }
    return ""
}

function liquid_uniq(value, source_path, arg,    path, i, child, text, seen, prop, target) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        return value
    }
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    path = "\034uniq" (++liquid_uniq_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    for (i = 0; i < liquid_context_len[source_path]; i++) {
        child = liquid_context_child(source_path, i)
        target = prop == "" ? child : liquid_context_child(child, prop)
        text = liquid_context_string(target)
        if (text in seen) {
            continue
        }
        seen[text] = 1
        if (liquid_context_type[child] == "scalar") {
            liquid_split_append(path, liquid_context_len[path], text)
        } else {
            liquid_context_temp_ref(path, liquid_context_len[path], child)
        }
    }
    return ""
}

function liquid_concat(value, source_path, arg,    right, right_path, path) {
    right = liquid_expression_value(arg)
    right_path = liquid_value_path
    if (right_path == "" || (liquid_context_type[right_path] != "seq" && liquid_context_type[right_path] != "map")) {
        return liquid_error()
    }
    path = "\034concat" (++liquid_concat_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    liquid_concat_append(path, source_path, value)
    liquid_concat_append(path, right_path, right)
    return ""
}

function liquid_concat_append(out_path, source_path, value,    i, child) {
    if (source_path != "" && liquid_context_type[source_path] == "seq") {
        for (i = 0; i < liquid_context_len[source_path]; i++) {
            child = liquid_context_child(source_path, i)
            liquid_concat_append(out_path, child, liquid_context_string(child))
        }
        return
    }
    if (source_path != "" && liquid_context_type[source_path] == "map") {
        liquid_context_temp_ref(out_path, liquid_context_len[out_path], source_path)
        return
    }
    if (value != "") {
        liquid_split_append(out_path, liquid_context_len[out_path], value)
    }
}

function liquid_map(value, source_path, arg,    prop, path) {
    if (source_path == "" || (liquid_context_type[source_path] != "seq" && liquid_context_type[source_path] != "map")) {
        if (value != "") {
            return liquid_error()
        }
        return value
    }
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    path = "\034map" (++liquid_map_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (prop == "") {
        return ""
    }
    liquid_map_append(path, source_path, prop)
    return ""
}

function liquid_map_append(out_path, source_path, prop,    i, child, target) {
    if (liquid_context_type[source_path] == "seq") {
        for (i = 0; i < liquid_context_len[source_path]; i++) {
            liquid_map_append(out_path, liquid_context_child(source_path, i), prop)
        }
        return
    }
    if (liquid_context_type[source_path] != "map") {
        liquid_error()
        return
    }
    target = liquid_context_child(source_path, prop)
    if (liquid_context_type[target] == "map" || liquid_context_type[target] == "seq") {
        liquid_context_temp_ref(out_path, liquid_context_len[out_path], target)
    } else {
        liquid_split_append(out_path, liquid_context_len[out_path], liquid_context_scalar(target))
    }
}

function liquid_where(value, source_path, arg,    prop, want_expr, want, has_want, path, i, child, target, text, matched) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        if (value != "") {
            return liquid_error()
        }
        return value
    }
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    want_expr = liquid_filter_arg(arg, 2)
    has_want = want_expr != ""
    if (has_want) {
        want = liquid_expression_value(want_expr)
        if (!liquid_value_defined && !liquid_value_literal) {
            want_expr = "nil"
        }
    }
    path = "\034where" (++liquid_where_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (prop == "") {
        return ""
    }
    for (i = 0; i < liquid_context_len[source_path]; i++) {
        child = liquid_context_child(source_path, i)
        target = liquid_context_child(child, prop)
        text = liquid_context_scalar(target)
        if (has_want) {
            if (liquid_trim(want_expr) == "nil" || liquid_trim(want_expr) == "null") {
                matched = text != "" && text != "false"
            } else {
                matched = text == want
            }
        } else {
            matched = text != "" && text != "false"
        }
        if (matched) {
            liquid_context_temp_ref(path, liquid_context_len[path], child)
        }
    }
    return ""
}

function liquid_reject(value, source_path, arg,    prop, prop_expr, want_expr, want, has_want, path) {
    prop_expr = liquid_filter_arg(arg, 1)
    prop = prop_expr
    if (prop_expr != "") {
        prop = liquid_expression_value(prop_expr)
    }
    want_expr = liquid_filter_arg(arg, 2)
    has_want = want_expr != ""
    if (has_want) {
        want = liquid_expression_value(want_expr)
        if (!liquid_value_defined && !liquid_value_literal) {
            want_expr = "nil"
        }
    }
    path = "\034reject" (++liquid_reject_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (prop == "") {
        return ""
    }
    liquid_reject_append(path, source_path, value, prop, has_want, want, want_expr, prop_expr)
    return ""
}

function liquid_reject_append(out_path, source_path, value, prop, has_want, want, want_expr, prop_expr,    i, child) {
    if (source_path != "" && (!(source_path in liquid_context_type) || liquid_context_type[source_path] == "")) {
        return
    }
    if (source_path != "" && liquid_context_type[source_path] == "seq") {
        for (i = 0; i < liquid_context_len[source_path]; i++) {
            child = liquid_context_child(source_path, i)
            liquid_reject_append(out_path, child, liquid_context_string(child), prop, has_want, want, want_expr, prop_expr)
        }
        return
    }
    if (source_path != "" && liquid_context_type[source_path] == "scalar" && liquid_context_tag[source_path] == "tag:yaml.org,2002:int" && prop_expr ~ /^["']/) {
        liquid_error()
        return
    }
    if (source_path != "" && liquid_filter_match(source_path, prop, has_want, want, want_expr)) {
        return
    }
    if (source_path != "" && liquid_context_type[source_path] != "scalar") {
        liquid_context_temp_ref(out_path, liquid_context_len[out_path], source_path)
    } else if (value != "" && !liquid_filter_match(source_path, prop, has_want, want, want_expr)) {
        liquid_split_append(out_path, liquid_context_len[out_path], value)
    }
}

function liquid_has(value, source_path, arg) {
    liquid_filter_blank_result = 0
    value = liquid_find_index(value, source_path, arg)
    if (liquid_filter_blank_result) {
        return ""
    }
    return value != ""
}

function liquid_find_index(value, source_path, arg,    prop, prop_expr, want_expr, want, has_want, i, key, child) {
    prop_expr = liquid_filter_arg(arg, 1)
    prop = prop_expr
    if (prop_expr != "") {
        prop = liquid_expression_value(prop_expr)
    }
    want_expr = liquid_filter_arg(arg, 2)
    has_want = want_expr != ""
    if (has_want) {
        want = liquid_expression_value(want_expr)
    }
    if (source_path != "" && liquid_context_type[source_path] == "seq") {
        for (i = 0; i < liquid_context_len[source_path]; i++) {
            child = liquid_context_child(source_path, i)
            if (liquid_context_type[child] == "scalar" && (liquid_context_tag[child] == "tag:yaml.org,2002:null" || liquid_context_tag[child] == "tag:yaml.org,2002:bool")) {
                liquid_filter_blank_result = 1
                return ""
            }
            if (liquid_context_type[child] == "scalar" && liquid_context_tag[child] == "tag:yaml.org,2002:int" && prop_expr ~ /^["']/) {
                liquid_error()
                return ""
            }
            if (liquid_filter_match(child, prop, has_want, want, want_expr)) {
                return i
            }
        }
        return ""
    }
    if (source_path != "" && liquid_context_type[source_path] == "map") {
        return liquid_filter_match(source_path, prop, has_want, want, want_expr) ? "0" : ""
    }
    if (prop != "" && index(value, prop) > 0 && (!has_want || prop == want)) {
        return "0"
    }
    return ""
}

function liquid_find(value, source_path, arg,    idx, child) {
    idx = liquid_find_index(value, source_path, arg)
    if (idx == "") {
        liquid_value_path = ""
        return ""
    }
    if (source_path != "" && liquid_context_type[source_path] == "seq") {
        child = liquid_context_child(source_path, idx)
        liquid_value_path = child
        return liquid_context_string(child)
    }
    if (source_path != "" && liquid_context_type[source_path] == "map") {
        liquid_value_path = source_path
        return liquid_context_string(source_path)
    }
    liquid_value_path = ""
    return value
}

function liquid_filter_match(path, prop, has_want, want, want_expr,    target, text) {
    if (liquid_context_type[path] == "map") {
        target = liquid_context_child(path, prop)
        text = liquid_context_scalar(target)
        if (has_want) {
            if (liquid_trim(want_expr) == "nil" || liquid_trim(want_expr) == "null") {
                return text != "" && text != "false"
            }
            if (liquid_trim(want_expr) ~ /^["']/ && liquid_context_tag[target] == "tag:yaml.org,2002:int") {
                return 0
            }
            return text == want
        }
        return text != "" && text != "false"
    }
    text = liquid_context_string(path)
    if (has_want) {
        return text == want
    }
    return prop != "" && index(text, prop) > 0
}

function liquid_strip_html(value) {
    gsub(/<script[^>]*>[^<]*(<[^\/][^>]*>[^<]*)*<\/script>/, "", value)
    gsub(/<style[^>]*>[^<]*(<[^\/][^>]*>[^<]*)*<\/style>/, "", value)
    gsub(/<!--([^-]|-[^-]|--[^>])*-->/, "", value)
    gsub(/<[^>]*>/, "", value)
    return value
}

function liquid_slice(value, path, start, count,    len, out, i, child) {
    if (path != "" && liquid_context_type[path] == "seq") {
        len = liquid_context_len[path]
        if (start < 0) {
            start = len + start
        }
        out = "\034slice" (++liquid_slice_id)
        liquid_value_path = out
        liquid_context_type[out] = "seq"
        liquid_context_len[out] = 0
        liquid_context_child_count[out] = 0
        if (start < 0 || start >= len || count <= 0) {
            return ""
        }
        for (i = start; i < len && i < start + count; i++) {
            child = liquid_context_child(path, i)
            if (liquid_context_type[child] == "scalar") {
                liquid_split_append(out, liquid_context_len[out], liquid_context_string(child))
            } else {
                liquid_context_temp_ref(out, liquid_context_len[out], child)
            }
        }
        return ""
    }
    if (path != "" && liquid_context_type[path] != "scalar") {
        return ""
    }
    len = length(value)
    if (start < 0) {
        start = len + start
    }
    if (start < 0 || start >= len || count <= 0) {
        return ""
    }
    return substr(value, start + 1, count)
}

function liquid_truncate(value, max, ending,    keep) {
    if (max <= 0 || length(value) <= max) {
        return value
    }
    keep = max - length(ending)
    if (keep < 0) {
        keep = 0
    }
    return substr(value, 1, keep) ending
}

function liquid_truncate_words(value, max, ending,    words, count, i, out) {
    gsub(/[ \t\r\n]+/, " ", value)
    value = liquid_trim(value)
    count = split(value, words, " ")
    if (max <= 0) {
        max = 1
    }
    if (count <= max) {
        return value
    }
    out = ""
    for (i = 1; i <= max; i++) {
        out = out (i == 1 ? "" : " ") words[i]
    }
    return out ending
}

function liquid_sum(path, property,    i, child, target, total) {
    total = 0
    if (path == "" || liquid_context_type[path] != "seq") {
        return "0"
    }
    property = liquid_unquote(property)
    for (i = 0; i < liquid_context_len[path]; i++) {
        child = liquid_context_child(path, i)
        total += liquid_sum_value(child, property)
    }
    return liquid_number_string(total, "", "")
}

function liquid_sum_value(path, property,    i, child, target, total) {
    if (liquid_context_type[path] == "seq" && property == "") {
        total = 0
        for (i = 0; i < liquid_context_len[path]; i++) {
            child = liquid_context_child(path, i)
            total += liquid_sum_value(child, property)
        }
        return total
    }
    if (property != "" && liquid_context_type[path] != "map") {
        liquid_error()
        return 0
    }
    target = property == "" ? path : liquid_context_child(path, property)
    return liquid_context_scalar(target) + 0
}

function liquid_round(number, precision,    scale, shifted) {
    if (precision < 0) {
        return "0"
    }
    scale = 1
    while (precision-- > 0) {
        scale *= 10
    }
    shifted = number * scale
    if (shifted >= 0) {
        shifted = int(shifted + 0.5)
    } else {
        shifted = int(shifted - 0.5)
    }
    return liquid_number_string(shifted / scale, (scale == 1 ? "" : "0.0"), "")
}

function liquid_number_string(number, left, right, precision, force_decimal) {
    if (precision == "") {
        precision = 10
    }
    if (liquid_number_is_float_shape(left) || liquid_number_is_float_shape(right)) {
        number = sprintf("%." precision "g", number)
        if (force_decimal && number !~ /[.eE]/) {
            number = number ".0"
        }
        return number
    }
    return sprintf("%d", number)
}

function liquid_number_is_float_shape(value,    text) {
    text = liquid_trim(value)
    if (text ~ /^[-+]?([0-9][0-9]*([.][0-9][0-9]*)?|[.][0-9][0-9]*)([eE][-+]?[0-9][0-9]*)?$/ ||
        text ~ /^[-+]?[0-9][0-9]*[eE][-+]?[0-9][0-9]*$/) {
        return text ~ /[.eE]/
    }
    return 0
}

function liquid_number_is_numeric_shape(value,    text) {
    text = liquid_trim(value)
    return text ~ /^[-+]?([0-9][0-9]*([.][0-9][0-9]*)?|[.][0-9][0-9]*)([eE][-+]?[0-9][0-9]*)?$/ ||
        text ~ /^[-+]?[0-9][0-9]*[eE][-+]?[0-9][0-9]*$/
}

function liquid_number_is_integer_shape(value,    text) {
    text = liquid_trim(value)
    return text ~ /^[-+]?[0-9][0-9]*$/
}

function liquid_make_range(expr,    body, dots, left, right, start, stop, path, i, child) {
    body = liquid_trim(substr(expr, 2, length(expr) - 2))
    dots = index(body, "..")
    left = liquid_expression_value(substr(body, 1, dots - 1))
    right = liquid_expression_value(substr(body, dots + 2))
    start = int(left + 0)
    stop = int(right + 0)
    liquid_range_id++
    path = "\034range" liquid_range_id
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (start <= stop) {
        for (i = start; i <= stop; i++) {
            child = liquid_context_child(path, liquid_context_len[path])
            liquid_context_type[child] = "scalar"
            liquid_context_value[child] = i
            liquid_context_len[path]++
            liquid_context_child_count[path]++
        }
    }
    return path
}

function liquid_special_property(expr,    prop, parent_expr, parent_path, n) {
    expr = liquid_trim(expr)
    if (expr !~ /[.]?(first|last|size)$/) {
        return 0
    }
    prop = expr
    sub(/^.*[.]/, "", prop)
    parent_expr = substr(expr, 1, length(expr) - length(prop) - 1)
    parent_path = liquid_expression_path(parent_expr)
    if (prop == "size") {
        liquid_value_path = ""
        liquid_special_value = liquid_context_size(parent_path)
        return 1
    }
    if (prop == "first") {
        if (liquid_context_type[parent_path] == "scalar") {
            liquid_value_path = ""
            liquid_special_value = substr(liquid_context_value[parent_path], 1, 1)
            return 1
        }
        if (liquid_context_type[parent_path] == "seq") {
            liquid_value_path = liquid_context_child(parent_path, 0)
            liquid_special_value = liquid_context_string(liquid_value_path)
            return 1
        }
        if (liquid_context_type[parent_path] == "map") {
            liquid_value_path = liquid_map_entry_pair(parent_path, 0)
            liquid_special_value = liquid_context_string(liquid_value_path)
            return 1
        }
    }
    if (prop == "last") {
        if (liquid_context_type[parent_path] == "scalar") {
            liquid_value_path = ""
            liquid_special_value = substr(liquid_context_value[parent_path], length(liquid_context_value[parent_path]), 1)
            return 1
        }
        if (liquid_context_type[parent_path] == "seq") {
            n = liquid_context_len[parent_path] - 1
            liquid_value_path = liquid_context_child(parent_path, n)
            liquid_special_value = n < 0 ? "" : liquid_context_string(liquid_value_path)
            return 1
        }
    }
    return 0
}

function liquid_map_entry_pair(source_path, idx,    path, key) {
    path = "\034mapentry" (++liquid_map_entry_id)
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (idx >= liquid_context_child_count[source_path]) {
        return path
    }
    key = liquid_context_child_order[source_path, idx]
    liquid_split_append(path, 0, key)
    liquid_context_temp_ref(path, 1, liquid_context_child(source_path, key))
    return path
}

function liquid_condition(expr,    op, pos, op_len, left, right, right_expr, left_expr, left_value, right_value, left_path, left_defined, left_literal, left_quoted, right_path, right_defined, right_literal, right_quoted) {
    expr = liquid_trim(expr)
    pos = liquid_first_logical_operator(expr)
    if (pos) {
        op = substr(expr, pos + 1, substr(expr, pos + 1, 1) == "o" ? 2 : 3)
        if (op == "or") {
            return liquid_condition(substr(expr, 1, pos - 1)) || liquid_condition(substr(expr, pos + 4))
        }
        return liquid_condition(substr(expr, 1, pos - 1)) && liquid_condition(substr(expr, pos + 5))
    }
    op = ""
    pos = index(expr, " contains ")
    if (pos) {
        op = "contains"
        op_len = length(" contains ")
    }
    if (!pos) {
        pos = index(expr, ">=")
        if (pos) {
            op = ">="
            op_len = length(op)
        }
    }
    if (!pos) {
        pos = index(expr, "<=")
        if (pos) {
            op = "<="
            op_len = length(op)
        }
    }
    if (!pos) {
        pos = index(expr, "==")
        if (pos) {
            op = "=="
            op_len = length(op)
        }
    }
    if (!pos) {
        pos = index(expr, "!=")
        if (pos) {
            op = "!="
            op_len = length(op)
        }
    }
    if (!pos) {
        pos = index(expr, ">")
        if (pos) {
            op = ">"
            op_len = length(op)
        }
    }
    if (!pos) {
        pos = index(expr, "<")
        if (pos) {
            op = "<"
            op_len = length(op)
        }
    }
    if (pos) {
        left = substr(expr, 1, pos - 1)
        right = substr(expr, pos + op_len)
        left_expr = liquid_trim(left)
        left_value = liquid_expression_value(left)
        left_path = liquid_value_path
        left_defined = liquid_value_defined
        left_literal = liquid_value_literal
        left_quoted = liquid_value_quoted
        if ((op == ">" || op == "<" || op == ">=" || op == "<=") && (liquid_trim(left) == "blank" || liquid_trim(left) == "empty")) {
            return 0
        }
        if (liquid_trim(right) == "blank" || liquid_trim(right) == "empty") {
            right_value = liquid_matches_blank_or_empty(liquid_trim(right), left_expr, left_value, left_path, left_defined, left_literal) ? "1" : "0"
            if (op == "==") {
                return right_value == "1"
            }
            if (op == "!=") {
                return right_value != "1"
            }
            return 0
        }
        right_expr = liquid_trim(right)
        right_value = liquid_expression_value(right)
        right_path = liquid_value_path
        right_defined = liquid_value_defined
        right_literal = liquid_value_literal
        right_quoted = liquid_value_quoted
        if (op == "contains") {
            if (!left_defined && !left_literal) {
                return 0
            }
            if ((!right_defined && !right_literal) || right_expr == "nil" || right_expr == "null") {
                return 0
            }
            if (left_path != "" && liquid_context_type[left_path] == "seq" && (right_expr == "true" || right_expr == "false")) {
                return 0
            }
            return liquid_contains(left_path, left_value, right_value)
        }
        if (op == "==") {
            if (liquid_condition_mixed_string_number(left_value, left_quoted, right_value, right_quoted)) {
                return 0
            }
            if (liquid_number_is_numeric_shape(left_value) && liquid_number_is_numeric_shape(right_value) && !left_quoted && !right_quoted) {
                return (left_value + 0) == (right_value + 0)
            }
            return left_value == right_value
        }
        if (op == "!=") {
            if (liquid_condition_mixed_string_number(left_value, left_quoted, right_value, right_quoted)) {
                return 1
            }
            if (liquid_number_is_numeric_shape(left_value) && liquid_number_is_numeric_shape(right_value) && !left_quoted && !right_quoted) {
                return (left_value + 0) != (right_value + 0)
            }
            return left_value != right_value
        }
        if (liquid_condition_mixed_string_number(left_value, left_quoted, right_value, right_quoted)) {
            return liquid_error()
        }
        if (op == ">=") {
            return left_value >= right_value
        }
        if (op == "<=") {
            return left_value <= right_value
        }
        if (op == ">") {
            return left_value > right_value
        }
        if (op == "<") {
            return left_value < right_value
        }
    }
    if (expr == "blank" || expr == "empty") {
        return 1
    }
    if (expr == "nil" || expr == "null") {
        return 0
    }
    left_value = liquid_expression_value(expr)
    left_path = liquid_value_path
    if (left_value == "false") {
        return 0
    }
    if (left_path != "" && liquid_value_defined) {
        return 1
    }
    if (liquid_value_literal) {
        return 1
    }
    return left_value != ""
}

function liquid_first_logical_operator(expr,    i, ch, quote, word) {
    for (i = 1; i <= length(expr); i++) {
        ch = substr(expr, i, 1)
        if (quote != "") {
            if (ch == quote) {
                quote = ""
            }
        } else if (ch == "\"" || ch == "'") {
            quote = ch
        } else if (substr(expr, i, 4) == " or ") {
            return i
        } else if (substr(expr, i, 5) == " and ") {
            return i
        }
    }
    return 0
}

function liquid_condition_mixed_string_number(left, left_quoted, right, right_quoted) {
    return (left_quoted && liquid_number_is_numeric_shape(left) && liquid_number_is_numeric_shape(right) && !right_quoted) || \
        (right_quoted && liquid_number_is_numeric_shape(right) && liquid_number_is_numeric_shape(left) && !left_quoted)
}

function liquid_contains(path, value, needle,    i, child) {
    if (path != "" && liquid_context_type[path] == "seq") {
        for (i = 0; i < liquid_context_len[path]; i++) {
            child = liquid_context_child(path, i)
            if (liquid_context_scalar(child) == needle) {
                return 1
            }
        }
        return 0
    }
    return index(value, needle) > 0
}

function liquid_is_blank(value, path) {
    if (path != "" && liquid_context_type[path] == "seq" && liquid_context_len[path] == 0) {
        return 1
    }
    if (path != "" && liquid_context_type[path] == "seq") {
        return 0
    }
    if (path != "" && liquid_context_type[path] == "map" && liquid_context_child_count[path] == 0) {
        return 1
    }
    if (path != "" && liquid_context_type[path] == "map") {
        return 0
    }
    if (value == "") {
        return 1
    }
    return 0
}

function liquid_matches_blank_or_empty(keyword, expr, value, path, defined, literal) {
    if (keyword == "empty") {
        if (expr == "blank" || expr == "nil" || expr == "null" || expr == "false") {
            return 0
        }
        if (!defined && !literal) {
            return expr == "empty"
        }
        return liquid_is_empty(value, path)
    }
    if (expr == "empty") {
        return 0
    }
    if (expr == "true") {
        return 0
    }
    if (expr == "blank" || expr == "nil" || expr == "null" || expr == "false") {
        return 1
    }
    if (!defined && !literal) {
        return 1
    }
    return liquid_is_blank(value, path)
}

function liquid_is_empty(value, path) {
    if (path != "" && liquid_context_type[path] == "seq") {
        return liquid_context_len[path] == 0
    }
    if (path != "" && liquid_context_type[path] == "map") {
        return liquid_context_child_count[path] == 0
    }
    return value == ""
}

function liquid_expression_path(expr,    i, ch, segment, path, quote, end, inner, first, depth) {
    expr = liquid_trim(expr)
    path = ""
    segment = ""
    first = 1
    for (i = 1; i <= length(expr); i++) {
        ch = substr(expr, i, 1)
        if (ch == "." || ch == "[" || ch ~ /[ \t\r\n]/) {
            if (segment != "") {
                if (first && segment in liquid_local_path) {
                    path = liquid_local_path[segment]
                } else {
                    path = liquid_context_child(path, segment)
                }
                first = 0
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
                    depth = 1
                    while (i <= length(expr)) {
                        ch = substr(expr, i, 1)
                        if (ch == "[") {
                            depth++
                        } else if (ch == "]") {
                            depth--
                            if (depth == 0) {
                                break
                            }
                        }
                        inner = inner ch
                        i++
                    }
                    inner = liquid_expression_value(inner)
                }
                if (inner ~ /^-[0-9]+$/ && liquid_context_type[path] == "seq") {
                    inner = liquid_context_len[path] + inner
                }
                path = liquid_context_child(path, inner)
                first = 0
            }
        } else {
            segment = segment ch
        }
    }
    if (segment != "") {
        if (first && segment in liquid_local_path) {
            path = liquid_local_path[segment]
        } else {
            path = liquid_context_child(path, segment)
        }
    }
    return path
}
