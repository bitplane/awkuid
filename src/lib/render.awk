function liquid_render(template,    out, rest, out_pos, tag_pos, open_pos, close_pos, expr, tag, end_pos, block, else_pos, true_block, false_block) {
    out = ""
    rest = template
    while (index(rest, "{{") || index(rest, "{%")) {
        out_pos = index(rest, "{{")
        tag_pos = index(rest, "{%")
        if (out_pos && (!tag_pos || out_pos < tag_pos)) {
            open_pos = out_pos
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
            continue
        }
        open_pos = tag_pos
        out = out substr(rest, 1, open_pos - 1)
        rest = substr(rest, open_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            out = out "{%" rest
            rest = ""
            break
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        rest = substr(rest, close_pos + 2)
        if (tag ~ /^assign[ \t\r\n]/) {
            liquid_render_assign(substr(tag, 7))
        } else if (tag ~ /^echo[ \t\r\n]/) {
            out = out liquid_expression_value(substr(tag, 5))
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
        } else if (tag == "comment" || tag == "doc") {
            end_pos = liquid_find_end_tag(rest, tag == "comment" ? "endcomment" : "enddoc")
            if (end_pos) {
                rest = substr(rest, end_pos)
                close_pos = index(rest, "%}")
                rest = substr(rest, close_pos + 2)
            }
        } else if (tag ~ /^if[ \t\r\n]/) {
            end_pos = index(rest, "{% endif %}")
            if (end_pos) {
                block = substr(rest, 1, end_pos - 1)
                rest = substr(rest, end_pos + length("{% endif %}"))
                else_pos = index(block, "{% else %}")
                if (else_pos) {
                    true_block = substr(block, 1, else_pos - 1)
                    false_block = substr(block, else_pos + length("{% else %}"))
                } else {
                    true_block = block
                    false_block = ""
                }
                out = out liquid_render(liquid_condition(substr(tag, 3)) ? true_block : false_block)
            }
        } else if (tag ~ /^unless[ \t\r\n]/) {
            end_pos = index(rest, "{% endunless %}")
            if (end_pos) {
                block = substr(rest, 1, end_pos - 1)
                rest = substr(rest, end_pos + length("{% endunless %}"))
                else_pos = index(block, "{% else %}")
                if (else_pos) {
                    true_block = substr(block, 1, else_pos - 1)
                    false_block = substr(block, else_pos + length("{% else %}"))
                } else {
                    true_block = block
                    false_block = ""
                }
                out = out liquid_render(liquid_condition(substr(tag, 7)) ? false_block : true_block)
            }
        } else if (tag ~ /^case[ \t\r\n]/) {
            end_pos = index(rest, "{% endcase %}")
            if (end_pos) {
                block = substr(rest, 1, end_pos - 1)
                rest = substr(rest, end_pos + length("{% endcase %}"))
                out = out liquid_render_case(substr(tag, 5), block)
            }
        } else if (tag ~ /^for[ \t\r\n]/) {
            end_pos = liquid_find_matching_tag(rest, "for", "endfor")
            if (end_pos) {
                block = substr(rest, 1, end_pos - 1)
                rest = substr(rest, end_pos + length("{% endfor %}"))
                out = out liquid_render_for(substr(tag, 4), block)
            }
        } else if (tag == "ifchanged") {
            end_pos = index(rest, "{% endifchanged %}")
            if (end_pos) {
                block = substr(rest, 1, end_pos - 1)
                rest = substr(rest, end_pos + length("{% endifchanged %}"))
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
            end_pos = index(rest, "{% endcapture %}")
            if (end_pos) {
                block = substr(rest, 1, end_pos - 1)
                rest = substr(rest, end_pos + length("{% endcapture %}"))
                liquid_local_value[liquid_trim(substr(tag, 8))] = liquid_render(block)
                liquid_local_path[liquid_trim(substr(tag, 8))] = ""
            }
        } else if (tag ~ /^#/) {
            continue
        } else if (tag ~ /^liquid([ \t\r\n]|$)/) {
            out = out liquid_render_liquid(substr(tag, 7))
        } else {
            out = out "{%" tag "%}"
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

function liquid_find_end_tag(text, close_name,    rest, base, tag_pos, close_pos, tag) {
    rest = text
    base = 0
    while ((tag_pos = index(rest, "{%")) > 0) {
        base += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_tag_clean(substr(rest, 1, close_pos - 1))
        if (tag == close_name) {
            return base + tag_pos + close_pos + 1
        }
        base += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_render_increment(name,    value) {
    value = liquid_counter_value[name] + 0
    liquid_counter_value[name] = value + 1
    liquid_local_value[name] = liquid_counter_value[name]
    liquid_local_path[name] = ""
    return value
}

function liquid_render_decrement(name,    value) {
    value = liquid_counter_value[name] - 1
    liquid_counter_value[name] = value
    liquid_local_value[name] = value
    liquid_local_path[name] = ""
    return value
}

function liquid_render_cycle(text,    colon, name_expr, name, args, count, idx, key, value) {
    text = liquid_trim(text)
    colon = liquid_find_unquoted(text, ":")
    if (colon) {
        name_expr = liquid_trim(substr(text, 1, colon - 1))
        name = liquid_expression_value(name_expr)
        args = liquid_trim(substr(text, colon + 1))
    } else {
        name = ""
        args = text
    }
    count = liquid_count_filter_args(args)
    key = name SUBSEP count
    idx = liquid_cycle_index[key] + 0
    value = liquid_expression_value(liquid_filter_arg(args, (idx % count) + 1))
    liquid_cycle_index[key] = idx + 1
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

function liquid_render_partial(text, isolated,    name, file, tpl, line, saved_values, saved_paths, result, rest) {
    text = liquid_trim(text)
    name = liquid_partial_name(text)
    if (name == "") {
        return ""
    }
    liquid_partial_save(saved_values, saved_paths)
    liquid_partial_args(text)
    file = liquid_template_dir "/" name ".liquid"
    tpl = ""
    while ((getline line < file) > 0) {
        tpl = tpl (tpl == "" ? "" : "\n") line
    }
    close(file)
    result = liquid_render(tpl)
    if (isolated) {
        liquid_partial_restore(saved_values, saved_paths)
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

function liquid_partial_name(text,    first, value) {
    split(text, first, /[ \t\r\n,]+/)
    value = first[1]
    if (value ~ /^["']/) {
        return liquid_unquote(value)
    }
    return liquid_expression_value(value)
}

function liquid_partial_args(text,    rest, parts, count, i, part, colon, name, expr) {
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
            name = parts[4] == "as" ? parts[5] : liquid_partial_name(text)
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
        liquid_local_value[name] = liquid_expression_value(expr)
        liquid_local_path[name] = liquid_value_path
    }
}

function liquid_partial_clear_args(    k) {
    for (k in liquid_partial_arg_names) {
        delete liquid_local_value[k]
        delete liquid_local_path[k]
        delete liquid_partial_arg_names[k]
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
}

function liquid_find_matching_tag(text, open_name, close_name,    rest, base, tag_pos, close_pos, tag, depth) {
    rest = text
    base = 0
    depth = 1
    while ((tag_pos = index(rest, "{%")) > 0) {
        base += tag_pos - 1
        rest = substr(rest, tag_pos + 2)
        close_pos = index(rest, "%}")
        if (!close_pos) {
            return 0
        }
        tag = liquid_trim(substr(rest, 1, close_pos - 1))
        if (tag == close_name) {
            depth--
            if (depth == 0) {
                return base + 1
            }
        } else if (tag ~ ("^" open_name "[ \t\r\n]")) {
            depth++
        }
        base += close_pos + 3
        rest = substr(rest, close_pos + 2)
    }
    return 0
}

function liquid_render_assign(text,    eq, name, expr) {
    eq = index(text, "=")
    if (!eq) {
        return
    }
    name = liquid_trim(substr(text, 1, eq - 1))
    expr = liquid_trim(substr(text, eq + 1))
    liquid_local_value[name] = liquid_expression_value(expr)
    liquid_local_path[name] = liquid_value_path
}

function liquid_render_for(text, block,    parts, var, source, source_value, source_path, i, key, child_path, pair_path, out, body, else_block, else_pos, total, start, stop, step, iter, rendered, limit, offset, reversed, source_key, k, saved_values, saved_paths) {
    liquid_for_save(saved_values, saved_paths)
    gsub(/,/, " ", text)
    split(liquid_trim(text), parts, /[ \t\r\n]+/)
    var = parts[1]
    source = parts[3]
    source_key = var "-" source
    limit = -1
    offset = 0
    reversed = 0
    for (i = 4; i in parts; i++) {
        if (parts[i] == "reversed") {
            reversed = 1
        } else if (parts[i] ~ /^limit:/) {
            limit = int(liquid_for_option(parts, i) + 0)
        } else if (parts[i] ~ /^offset:/) {
            if (liquid_for_option_raw(parts, i) == "continue") {
                offset = liquid_for_continue[source_key] + 0
            } else {
                offset = int(liquid_for_option(parts, i) + 0)
            }
        }
    }
    else_pos = index(block, "{% else %}")
    if (else_pos) {
        body = substr(block, 1, else_pos - 1)
        else_block = substr(block, else_pos + length("{% else %}"))
    } else {
        body = block
        else_block = ""
    }
    source_value = liquid_expression_value(source)
    source_path = liquid_value_path
    if (source_path in liquid_context_ref) {
        source_path = liquid_context_ref[source_path]
    }
    out = ""
    total = liquid_context_type[source_path] == "seq" ? liquid_context_len[source_path] : (liquid_context_type[source_path] == "map" ? liquid_context_child_count[source_path] : (liquid_for_scalar_iterable(source_path, source_value) ? 1 : 0))
    if (offset > total) {
        offset = total
    }
    total -= offset
    if (limit >= 0 && limit < total) {
        total = limit
    }
    if (total <= 0) {
        out = liquid_render(else_block)
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
    } else if (liquid_context_type[source_path] == "map") {
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
    return out
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

function liquid_for_option(parts, i,    raw) {
    raw = liquid_for_option_raw(parts, i)
    return liquid_expression_value(raw)
}

function liquid_for_option_raw(parts, i,    raw) {
    raw = substr(parts[i], index(parts[i], ":") + 1)
    if (raw == "" && ((i + 1) in parts)) {
        raw = parts[i + 1]
    }
    return liquid_trim(raw)
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

function liquid_render_case(expr, block,    case_value, rest, pos, next_pos, else_pos, tag, body, tag_end, matched, out, when_value) {
    case_value = liquid_expression_value(expr)
    rest = block
    out = ""
    while ((pos = index(rest, "{% when ")) > 0) {
        rest = substr(rest, pos + length("{% when "))
        tag_end = index(rest, "%}")
        if (!tag_end) {
            return ""
        }
        tag = liquid_trim(substr(rest, 1, tag_end - 1))
        rest = substr(rest, tag_end + 2)
        next_pos = index(rest, "{% when ")
        else_pos = index(rest, "{% else %}")
        if (next_pos && (!else_pos || next_pos < else_pos)) {
            body = substr(rest, 1, next_pos - 1)
            rest = substr(rest, next_pos)
        } else if (else_pos) {
            body = substr(rest, 1, else_pos - 1)
            if (!matched) {
                out = substr(rest, else_pos + length("{% else %}"))
            }
            rest = ""
        } else {
            body = rest
            rest = ""
        }
        if (!matched && liquid_case_matches(case_value, tag)) {
            out = body
            matched = 1
        }
    }
    return liquid_render(out)
}

function liquid_case_matches(case_value, tag,    normalized, part, i) {
    normalized = tag
    if (normalized ~ /[ \t\r\n]+and[ \t\r\n]+/) {
        return 0
    }
    gsub(/[ \t\r\n]+or[ \t\r\n]+/, ",", normalized)
    for (i = 1; ; i++) {
        part = liquid_filter_arg(normalized, i)
        if (part == "") {
            break
        }
        if (case_value == liquid_expression_value(part)) {
            return 1
        }
    }
    return 0
}

function liquid_render_liquid(text,    lines, count, i, line, template) {
    count = split(text, lines, "\n")
    template = ""
    for (i = 1; i <= count; i++) {
        line = liquid_trim(lines[i])
        if (line == "") {
            continue
        }
        template = template "{% " line " %}"
    }
    return liquid_render(template)
}
