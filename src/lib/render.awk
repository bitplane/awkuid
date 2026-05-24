function liquid_render(template,    out, rest, out_pos, tag_pos, open_pos, close_pos, expr, tag, end_pos, block, else_pos, true_block, false_block, trim_left, trim_right, close_tag) {
    out = ""
    rest = template
    while (index(rest, "{{") || index(rest, "{%")) {
        out_pos = index(rest, "{{")
        tag_pos = index(rest, "{%")
        if (out_pos && (!tag_pos || out_pos < tag_pos)) {
            open_pos = out_pos
            out = out substr(rest, 1, open_pos - 1)
            rest = substr(rest, open_pos + 2)
            trim_left = substr(rest, 1, 1) == "-"
            if (trim_left) {
                sub(/[ \t\r\n]+$/, "", out)
            }
            close_pos = index(rest, "}}")
            if (!close_pos) {
                out = out "{{" rest
                rest = ""
                break
            }
            expr = substr(rest, 1, close_pos - 1)
            trim_right = substr(expr, length(expr), 1) == "-"
            if (trim_left) {
                sub(/^-/, "", expr)
            }
            if (trim_right) {
                sub(/-$/, "", expr)
            }
            expr = liquid_trim(expr)
            out = out liquid_expression_value(expr)
            rest = substr(rest, close_pos + 2)
            if (trim_right) {
                sub(/^[ \t\r\n]+/, "", rest)
            }
            continue
        }
        open_pos = tag_pos
        out = out substr(rest, 1, open_pos - 1)
        rest = substr(rest, open_pos + 2)
        trim_left = substr(rest, 1, 1) == "-"
        if (trim_left) {
            sub(/[ \t\r\n]+$/, "", out)
        }
        if (rest ~ /^-[ \t]*#/) {
            close_pos = index(rest, "%}")
            if (close_pos) {
                tag = substr(rest, 1, close_pos - 1)
                trim_right = substr(tag, length(tag), 1) == "-"
                rest = substr(rest, close_pos + 2)
                if (trim_right) {
                    sub(/^[ \t\r\n]+/, "", rest)
                }
                continue
            }
        }
        close_pos = index(rest, "%}")
        if (!close_pos) {
            out = out "{%" rest
            rest = ""
            break
        }
        tag = substr(rest, 1, close_pos - 1)
        trim_right = substr(tag, length(tag), 1) == "-"
        if (index(tag, "{%")) {
            base += tag_pos + 1
            continue
        }
        tag = liquid_tag_clean(tag)
        rest = substr(rest, close_pos + 2)
        if (trim_right) {
            sub(/^[ \t\r\n]+/, "", rest)
        }
        if (tag ~ /^assign[ \t\r\n]/) {
            liquid_render_assign(substr(tag, 7))
        } else if (tag ~ /^echo[ \t\r\n]/) {
            out = out liquid_render_expression(substr(tag, 5))
        } else if (tag == "echo") {
            continue
        } else if (tag == "break") {
            liquid_flow_control = "break"
            return out
        } else if (tag == "continue") {
            liquid_flow_control = "continue"
            return out
        } else if (tag ~ /^cycle[ \t\r\n]/) {
            out = out liquid_render_cycle(substr(tag, 7))
        } else if (tag ~ /^increment[ \t\r\n]/) {
            out = out liquid_render_increment(liquid_trim(substr(tag, 10)))
        } else if (tag ~ /^decrement[ \t\r\n]/) {
            out = out liquid_render_decrement(liquid_trim(substr(tag, 10)))
        } else if (tag == "comment" || tag == "doc" || tag ~ /^(comment|doc)[ \t\r\n]/) {
            if (tag ~ /^doc[ \t\r\n]/) {
                return liquid_error()
            }
            close_tag = tag ~ /^comment/ ? "endcomment" : "enddoc"
            end_pos = close_tag == "endcomment" ? liquid_find_comment_end(rest) : liquid_find_end_tag(rest, close_tag)
            if (end_pos > 0) {
                if (tag == "doc" && liquid_doc_contains_doc(rest, end_pos)) {
                    return liquid_error()
                }
                rest = substr(rest, end_pos)
                close_pos = index(rest, "%}")
                if (close_pos && substr(substr(rest, 1, close_pos - 1), length(substr(rest, 1, close_pos - 1)), 1) == "-") {
                    trim_right = 1
                } else {
                    trim_right = 0
                }
                rest = substr(rest, close_pos + 2)
                if (trim_right) {
                    sub(/^[ \t\r\n]+/, "", rest)
                }
            } else if (tag == "doc" || end_pos < 0) {
                return liquid_error()
            }
        } else if (tag == "raw") {
            end_pos = liquid_find_tag_start(rest, "endraw")
            if (end_pos) {
                out = out substr(rest, 1, end_pos - 1)
                rest = liquid_after_tag(rest, end_pos)
            }
        } else if (tag ~ /^if[ \t\r\n]/) {
            end_pos = liquid_find_matching_tag(rest, "if", "endif")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                out = out liquid_render_conditional(substr(tag, 3), block, 0)
                if (liquid_flow_control == "break" || liquid_flow_control == "continue") {
                    return out
                }
            }
        } else if (tag ~ /^unless[ \t\r\n]/) {
            end_pos = liquid_find_matching_tag(rest, "unless", "endunless")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                out = out liquid_render_conditional(substr(tag, 7), block, 1)
                if (liquid_flow_control == "break" || liquid_flow_control == "continue") {
                    return out
                }
            }
        } else if (tag ~ /^case[ \t\r\n]/) {
            end_pos = liquid_find_matching_tag(rest, "case", "endcase")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                out = out liquid_render_case(substr(tag, 5), block)
            }
        } else if (tag ~ /^for[ \t\r\n]/) {
            end_pos = liquid_find_matching_tag(rest, "for", "endfor")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                out = out liquid_render_for(substr(tag, 4), block)
            }
        } else if (tag ~ /^tablerow[ \t\r\n]/) {
            end_pos = liquid_find_matching_tag(rest, "tablerow", "endtablerow")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                out = out liquid_render_tablerow(substr(tag, 9), block)
            }
        } else if (tag == "ifchanged") {
            end_pos = liquid_find_end_tag(rest, "endifchanged")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                true_block = liquid_render(block)
                if (true_block != liquid_ifchanged_last) {
                    out = out true_block
                    liquid_ifchanged_last = true_block
                }
            }
        } else if (tag ~ /^include[ \t\r\n]/) {
            out = out liquid_render_partial(substr(tag, 9), 0)
        } else if (tag ~ /^render[ \t\r\n]/) {
            out = out liquid_render_partial(substr(tag, 8), 1)
        } else if (tag ~ /^capture[ \t\r\n]/) {
            end_pos = liquid_find_end_tag(rest, "endcapture")
            if (end_pos) {
                block = liquid_block_before_close(rest, end_pos)
                rest = liquid_after_tag(rest, end_pos)
                expr = liquid_trim(substr(tag, 8))
                if (!liquid_assign_name_valid(expr)) {
                    return liquid_error()
                }
                liquid_local_value[expr] = liquid_render(block)
                liquid_local_path[expr] = ""
            }
        } else if (tag ~ /^#/) {
            if (!liquid_inline_comment_valid(tag)) {
                return liquid_error()
            }
            continue
        } else if (tag ~ /^liquid([ \t\r\n]|$)/) {
            out = out liquid_render_liquid(substr(tag, 7))
        } else {
            return liquid_error()
        }
    }
    return out rest
}

function liquid_tag_clean(text) {
    text = liquid_trim(text)
    sub(/^-/, "", text)
    sub(/-$/, "", text)
    return liquid_trim(text)
}

function liquid_inline_comment_valid(text,    lines, count, i, line) {
    count = split(text, lines, "\n")
    for (i = 1; i <= count; i++) {
        line = liquid_trim(lines[i])
        if (line != "" && line !~ /^#/) {
            return 0
        }
    }
    return 1
}

function liquid_after_tag(text, pos,    tail, close_pos, tag) {
    tail = substr(text, pos)
    close_pos = index(tail, "%}")
    if (!close_pos) {
        return ""
    }
    tag = substr(tail, 1, close_pos - 1)
    tail = substr(tail, close_pos + 2)
    if (substr(tag, length(tag), 1) == "-") {
        sub(/^[ \t\r\n]+/, "", tail)
    }
    return tail
}

function liquid_block_before_close(text, pos,    block, tail) {
    block = substr(text, 1, pos - 1)
    tail = substr(text, pos)
    if (substr(tail, 1, 3) == "{%-") {
        sub(/[ \t\r\n]+$/, "", block)
    }
    return block
}

function liquid_render_expression(expr,    value) {
    value = liquid_expression_value(expr)
    if (liquid_value_path != "" && \
            (liquid_context_type[liquid_value_path] == "seq" || liquid_context_type[liquid_value_path] == "map")) {
        return liquid_context_string(liquid_value_path)
    }
    return value
}

function liquid_find_end_tag(text, close_name,    rest, offset, tag_pos, close_pos, tag) {
    rest = text
    offset = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        offset += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            offset += tag_pos + 1
            continue
        }
        tag = substr(rest, 1, close_pos - 1)
        if (index(tag, "{%")) {
            offset += tag_pos + 1
            continue
        }
        tag = liquid_tag_clean(tag)
        if (tag == close_name) {
            return offset + 1
        }
        offset += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_find_tag_start(text, close_name,    rest, offset, tag_pos, close_pos, tag) {
    rest = text
    offset = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            offset += tag_pos + 1
            continue
        }
        tag = substr(rest, 1, close_pos - 1)
        if (index(tag, "{%")) {
            offset += tag_pos + 1
            continue
        }
        tag = liquid_tag_clean(tag)
        if (tag == close_name) {
            return offset + tag_pos
        }
        offset += tag_pos + close_pos + 2
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_doc_contains_doc(text, end_pos,    body, rest, tag_pos, close_pos, tag) {
    body = substr(text, 1, end_pos - 1)
    rest = body
    while ((tag_pos = index(rest, "{%")) > 0) {
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        if (tag == "doc" || tag ~ /^doc[ \t\r\n]/) {
            return 1
        }
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_find_comment_end(text,    rest, offset, tag_pos, close_pos, tag, before, depth, raw_depth) {
    rest = text
    offset = 0
    depth = 1
    raw_depth = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        before = substr(rest, 1, tag_pos - 1)
        if (index(before, "{{") && !index(before, "}}")) {
            return -1
        }
        offset += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return -1
        }
        tag = substr(rest, 1, close_pos - 1)
        if (index(tag, "{%")) {
            return -1
        }
        tag = liquid_tag_clean(tag)
        if (raw_depth) {
            if (tag == "endraw") {
                raw_depth--
            }
        } else if (tag == "raw") {
            raw_depth++
        } else if (tag == "comment") {
            depth++
        } else if (tag == "endcomment") {
            depth--
            if (depth == 0) {
                return offset + 1
            }
        }
        offset += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    if (index(rest, "{{") && !index(rest, "}}")) {
        return -1
    }
    return -1
}

function liquid_render_increment(name,    value) {
    value = liquid_counter_value[name] + 0
    liquid_counter_value[name] = value + 1
    if (!(name in liquid_local_value) || liquid_counter_local[name]) {
        liquid_local_value[name] = liquid_counter_value[name]
        liquid_local_path[name] = ""
        liquid_counter_local[name] = 1
    }
    return value
}

function liquid_render_decrement(name,    value) {
    value = liquid_counter_value[name] - 1
    liquid_counter_value[name] = value
    if (!(name in liquid_local_value) || liquid_counter_local[name]) {
        liquid_local_value[name] = value
        liquid_local_path[name] = ""
        liquid_counter_local[name] = 1
    }
    return value
}

function liquid_render_cycle(text,    colon, name_expr, name, args, count, idx, key, value) {
    text = liquid_trim(text)
    colon = liquid_find_unquoted(text, ":")
    if (colon) {
        name_expr = liquid_trim(substr(text, 1, colon - 1))
        name = liquid_expression_value(name_expr)
        if (name == "" && !liquid_value_literal) {
            name = "\034undefined-cycle"
        }
        args = liquid_trim(substr(text, colon + 1))
    } else {
        name = ""
        args = text
    }
    count = liquid_count_filter_args(args)
    if (colon && count == 1 && liquid_cycle_last_count[name] > 2) {
        liquid_cycle_last_count[name] = count
        return ""
    }
    key = colon ? name SUBSEP (count >= 2 ? "multi" : "single") : name SUBSEP count
    idx = liquid_cycle_index[key] + 0
    value = liquid_expression_value(liquid_filter_arg(args, (idx % count) + 1))
    liquid_cycle_index[key] = idx + 1
    if (colon) {
        liquid_cycle_last_count[name] = count
    }
    return value
}

function liquid_count_filter_args(args,    i, part, count) {
    count = 0
    for (i = 1; ; i++) {
        part = liquid_filter_arg(args, i)
        if (part == "") {
            break
        }
        count++
    }
    return count
}

function liquid_render_partial(text, isolated,    name, file, tpl, line, saved_values, saved_paths, saved_counters, saved_counter_locals, result, rest) {
    text = liquid_trim(text)
    name = liquid_partial_name(text)
    if (name == "") {
        return ""
    }
    liquid_partial_save(saved_values, saved_paths)
    if (isolated) {
        liquid_partial_save_counters(saved_counters, saved_counter_locals)
    }
    liquid_partial_args(text)
    if (isolated) {
        liquid_partial_isolate()
    }
    file = liquid_template_dir "/" name ".liquid"
    tpl = ""
    while ((getline line < file) > 0) {
        tpl = tpl (tpl == "" ? "" : "\n") line
    }
    close(file)
    if (liquid_partial_is_for(text)) {
        result = liquid_render_partial_loop(text, name, tpl, isolated)
        liquid_partial_restore(saved_values, saved_paths)
        if (isolated) {
            liquid_partial_restore_counters(saved_counters, saved_counter_locals)
        }
        return result
    }
    liquid_partial_isolated = isolated
    result = liquid_render(tpl)
    liquid_partial_isolated = 0
    if (isolated) {
        liquid_partial_restore(saved_values, saved_paths)
        liquid_partial_restore_counters(saved_counters, saved_counter_locals)
    } else {
        liquid_partial_clear_args()
        for (rest in saved_paths) {
            if (!(rest in liquid_local_path)) {
                liquid_local_path[rest] = saved_paths[rest]
            }
        }
    }
    return result
}

function liquid_partial_is_for(text,    rest) {
    rest = text
    sub(/^[^ \t\r\n,]+/, "", rest)
    return rest ~ /(^|[ \t\r\n,])for[ \t\r\n]/
}

function liquid_render_partial_loop(text, name, tpl, isolated,    rest, parts, source, alias, source_value, source_path, total, i, child_path, out, saved_values, saved_paths, saved_counters, saved_counter_locals) {
    rest = text
    sub(/^[^ \t\r\n,]+/, "", rest)
    sub(/^.*(^|[ \t\r\n,])for[ \t\r\n]+/, "for ", rest)
    split(rest, parts, /[ \t\r\n]+/)
    source = parts[2]
    alias = parts[3] == "as" ? parts[4] : name
    source_value = liquid_expression_value(source)
    source_path = liquid_value_path
    if (source_path in liquid_context_ref) {
        source_path = liquid_context_ref[source_path]
    }
    total = liquid_context_type[source_path] == "seq" ? liquid_context_len[source_path] : 0
    out = ""
    for (i = 0; i < total; i++) {
        liquid_partial_save(saved_values, saved_paths)
        if (isolated) {
            liquid_partial_save_counters(saved_counters, saved_counter_locals)
            for (child_path in liquid_local_value) {
                delete liquid_local_value[child_path]
            }
            for (child_path in liquid_local_path) {
                delete liquid_local_path[child_path]
            }
            for (child_path in liquid_counter_value) {
                delete liquid_counter_value[child_path]
            }
            for (child_path in liquid_counter_local) {
                delete liquid_counter_local[child_path]
            }
        }
        child_path = liquid_context_child(source_path, i)
        liquid_local_path[alias] = child_path
        liquid_local_value[alias] = liquid_context_string(child_path)
        liquid_for_set_meta(i, total, alias, source)
        if (isolated) {
            liquid_no_parentloop++
        }
        out = out liquid_render(tpl)
        if (isolated) {
            liquid_no_parentloop--
        }
        liquid_partial_restore(saved_values, saved_paths)
        if (isolated) {
            liquid_partial_restore_counters(saved_counters, saved_counter_locals)
        }
    }
    return out
}

function liquid_partial_isolate(    k, keep_values, keep_paths) {
    for (k in liquid_partial_arg_names) {
        keep_values[k] = liquid_local_value[k]
        keep_paths[k] = liquid_local_path[k]
    }
    for (k in liquid_local_value) {
        delete liquid_local_value[k]
    }
    for (k in liquid_local_path) {
        delete liquid_local_path[k]
    }
    for (k in keep_values) {
        liquid_local_value[k] = keep_values[k]
    }
    for (k in keep_paths) {
        liquid_local_path[k] = keep_paths[k]
    }
    for (k in liquid_counter_value) {
        delete liquid_counter_value[k]
    }
    for (k in liquid_counter_local) {
        delete liquid_counter_local[k]
    }
}

function liquid_partial_name(text,    first, value) {
    split(text, first, /[ \t\r\n,]+/)
    value = first[1]
    if (value ~ /^["']/) {
        return liquid_unquote(value)
    }
    return liquid_expression_value(value)
}

function liquid_partial_args(text,    rest, parts, count, i, part, colon, name, expr, value, path) {
    rest = text
    sub(/^[^ \t\r\n,]+/, "", rest)
    sub(/^[ \t\r\n]*/, "", rest)
    sub(/^,/, "", rest)
    sub(/^[ \t\r\n]*/, "", rest)
    count = split(rest, parts, ",")
    for (i = 1; i <= count; i++) {
        part = liquid_trim(parts[i])
        if (part == "") {
            continue
        }
        if (part ~ /^with[ \t]/ || part ~ /^for[ \t]/) {
            split(part, parts, /[ \t\r\n]+/)
            name = parts[3] == "as" ? parts[4] : liquid_partial_name(text)
            expr = parts[2]
        } else {
            colon = index(part, ":")
            if (!colon) {
                continue
            }
            name = liquid_trim(substr(part, 1, colon - 1))
            expr = liquid_trim(substr(part, colon + 1))
        }
        liquid_partial_arg_names[name] = 1
        value = liquid_expression_value(expr)
        path = liquid_value_path
        liquid_local_value[name] = value
        liquid_local_path[name] = path
        liquid_partial_arg_value[name] = liquid_local_value[name]
        liquid_partial_arg_path[name] = liquid_local_path[name]
    }
}

function liquid_partial_clear_args(    k) {
    for (k in liquid_partial_arg_names) {
        if (liquid_partial_arg_assigned[k]) {
            liquid_local_value[k] = liquid_partial_arg_value[k]
            liquid_local_path[k] = liquid_partial_arg_path[k]
        } else {
            delete liquid_local_value[k]
            delete liquid_local_path[k]
        }
        delete liquid_partial_arg_names[k]
        delete liquid_partial_arg_value[k]
        delete liquid_partial_arg_path[k]
        delete liquid_partial_arg_assigned[k]
    }
}

function liquid_partial_save(values, paths,    k) {
    for (k in liquid_local_value) {
        values[k] = liquid_local_value[k]
    }
    for (k in liquid_local_path) {
        paths[k] = liquid_local_path[k]
    }
}

function liquid_partial_restore(values, paths,    k) {
    for (k in liquid_local_value) {
        delete liquid_local_value[k]
    }
    for (k in liquid_local_path) {
        delete liquid_local_path[k]
    }
    for (k in values) {
        liquid_local_value[k] = values[k]
    }
    for (k in paths) {
        liquid_local_path[k] = paths[k]
    }
    for (k in liquid_partial_arg_names) {
        delete liquid_partial_arg_names[k]
    }
    for (k in liquid_partial_arg_value) {
        delete liquid_partial_arg_value[k]
        delete liquid_partial_arg_path[k]
        delete liquid_partial_arg_assigned[k]
    }
}

function liquid_partial_save_counters(counters, counter_locals,    k) {
    for (k in liquid_counter_value) {
        counters[k] = liquid_counter_value[k]
    }
    for (k in liquid_counter_local) {
        counter_locals[k] = liquid_counter_local[k]
    }
}

function liquid_partial_restore_counters(counters, counter_locals,    k) {
    for (k in liquid_counter_value) {
        delete liquid_counter_value[k]
    }
    for (k in liquid_counter_local) {
        delete liquid_counter_local[k]
    }
    for (k in counters) {
        liquid_counter_value[k] = counters[k]
    }
    for (k in counter_locals) {
        liquid_counter_local[k] = counter_locals[k]
    }
}

function liquid_find_matching_tag(text, open_name, close_name,    rest, offset, tag_pos, close_pos, tag, depth) {
    rest = text
    offset = 0
    depth = 1
    while ((tag_pos = index(rest, "{%")) > 0) {
        offset += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        if (tag == close_name) {
            depth--
            if (depth == 0) {
                return offset + 1
            }
        } else if (tag ~ ("^" open_name "[ \t\r\n]")) {
            depth++
        }
        offset += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_render_conditional(expr, block, invert,    rest, cond, pos, tag, body, selected, render_body) {
    rest = block
    cond = invert ? !liquid_condition(expr) : liquid_condition(expr)
    while (1) {
        pos = liquid_find_conditional_branch(rest, tag)
        if (pos) {
            body = substr(rest, 1, pos - 1)
            rest = substr(rest, pos)
        } else {
            body = rest
            rest = ""
        }
        if (!selected && cond) {
            render_body = body
            selected = 1
        }
        if (!pos || selected) {
            break
        }
        rest = substr(rest, 3)
        pos = index(rest, "%}")
        tag = liquid_tag_clean(substr(rest, 1, pos - 1))
        rest = substr(rest, pos + 2)
        if (tag ~ /^elsif[ \t\r\n]/) {
            cond = liquid_condition(substr(tag, 6))
        } else if (tag ~ /^else([ \t\r\n]|$)/) {
            cond = 1
        }
    }
    return liquid_render_control_body(render_body, block)
}

function liquid_render_control_body(body, source,    rendered) {
    if (source == "") {
        source = body
    }
    rendered = liquid_render(body)
    if (rendered ~ /^[ \t\r\n]*$/ && !liquid_control_body_has_output(source)) {
        return ""
    }
    return rendered
}

function liquid_control_body_has_output(body,    capture_pos, end_pos, visible) {
    visible = body
    while ((capture_pos = index(visible, "{% capture")) > 0) {
        end_pos = liquid_find_end_tag(substr(visible, capture_pos + 2), "endcapture")
        if (!end_pos) {
            break
        }
        visible = substr(visible, 1, capture_pos - 1) substr(visible, capture_pos + 1 + end_pos)
    }
    return index(visible, "{{") || visible ~ /[{]%[-]?[ \t\r\n]*echo[ \t\r\n]/
}

function liquid_find_conditional_branch(text, tag_out,    rest, offset, tag_pos, close_pos, tag, depth) {
    rest = text
    offset = 0
    depth = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        offset += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        if (depth == 0 && (tag ~ /^elsif[ \t\r\n]/ || tag ~ /^else([ \t\r\n]|$)/)) {
            return offset + 1
        }
        if (tag ~ /^(if|unless)[ \t\r\n]/) {
            depth++
        } else if ((tag == "endif" || tag == "endunless") && depth > 0) {
            depth--
        }
        offset += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_render_assign(text,    eq, name, expr, value, path) {
    eq = index(text, "=")
    if (!eq) {
        return
    }
    name = liquid_trim(substr(text, 1, eq - 1))
    expr = liquid_trim(substr(text, eq + 1))
    if (!liquid_assign_name_valid(name)) {
        return liquid_error()
    }
    if ((name in liquid_partial_arg_names) && !liquid_partial_isolated) {
        value = liquid_expression_value(expr)
        path = liquid_value_path
        liquid_partial_arg_value[name] = value
        liquid_partial_arg_path[name] = path
        liquid_partial_arg_assigned[name] = 1
    } else {
        value = liquid_expression_value(expr)
        path = liquid_value_path
        liquid_local_value[name] = value
        liquid_local_path[name] = path
        if (name in liquid_partial_arg_names) {
            liquid_partial_arg_assigned[name] = 1
        }
    }
    if (name ~ /^[0-9]+$/) {
        liquid_numeric_assign[name] = 1
    }
    delete liquid_counter_local[name]
}

function liquid_assign_name_valid(name) {
    return substr(name, 1, 1) != "-" && substr(name, length(name), 1) != "?"
}

function liquid_render_for(text, block,    parts, var, source, source_value, source_path, source_literal, i, key, child_path, pair_path, out, body, else_block, else_pos, total, start, stop, step, iter, rendered, limit, offset, reversed, source_key, k, saved_values, saved_paths, rest, options, depth, ch, raw) {
    liquid_for_save(saved_values, saved_paths)
    text = liquid_trim(text)
    i = index(text, " in ")
    var = liquid_trim(substr(text, 1, i - 1))
    rest = liquid_trim(substr(text, i + 4))
    if (substr(rest, 1, 1) == "(") {
        depth = 0
        for (i = 1; i <= length(rest); i++) {
            ch = substr(rest, i, 1)
            if (ch == "(") {
                depth++
            } else if (ch == ")") {
                depth--
                if (depth == 0) {
                    break
                }
            }
        }
        source = substr(rest, 1, i)
        options = liquid_trim(substr(rest, i + 1))
    } else {
        split(rest, parts, /[ \t\r\n]+/)
        source = parts[1]
        options = liquid_trim(substr(rest, length(source) + 1))
    }
    source_key = var "-" source
    limit = -1
    offset = 0
    reversed = 0
    gsub(/,/, " ", options)
    split(options, parts, /[ \t\r\n]+/)
    for (i = 1; i in parts; i++) {
        if (parts[i] == "reversed") {
            reversed = 1
        } else if (parts[i] ~ /^limit:/) {
            raw = liquid_for_option_raw(parts, i)
            limit = liquid_for_option_number(raw)
            if (liquid_had_error) {
                liquid_for_restore(saved_values, saved_paths)
                return ""
            }
        } else if (parts[i] ~ /^offset:/) {
            if (liquid_for_option_raw(parts, i) == "continue") {
                offset = liquid_for_continue[source_key] + 0
            } else {
                raw = liquid_for_option_raw(parts, i)
                offset = liquid_for_option_number(raw)
                if (liquid_had_error) {
                    liquid_for_restore(saved_values, saved_paths)
                    return ""
                }
            }
        }
    }
    else_pos = liquid_find_for_else(block)
    if (else_pos) {
        body = substr(block, 1, else_pos - 1)
        else_block = substr(block, else_pos + length("{% else %}"))
    } else {
        body = block
        else_block = ""
    }
    source_value = liquid_expression_value(source)
    source_path = liquid_value_path
    source_literal = liquid_value_literal
    if (source_path in liquid_context_ref) {
        source_path = liquid_context_ref[source_path]
    }
    out = ""
    total = liquid_context_type[source_path] == "seq" ? liquid_context_len[source_path] : (liquid_context_type[source_path] == "map" && !source_literal ? liquid_context_child_count[source_path] : (liquid_for_scalar_iterable(source_path, source_value) ? 1 : 0))
    if (offset > total) {
        offset = total
    }
    total -= offset
    if (limit >= 0 && limit < total) {
        total = limit
    }
    if (total <= 0) {
        out = liquid_render_control_body(else_block)
        liquid_for_restore(saved_values, saved_paths)
        return out
    }
    liquid_for_shift_parent()
    start = reversed ? offset + total - 1 : offset
    stop = reversed ? offset : offset + total - 1
    step = reversed ? -1 : 1
    if (liquid_context_type[source_path] == "seq") {
        iter = 0
        for (i = start; reversed ? i >= stop : i <= stop; i += step) {
            child_path = liquid_context_child(source_path, i)
            liquid_local_path[var] = child_path
            liquid_local_value[var] = liquid_context_string(child_path)
            liquid_for_set_meta(iter, total, var, source)
            rendered = liquid_render(body)
            out = out rendered
            if (liquid_flow_control == "break") {
                liquid_flow_control = ""
                break
            }
            if (liquid_flow_control == "continue") {
                liquid_flow_control = ""
            }
            iter++
        }
    } else if (!source_literal && liquid_context_type[source_path] == "map") {
        iter = 0
        for (i = start; reversed ? i >= stop : i <= stop; i += step) {
            key = liquid_context_child_order[source_path, i]
            child_path = liquid_context_child(source_path, key)
            pair_path = "\034pair" (++liquid_pair_id)
            liquid_context_type[pair_path] = "seq"
            liquid_context_len[pair_path] = 2
            liquid_context_child_count[pair_path] = 2
            liquid_split_append(pair_path, 0, key)
            liquid_context_temp_ref(pair_path, 1, child_path)
            liquid_local_path[var] = pair_path
            liquid_local_value[var] = ""
            liquid_for_set_meta(iter, total, var, source)
            rendered = liquid_render(body)
            out = out rendered
            if (liquid_flow_control == "break") {
                liquid_flow_control = ""
                break
            }
            if (liquid_flow_control == "continue") {
                liquid_flow_control = ""
            }
            iter++
        }
    } else if (liquid_for_scalar_iterable(source_path, source_value)) {
        liquid_local_path[var] = ""
        liquid_local_value[var] = source_value
        liquid_for_set_meta(0, 1, var, source)
        out = out liquid_render(body)
        if (liquid_flow_control == "break" || liquid_flow_control == "continue") {
            liquid_flow_control = ""
        }
    }
    liquid_for_continue[source_key] = offset + total
    delete liquid_local_path[var]
    delete liquid_local_value[var]
    liquid_for_restore(saved_values, saved_paths)
    if (out ~ /^[ \t\r\n]*$/ && !liquid_control_body_has_output(body)) {
        return ""
    }
    return out
}

function liquid_find_for_else(text,    rest, offset, tag_pos, close_pos, tag, depth) {
    rest = text
    offset = 0
    depth = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        offset += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        if (depth == 0 && tag ~ /^else([ \t\r\n]|$)/) {
            return offset + 1
        }
        if (tag ~ /^(if|unless|for|case)[ \t\r\n]/) {
            depth++
        } else if ((tag == "endif" || tag == "endunless" || tag == "endfor" || tag == "endcase") && depth > 0) {
            depth--
        }
        offset += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_render_tablerow(text, block,    parts, var, source, source_value, source_path, options, i, total_source, total, offset, limit, cols, raw, saved_values, saved_paths, out, iter, source_index, row, col, child_path, cell) {
    liquid_for_save(saved_values, saved_paths)
    text = liquid_trim(text)
    i = index(text, " in ")
    var = liquid_trim(substr(text, 1, i - 1))
    split(liquid_trim(substr(text, i + 4)), parts, /[ \t\r\n]+/)
    source = parts[1]
    options = liquid_trim(substr(liquid_trim(substr(text, i + 4)), length(source) + 1))
    source_value = liquid_expression_value(source)
    source_path = liquid_value_path
    if (source_path in liquid_context_ref) {
        source_path = liquid_context_ref[source_path]
    }
    total_source = liquid_context_type[source_path] == "seq" ? liquid_context_len[source_path] : 0
    offset = 0
    limit = -1
    cols = 0
    gsub(/,/, " ", options)
    split(options, parts, /[ \t\r\n]+/)
    for (i = 1; i in parts; i++) {
        if (parts[i] ~ /^limit:/) {
            raw = liquid_for_option_raw(parts, i)
            limit = int(liquid_expression_value(raw) + 0)
        } else if (parts[i] ~ /^offset:/) {
            raw = liquid_for_option_raw(parts, i)
            offset = int(liquid_expression_value(raw) + 0)
        } else if (parts[i] ~ /^cols:/) {
            raw = liquid_for_option_raw(parts, i)
            cols = int(liquid_expression_value(raw) + 0)
        }
    }
    if (offset > total_source) {
        offset = total_source
    }
    total = total_source - offset
    if (limit >= 0 && limit < total) {
        total = limit
    }
    if (cols <= 0) {
        cols = total
    }
    out = ""
    for (iter = 0; iter < total; iter++) {
        source_index = offset + iter
        row = int(iter / cols) + 1
        col = (iter % cols) + 1
        if (col == 1) {
            out = out (iter == 0 ? "" : "</tr>\n") "<tr class=\"row" row "\">" (row == 1 ? "\n" : "")
        }
        child_path = liquid_context_child(source_path, source_index)
        liquid_local_path[var] = child_path
        liquid_local_value[var] = liquid_context_string(child_path)
        liquid_tablerow_set_meta(iter, total, row, col, cols)
        cell = liquid_render(block)
        out = out "<td class=\"col" col "\">" cell "</td>"
        if (liquid_flow_control == "break") {
            liquid_flow_control = ""
            break
        }
        if (liquid_flow_control == "continue") {
            liquid_flow_control = ""
        }
    }
    if (out != "") {
        out = out "</tr>\n"
    }
    delete liquid_local_path[var]
    delete liquid_local_value[var]
    liquid_for_restore(saved_values, saved_paths)
    return out
}

function liquid_tablerow_set_meta(index0, loop_len, row, col, cols) {
    liquid_local_value["tablerowloop.index0"] = index0
    liquid_local_value["tablerowloop.index"] = index0 + 1
    liquid_local_value["tablerowloop.length"] = loop_len
    liquid_local_value["tablerowloop.rindex"] = loop_len - index0
    liquid_local_value["tablerowloop.rindex0"] = loop_len - index0 - 1
    liquid_local_value["tablerowloop.first"] = index0 == 0 ? "true" : "false"
    liquid_local_value["tablerowloop.last"] = index0 == loop_len - 1 ? "true" : "false"
    liquid_local_value["tablerowloop.row"] = row
    liquid_local_value["tablerowloop.col"] = col
    liquid_local_value["tablerowloop.col0"] = col - 1
    liquid_local_value["tablerowloop.col_first"] = col == 1 ? "true" : "false"
    liquid_local_value["tablerowloop.col_last"] = (col == cols || index0 == loop_len - 1) ? "true" : "false"
}

function liquid_for_scalar_iterable(source_path, source_value) {
    if (source_value == "") {
        return 0
    }
    if (source_path != "" && liquid_context_tag[source_path] != "tag:yaml.org,2002:str") {
        return 0
    }
    return 1
}

function liquid_for_option_raw(parts, i,    raw) {
    raw = substr(parts[i], index(parts[i], ":") + 1)
    if (raw == "" && ((i + 1) in parts)) {
        raw = parts[i + 1]
    }
    return liquid_trim(raw)
}

function liquid_for_option_number(raw,    value, path) {
    value = liquid_expression_value(raw)
    path = liquid_value_path
    if (path != "" && liquid_context_type[path] != "scalar") {
        return liquid_error()
    }
    if (!liquid_number_is_integer_shape(value)) {
        return liquid_error()
    }
    return int(value + 0)
}

function liquid_for_set_meta(index0, loop_len, var, source) {
    liquid_local_value["forloop.index0"] = index0
    liquid_local_value["forloop.index"] = index0 + 1
    liquid_local_value["forloop.length"] = loop_len
    liquid_local_value["forloop.rindex"] = loop_len - index0
    liquid_local_value["forloop.rindex0"] = loop_len - index0 - 1
    liquid_local_value["forloop.first"] = index0 == 0 ? "true" : "false"
    liquid_local_value["forloop.last"] = index0 == loop_len - 1 ? "true" : "false"
    liquid_local_value["forloop.name"] = var "-" source
}

function liquid_for_shift_parent(    k, shifted_values, shifted_paths) {
    if (liquid_no_parentloop) {
        return
    }
    for (k in liquid_local_value) {
        if (k ~ /^forloop[.]/) {
            shifted_values["forloop.parentloop" substr(k, 8)] = liquid_local_value[k]
        }
    }
    for (k in liquid_local_path) {
        if (k ~ /^forloop[.]/) {
            shifted_paths["forloop.parentloop" substr(k, 8)] = liquid_local_path[k]
        }
    }
    for (k in shifted_values) {
        liquid_local_value[k] = shifted_values[k]
    }
    for (k in shifted_paths) {
        liquid_local_path[k] = shifted_paths[k]
    }
}

function liquid_for_save(values, paths,    k) {
    for (k in liquid_local_value) {
        if (k ~ /^forloop[.]/) {
            values[k] = liquid_local_value[k]
        }
    }
    for (k in liquid_local_path) {
        if (k ~ /^forloop[.]/) {
            paths[k] = liquid_local_path[k]
        }
    }
}

function liquid_for_restore(values, paths,    k) {
    for (k in liquid_local_value) {
        if (k ~ /^forloop[.]/) {
            delete liquid_local_value[k]
        }
    }
    for (k in liquid_local_path) {
        if (k ~ /^forloop[.]/) {
            delete liquid_local_path[k]
        }
    }
    for (k in values) {
        liquid_local_value[k] = values[k]
    }
    for (k in paths) {
        liquid_local_path[k] = paths[k]
    }
}

function liquid_render_case(expr, block,    case_value, case_defined, rest, pos, next_pos, tag, body, tag_end, matched, out, count, i) {
    case_value = liquid_expression_value(expr)
    case_defined = liquid_value_defined || liquid_value_literal
    rest = block
    out = ""
    while ((pos = liquid_find_case_tag(rest)) > 0) {
        rest = substr(rest, pos + 2)
        tag_end = index(rest, "%}")
        if (!tag_end) {
            return liquid_error()
        }
        tag = liquid_trim(substr(rest, 1, tag_end - 1))
        tag = liquid_tag_clean(tag)
        rest = substr(rest, tag_end + 2)
        next_pos = liquid_find_case_tag(rest)
        if (next_pos) {
            body = substr(rest, 1, next_pos - 1)
            rest = substr(rest, next_pos)
        } else {
            body = rest
            rest = ""
        }
        if (tag ~ /^when([ \t\r\n]|$)/) {
            tag = liquid_trim(substr(tag, 5))
            count = liquid_case_match_count(case_value, tag)
            if (count == -1 || (count == -2 && !case_defined)) {
                return liquid_error()
            } else if (count == -2) {
                return ""
            }
            for (i = 0; i < count; i++) {
                out = out body
            }
            if (count > 0) {
                matched = 1
            }
        } else if (tag == "else") {
            if (!matched) {
                out = out body
            }
        }
    }
    return liquid_render_control_body(out, block)
}

function liquid_find_case_tag(text,    rest, offset, tag_pos, close_pos, tag) {
    rest = text
    offset = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        offset += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        if (tag == "else" || tag ~ /^when([ \t\r\n]|$)/) {
            return offset + 1
        }
        offset += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_case_match_count(case_value, tag,    normalized, part, i, count) {
    tag = liquid_trim(tag)
    if (tag == "") {
        return -1
    }
    if (tag ~ /[ \t\r\n]+and[ \t\r\n]+/) {
        return -2
    }
    normalized = tag
    gsub(/[ \t\r\n]+or[ \t\r\n]+/, ",", normalized)
    for (i = 1; ; i++) {
        part = liquid_filter_arg(normalized, i)
        if (part == "") {
            break
        }
        if (case_value == liquid_expression_value(part)) {
            count++
        }
    }
    return count
}

function liquid_render_liquid(text,    lines, count, i, line, template) {
    if (liquid_has_bare_cr(text)) {
        return liquid_error()
    }
    count = split(text, lines, "\n")
    template = ""
    for (i = 1; i <= count; i++) {
        line = liquid_trim(lines[i])
        if (line == "") {
            continue
        }
        if (line == "comment") {
            while (i < count) {
                i++
                line = liquid_trim(lines[i])
                if (line == "endcomment") {
                    break
                }
            }
            continue
        }
        template = template "{% " line " %}"
    }
    return liquid_render(template)
}

function liquid_has_bare_cr(text,    i) {
    for (i = 1; i <= length(text); i++) {
        if (substr(text, i, 1) == "\r" && substr(text, i + 1, 1) != "\n") {
            return 1
        }
    }
    return 0
}
