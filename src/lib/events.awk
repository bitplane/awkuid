function yaml_event_escape(text,    out, i, ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        if (ch == "\\") {
            out = out "\\\\"
        } else if (ch == "\t") {
            out = out "\\t"
        } else if (ch == "\n") {
            out = out "\\n"
        } else if (ch == "\r") {
            out = out "\\r"
        } else if (ch == "\b") {
            out = out "\\b"
        } else if (ch == "/") {
            out = out "\\/"
        } else {
            out = out ch
        }
    }
    return out
}

function yaml_event_unescape(text,    out, i, ch, next_ch) {
    out = ""
    for (i = 1; i <= length(text); i++) {
        ch = substr(text, i, 1)
        next_ch = substr(text, i + 1, 1)
        if (ch == "\\" && next_ch != "") {
            if (next_ch == "t") {
                out = out "\t"
            } else if (next_ch == "n") {
                out = out "\n"
            } else if (next_ch == "r") {
                out = out "\r"
            } else if (next_ch == "b") {
                out = out "\b"
            } else if (next_ch == "f") {
                out = out "\f"
            } else {
                out = out next_ch
            }
            i++
        } else {
            out = out ch
        }
    }
    return out
}

function yaml_event_path_join(parent, key) {
    key = yaml_event_escape(key)
    if (parent == "") {
        return key
    }
    return parent "/" key
}

function yaml_event_read(line, fields,    i, count) {
    count = split(line, fields, "\t")
    for (i = 3; i <= count; i++) {
        fields[i] = yaml_event_unescape(fields[i])
    }
    return count
}
