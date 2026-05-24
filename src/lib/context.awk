function liquid_context_load(line,    fields, event, path) {
    yaml_event_read(line, fields)
    event = fields[1]
    if ((fields[2] + 0) != 0) {
        return
    }
    path = fields[3]
    if (event == "MAP_START") {
        liquid_context_type[path] = "map"
    } else if (event == "SEQ_START") {
        liquid_context_type[path] = "seq"
        liquid_context_len[path] = 0
    } else if (event == "SEQ_END") {
        liquid_context_len[path] = liquid_context_seq_count[path] + 0
    } else if (event == "SCALAR") {
        liquid_context_type[path] = "scalar"
        liquid_context_value[path] = fields[7]
        liquid_context_note_sequence_item(path)
    } else if (event == "ALIAS") {
        liquid_context_type[path] = "scalar"
        liquid_context_value[path] = ""
        liquid_context_note_sequence_item(path)
    }
}

function liquid_context_note_sequence_item(path,    parent, key) {
    parent = liquid_context_parent_path(path)
    key = liquid_context_path_key(path)
    if (liquid_context_type[parent] == "seq" && key ~ /^[0-9]+$/) {
        if ((key + 1) > liquid_context_seq_count[parent]) {
            liquid_context_seq_count[parent] = key + 1
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
    return yaml_event_path_join(path, key)
}

function liquid_context_scalar(path) {
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
