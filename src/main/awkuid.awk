BEGIN {
    liquid_template = ""
    liquid_template_file = ARGV[1]
    if (liquid_template_file == "") {
        print "awkuid: missing template file" > "/dev/stderr"
        exit 2
    }
    while ((getline liquid_template_line < liquid_template_file) > 0) {
        liquid_template = liquid_template (liquid_template == "" ? "" : "\n") liquid_template_line
    }
    close(liquid_template_file)
    ARGV[1] = ""
}

{
    liquid_context_load($0)
}

END {
    printf "%s", liquid_render(liquid_template)
}
