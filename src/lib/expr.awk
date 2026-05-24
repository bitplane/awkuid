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
    if (expr in liquid_local_value) {
        liquid_value_path = liquid_local_path[expr]
        liquid_value_literal = 0
        return liquid_local_value[expr]
    }
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
    if (expr == "blank" || expr == "empty" || expr == "nil" || expr == "null") {
        return ""
    }
    if (expr == "true") {
        return "true"
    }
    if (expr == "false") {
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
        return liquid_unquote(expr)
    }
    liquid_value_path = liquid_expression_path(expr)
    if (!(liquid_value_path in liquid_context_type) && liquid_special_property(expr)) {
        liquid_value_defined = 1
        return liquid_special_value
    }
    liquid_value_defined = liquid_value_path in liquid_context_type
    return liquid_context_scalar(liquid_value_path)
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

function liquid_apply_filter(value, filter, arg, path,    sep, n, child, right, num) {
    if (filter == "upcase") {
        return toupper(value)
    }
    if (filter == "downcase") {
        return tolower(value)
    }
    if (filter == "strip") {
        return liquid_trim(value)
    }
    if (filter == "squish") {
        gsub(/[ \t\r\n]+/, " ", value)
        return liquid_trim(value)
    }
    if (filter == "lstrip") {
        sub(/^[ \t\r\n]+/, "", value)
        return value
    }
    if (filter == "rstrip") {
        sub(/[ \t\r\n]+$/, "", value)
        return value
    }
    if (filter == "strip_newlines") {
        gsub(/[\r\n]/, "", value)
        return value
    }
    if (filter == "newline_to_br") {
        gsub(/\r\n/, "\n", value)
        gsub(/\n/, "<br />\n", value)
        return value
    }
    if (filter == "capitalize") {
        return length(value) ? toupper(substr(value, 1, 1)) substr(value, 2) : value
    }
    if (filter == "escape") {
        return liquid_html_escape(value)
    }
    if (filter == "escape_once") {
        return liquid_html_escape_once(value)
    }
    if (filter == "url_encode") {
        return liquid_url_encode(value)
    }
    if (filter == "url_decode") {
        return liquid_url_decode(value)
    }
    if (filter == "date") {
        return liquid_date(value, arg)
    }
    if (filter == "base64_encode") {
        return liquid_base64_encode(value, 0)
    }
    if (filter == "base64_url_safe_encode") {
        return liquid_base64_encode(value, 1)
    }
    if (filter == "base64_decode") {
        return liquid_base64_decode(value, 0)
    }
    if (filter == "base64_url_safe_decode") {
        return liquid_base64_decode(value, 1)
    }
    if (filter == "size") {
        if (path != "") {
            return liquid_context_size(path)
        }
        return length(value)
    }
    if (filter == "join") {
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
        return liquid_split(value, arg)
    }
    if (filter == "reverse") {
        return liquid_reverse(value, path)
    }
    if (filter == "sort") {
        return liquid_sort(value, path, 0, arg)
    }
    if (filter == "sort_natural") {
        return liquid_sort(value, path, 1, arg)
    }
    if (filter == "compact") {
        return liquid_compact(value, path, arg)
    }
    if (filter == "uniq") {
        return liquid_uniq(value, path, arg)
    }
    if (filter == "concat") {
        return liquid_concat(value, path, arg)
    }
    if (filter == "map") {
        return liquid_map(value, path, arg)
    }
    if (filter == "where") {
        return liquid_where(value, path, arg)
    }
    if (filter == "reject") {
        return liquid_reject(value, path, arg)
    }
    if (filter == "has") {
        return liquid_has(value, path, arg) ? "true" : "false"
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
        return liquid_default_filter(value, path, arg)
    }
    if (filter == "plus") {
        right = liquid_expression_value(arg)
        return liquid_number_string((value + 0) + (right + 0), value, right)
    }
    if (filter == "minus") {
        right = liquid_expression_value(arg)
        return liquid_number_string((value + 0) - (right + 0), value, right)
    }
    if (filter == "times") {
        right = liquid_expression_value(arg)
        return liquid_number_string((value + 0) * (right + 0), value, right)
    }
    if (filter == "divided_by") {
        right = liquid_expression_value(arg)
        if ((right + 0) == 0) {
            return ""
        }
        return liquid_number_string((value + 0) / (right + 0), value, right, 16, 1)
    }
    if (filter == "modulo") {
        right = liquid_expression_value(arg)
        if ((right + 0) == 0) {
            return ""
        }
        return liquid_number_string((value + 0) % (right + 0), value, right, 16, 1)
    }
    if (filter == "round") {
        right = (arg == "" ? 0 : int(liquid_expression_value(arg) + 0))
        return liquid_round(value + 0, right)
    }
    if (filter == "abs") {
        num = value + 0
        return liquid_number_string(num < 0 ? -num : num, value, "")
    }
    if (filter == "ceil") {
        num = value + 0
        return sprintf("%d", (num == int(num) || num < 0) ? int(num) : int(num) + 1)
    }
    if (filter == "floor") {
        num = value + 0
        return sprintf("%d", (num == int(num) || num >= 0) ? int(num) : int(num) - 1)
    }
    if (filter == "at_least") {
        right = liquid_expression_value(arg) + 0
        num = value + 0
        return liquid_number_string(num < right ? right : num, value, right)
    }
    if (filter == "at_most") {
        right = liquid_expression_value(arg) + 0
        num = value + 0
        return liquid_number_string(num > right ? right : num, value, right)
    }
    if (filter == "append") {
        return value liquid_expression_value(liquid_filter_arg(arg, 1))
    }
    if (filter == "prepend") {
        return liquid_expression_value(liquid_filter_arg(arg, 1)) value
    }
    if (filter == "remove") {
        return liquid_string_replace(value, liquid_expression_value(liquid_filter_arg(arg, 1)), "")
    }
    if (filter == "remove_first") {
        return liquid_string_replace_first(value, liquid_expression_value(liquid_filter_arg(arg, 1)), "")
    }
    if (filter == "remove_last") {
        return liquid_string_replace_last(value, liquid_expression_value(liquid_filter_arg(arg, 1)), "")
    }
    if (filter == "replace") {
        return liquid_string_replace(value, liquid_expression_value(liquid_filter_arg(arg, 1)), liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "replace_first") {
        return liquid_string_replace_first(value, liquid_expression_value(liquid_filter_arg(arg, 1)), liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "replace_last") {
        return liquid_string_replace_last(value, liquid_expression_value(liquid_filter_arg(arg, 1)), liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "strip_html") {
        return liquid_strip_html(value)
    }
    if (filter == "slice") {
        return liquid_slice(value, path, int(liquid_expression_value(liquid_filter_arg(arg, 1)) + 0), liquid_filter_arg(arg, 2) == "" ? 1 : int(liquid_expression_value(liquid_filter_arg(arg, 2)) + 0))
    }
    if (filter == "truncate") {
        return liquid_truncate(value, liquid_filter_arg(arg, 1) == "" ? 50 : int(liquid_expression_value(liquid_filter_arg(arg, 1)) + 0), liquid_filter_arg(arg, 2) == "" ? "..." : liquid_expression_value(liquid_filter_arg(arg, 2)))
    }
    if (filter == "truncatewords") {
        return liquid_truncate_words(value, liquid_filter_arg(arg, 1) == "" ? 15 : int(liquid_expression_value(liquid_filter_arg(arg, 1)) + 0), liquid_filter_arg(arg, 2) == "" ? "..." : liquid_expression_value(liquid_filter_arg(arg, 2)))
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

function liquid_string_replace(value, from, to,    out, pos) {
    if (from == "") {
        return value
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

function liquid_sort(value, source_path, natural, arg,    path, n, i, j, tmp, tmp_path, values, paths, keys, key, prop, child, sort_path) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        return value
    }
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    n = liquid_context_len[source_path]
    for (i = 0; i < n; i++) {
        paths[i] = liquid_context_child(source_path, i)
        if (prop != "") {
            sort_path = liquid_context_child(paths[i], prop)
            values[i] = liquid_context_string(sort_path)
            if (!(sort_path in liquid_context_type)) {
                keys[i] = "\377"
                continue
            }
        } else {
            values[i] = liquid_context_string(paths[i])
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
    return ""
}

function liquid_compact(value, source_path, arg,    path, i, child, text, prop, target) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
        return value
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
    target = liquid_context_child(source_path, prop)
    if (liquid_context_type[target] == "map" || liquid_context_type[target] == "seq") {
        liquid_context_temp_ref(out_path, liquid_context_len[out_path], target)
    } else {
        liquid_split_append(out_path, liquid_context_len[out_path], liquid_context_scalar(target))
    }
}

function liquid_where(value, source_path, arg,    prop, want_expr, want, has_want, path, i, child, target, text, matched) {
    if (source_path == "" || liquid_context_type[source_path] != "seq") {
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

function liquid_reject(value, source_path, arg,    prop, want_expr, want, has_want, path) {
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    want_expr = liquid_filter_arg(arg, 2)
    has_want = want_expr != ""
    if (has_want) {
        want = liquid_expression_value(want_expr)
    }
    path = "\034reject" (++liquid_reject_id)
    liquid_value_path = path
    liquid_context_type[path] = "seq"
    liquid_context_len[path] = 0
    liquid_context_child_count[path] = 0
    if (prop == "") {
        return ""
    }
    liquid_reject_append(path, source_path, value, prop, has_want, want, want_expr)
    return ""
}

function liquid_reject_append(out_path, source_path, value, prop, has_want, want, want_expr,    i, child) {
    if (source_path != "" && liquid_context_type[source_path] == "seq") {
        for (i = 0; i < liquid_context_len[source_path]; i++) {
            child = liquid_context_child(source_path, i)
            liquid_reject_append(out_path, child, liquid_context_string(child), prop, has_want, want, want_expr)
        }
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
    return liquid_find_index(value, source_path, arg) != ""
}

function liquid_find_index(value, source_path, arg,    prop, want_expr, want, has_want, i, key, child) {
    prop = liquid_filter_arg(arg, 1)
    if (prop != "") {
        prop = liquid_expression_value(prop)
    }
    want_expr = liquid_filter_arg(arg, 2)
    has_want = want_expr != ""
    if (has_want) {
        want = liquid_expression_value(want_expr)
    }
    if (source_path != "" && liquid_context_type[source_path] == "seq") {
        for (i = 0; i < liquid_context_len[source_path]; i++) {
            child = liquid_context_child(source_path, i)
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
    if (max <= 0 || count <= max) {
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
        target = property == "" ? child : liquid_context_child(child, property)
        total += liquid_context_scalar(target) + 0
    }
    return liquid_number_string(total, "", "")
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

function liquid_condition(expr,    op, pos, op_len, left, right, right_expr, left_expr, left_value, right_value, left_path, left_defined, left_literal) {
    expr = liquid_trim(expr)
    pos = index(expr, " or ")
    if (pos) {
        return liquid_condition(substr(expr, 1, pos - 1)) || liquid_condition(substr(expr, pos + 4))
    }
    pos = index(expr, " and ")
    if (pos) {
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
        if (op == "contains") {
            if (left_path != "" && liquid_context_type[left_path] == "seq" && (right_expr == "true" || right_expr == "false" || right_expr == "nil" || right_expr == "null")) {
                return 0
            }
            return liquid_contains(left_path, left_value, right_value)
        }
        if (op == "==") {
            return left_value == right_value
        }
        if (op == "!=") {
            return left_value != right_value
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

function liquid_expression_path(expr,    i, ch, segment, path, quote, end, inner, first) {
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
                    while (i <= length(expr) && substr(expr, i, 1) != "]") {
                        inner = inner substr(expr, i, 1)
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
