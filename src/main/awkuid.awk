BEGIN {
    liquid_template = ""
    liquid_had_error = 0
    liquid_template_file = ARGV[1]
    if (liquid_template_file == "") {
        print "awkuid: missing template file" > "/dev/stderr"
        exit 2
    }
    while ((getline liquid_template_line < liquid_template_file) > 0) {
        liquid_template = liquid_template (liquid_template == "" ? "" : "\n") liquid_template_line
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
    if (liquid_had_error) {
        exit 1
    }
    printf "%s", liquid_rendered
}
