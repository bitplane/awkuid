BEGIN {
    liquid_template = ""
    liquid_had_error = 0
    liquid_numeric_assign["\034"] = ""
    delete liquid_numeric_assign["\034"]
    liquid_numeric_assign_used["\034"] = ""
    delete liquid_numeric_assign_used["\034"]
    liquid_template_file = ARGV[1]
    if (liquid_template_file == "") {
        print "awkuid: missing template file" > "/dev/stderr"
        exit 2
    }
    liquid_template_first_line = 1
    while ((getline liquid_template_line < liquid_template_file) > 0) {
        liquid_template = liquid_template (liquid_template_first_line ? "" : "\n") liquid_template_line
        liquid_template_first_line = 0
    }
    close(liquid_template_file)
    if (liquid_template_dir == "") {
        liquid_template_dir = liquid_template_file
        sub(/\/[^\/]*$/, "", liquid_template_dir)
    }
    ARGV[1] = ""
}

{
    liquid_context_load($0)
}

END {
    liquid_rendered = liquid_render(liquid_template)
    for (liquid_numeric_assign_name in liquid_numeric_assign) {
        if (!liquid_numeric_assign_used[liquid_numeric_assign_name]) {
            liquid_had_error = 1
        }
    }
    if (liquid_had_error) {
        exit 1
    }
    printf "%s", liquid_rendered
}
