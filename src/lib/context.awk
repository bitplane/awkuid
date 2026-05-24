function liquid_context_load(line,    fields, event, path) {
    yaml_event_read(line, fields)
    event = fields[1]
    if ((fields[2] + 0) != 0) {
        return
    }
    path = fields[3]
    if (event == "MAP_START") {
        liquid_context_type[path] = "map"
        liquid_context_note_child(path)
    } else if (event == "SEQ_START") {
        liquid_context_type[path] = "seq"
        liquid_context_len[path] = 0
        liquid_context_note_child(path)
    } else if (event == "SEQ_END") {
        liquid_context_len[path] = liquid_context_child_count[path] + 0
    } else if (event == "SCALAR") {
        liquid_context_type[path] = "scalar"
        liquid_context_tag[path] = fields[4]
        liquid_context_value[path] = fields[7]
        liquid_context_note_child(path)
    } else if (event == "ALIAS") {
        liquid_context_type[path] = "scalar"
        liquid_context_value[path] = ""
        liquid_context_note_child(path)
    }
}

function liquid_context_note_child(path,    parent, key, idx) {
    if (path == "") {
        return
    }
    parent = liquid_context_parent_path(path)
    key = liquid_context_path_key(path)
    if (liquid_context_seen_child[parent SUBSEP key]) {
        return
    }
    liquid_context_seen_child[parent SUBSEP key] = 1
    idx = liquid_context_child_count[parent] + 0
    liquid_context_child_order[parent, idx] = key
    liquid_context_child_count[parent] = idx + 1
    if (key ~ /^[0-9]+$/) {
        if ((key + 1) > liquid_context_len[parent]) {
            liquid_context_len[parent] = key + 1
        }
    }
}

function liquid_context_parent_path(path,    i, ch, slash, backslashes, j) {
    slash = 0
    for (i = 1; i <= length(path); i++) {
        ch = substr(path, i, 1)
        if (ch == "/") {
            backslashes = 0
            for (j = i - 1; j >= 1 && substr(path, j, 1) == "\\"; j--) {
                backslashes++
            }
            if (backslashes % 2 == 0) {
                slash = i
            }
        }
    }
    if (!slash) {
        return ""
    }
    return substr(path, 1, slash - 1)
}

function liquid_context_path_key(path,    parent) {
    parent = liquid_context_parent_path(path)
    if (parent == "") {
        return yaml_event_unescape(path)
    }
    return yaml_event_unescape(substr(path, length(parent) + 2))
}

function liquid_context_child(path, key) {
    if (path in liquid_context_ref) {
        return liquid_context_child(liquid_context_ref[path], key)
    }
    return yaml_event_path_join(path, key)
}

function liquid_context_scalar(path) {
    if (path in liquid_context_ref) {
        return liquid_context_scalar(liquid_context_ref[path])
    }
    if (liquid_context_type[path] == "scalar") {
        return liquid_context_value[path]
    }
    if (liquid_context_type[path] == "seq") {
        return ""
    }
    if (liquid_context_type[path] == "map") {
        return ""
    }
    return ""
}

function liquid_context_size(path) {
    if (path in liquid_context_ref) {
        return liquid_context_size(liquid_context_ref[path])
    }
    if (path == "") {
        return 0
    }
    if (liquid_context_type[path] == "scalar") {
        return length(liquid_context_value[path])
    }
    if (liquid_context_type[path] == "seq") {
        return liquid_context_len[path] + 0
    }
    if (liquid_context_type[path] == "map") {
        return liquid_context_child_count[path] + 0
    }
    return 0
}

function liquid_context_string(path) {
    if (path in liquid_context_ref) {
        return liquid_context_string(liquid_context_ref[path])
    }
    if (liquid_context_type[path] == "scalar") {
        return liquid_context_value[path]
    }
    if (liquid_context_type[path] == "map") {
        return "{}"
    }
    if (liquid_context_type[path] == "seq") {
        return liquid_context_join(path, "")
    }
    return ""
}

function liquid_context_join(path, sep,    i, out, child) {
    if (path in liquid_context_ref) {
        path = liquid_context_ref[path]
    }
    if (liquid_context_type[path] != "seq") {
        return liquid_context_string(path)
    }
    out = ""
    for (i = 0; i < liquid_context_len[path]; i++) {
        child = liquid_context_child(path, i)
        out = out (i == 0 ? "" : sep) liquid_context_string(child)
    }
    return out
}

function liquid_context_temp_ref(parent, idx, source,    child) {
    child = liquid_context_child(parent, idx)
    liquid_context_ref[child] = source
    liquid_context_type[child] = liquid_context_type[source]
    liquid_context_len[child] = liquid_context_len[source]
    liquid_context_child_count[child] = liquid_context_child_count[source]
    liquid_context_len[parent] = idx + 1
    liquid_context_child_count[parent] = idx + 1
}
