import xml.etree.ElementTree as Tree
import sys

wl_registry_fixed = False

def generate(files):
    print(f'const std = @import("std");')
    print(f'const Context = @import("context.zig").Context;')
    print(f'const Header = @import("context.zig").Header;')
    print(f'const Object = @import("context.zig").Object;\n')

    for file in files:
        tree = Tree.parse(file)
        protocol = tree.getroot()
        if protocol.tag == "protocol":
            generate_protocol(protocol)

def generate_protocol(protocol):
    for child in protocol:
        if child.tag == "interface":
            print(f"\n// {child.attrib['name']}")
            generate_interface(child)
            generate_interface_global_debug(child)
            generate_new_object(child)
            generate_dispatch_function(child)
            generate_enum(child)
            generate_send(child)

# Generate enum
def generate_enum(interface):
    for child in interface:
        if child.tag == "enum":
            print(f"\npub const {interface.attrib['name']}_{child.attrib['name']} = enum(u32) {{")
            for value in child:
                if value.tag == "entry":
                    if value.attrib['name'].isdigit():
                        print(f"\t@\"{value.attrib['name']}\" = {value.attrib['value']},")
                    else:
                        print(f"\t{value.attrib['name']} = {value.attrib['value']},")
            print(f"}};")

# Generate new object
def generate_new_object(interface):
    print(f"pub fn new_{interface.attrib['name']}(context: *Context, id: u32) ?*Object {{")
    print(f"\tvar object = Object {{")
    print(f"\t\t.id = id,")
    print(f"\t\t.dispatch = {interface.attrib['name']}_dispatch,")
    print(f"\t\t.context = context,")
    print(f"\t\t.version = 0,")
    print(f"\t\t.container = 0,")
    print(f"\t}};")
    print(f"\tcontext.register(object) catch |err| {{")
    print(f"\t\tstd.debug.warn(\"Couldn't register id: {{}}\\n\", .{{id}});")
    print(f"\t}};")
    print(f"\tif (context.objects.get(id)) |o| {{ return &o.value; }}")
    print(f"\treturn null;")
    print(f"}}\n")

# Generate Dispatch function
def generate_dispatch_function(interface):
    print(f"fn {interface.attrib['name']}_dispatch(object: Object, opcode: u16) void {{")
    print(f"\tswitch(opcode) {{")
    i = 0
    for child in interface:
        if child.tag == "request":
            fix_wl_registry(interface, child)
            generate_request_dispatch(i, child, interface)
            i = i + 1
    print(f"\t\telse => {{}},")
    print(f"\t}}")
    print(f"}}")

def fix_wl_registry(interface, request):
    global wl_registry_fixed
    if not wl_registry_fixed and interface.attrib['name'] == 'wl_registry' and request.attrib['name'] == 'bind':
        c = Tree.Element("arg")
        c.attrib['name'] = 'name_string'
        c.attrib['type'] = 'string'
        request.insert(2, c)
        c = Tree.Element("arg")
        c.attrib['name'] = 'version'
        c.attrib['type'] = 'uint'
        request.insert(3, c)
        wl_registry_fixed = True

def generate_request_dispatch(index, request, interface):
    print(f"\t\t\t// {request.attrib['name']}")
    print(f"\t\t\t{index} => {{")
    for arg in request:
        if arg.tag == "arg":
            generate_next(arg)
    print(f"\t\t\t\tif ({interface.attrib['name'].upper()}.{request.attrib['name']}) |{request.attrib['name']}| {{", end = '')
    print(f"{request.attrib['name']}(object, ", end = '')
    first = True
    for arg in request:
        if arg.tag == "arg":
            if first:
                print(f"{arg.attrib['name']}", end = '')
                first = False
            else:
                print(f", {arg.attrib['name']}", end = '')
    print(f");")
    print(f"\t\t\t}}")
    print(f"\t\t\t}},")

def generate_next(arg):
    name = arg.attrib["name"]
    atype = lookup_type(arg.attrib["type"], arg)
    if arg.attrib["type"] == "object":
        print(f"\t\t\tvar {name}: Object = object.context.objects.getValue(object.context.next_u32()).?;")
    else:    
        print(f"\t\t\t\tvar {name}: {atype} = object.context.next_{next_type(arg.attrib['type'])}();")

def next_type(type):
    types = {
        "int": "i32",
        "uint": "u32",
        "new_id": "u32",
        "fd": "fd",
        "string": "string",
        "array": "array",
        "object": "OBJECT",
        "fixed": "fixed"
    }
    return types[type]

def put_type_arg(type):
    types = {
        "int": "i32",
        "uint": "u32",
        "new_id": "u32",
        "fd": "i32",
        "string": "[]const u8",
        "array": "[]u32",
        "object": "u32",
        "fixed": "f32"
    }
    return types[type]

def put_type(type):
    types = {
        "int": "I32",
        "uint": "U32",
        "new_id": "U32",
        "fd": "I32",
        "string": "String",
        "array": "Array",
        "object": "U32",
        "fixed": "Fixed"
    }
    return types[type]

# End Generate Object

def generate_description(description):
    desc = description.attrib["summary"]
    print(f"\t// {desc}")

# Generate Interface
def generate_interface(interface):
    print(f"pub const {interface.attrib['name']}_interface = struct {{")
    for child in interface:
        if child.tag == "description":
            generate_description(child)
        if child.tag == "request":
            generate_request(interface, child)
        if child.tag == "event":
            generate_event(child)
    print(f"}};\n")

def generate_request(interface, request):
    fix_wl_registry(interface, request)
    name = request.attrib["name"]
    print(f"\t{name}: ?fn(Object, ", end = '')
    first = True
    for arg in request:
        if arg.tag == "arg":
            generate_request_arg(arg, first)
            if first == True:
                first = False
    print(") void,")

def generate_request_arg(arg, first):
    arg_type = lookup_type(arg.attrib["type"], arg)
    if first:
        print(f"{arg_type}", end = "")
    else:
        print(f", {arg_type}", end = "")

def generate_event(event):
    1

# Generate Interface global
def generate_interface_global_debug(interface):
    for child in interface:
        if child.tag == "request":
            print(f"fn {interface.attrib['name']}_{child.attrib['name']}_default(object: Object", end ='')
            for arg in child:
                if arg.tag == "arg":
                    arg_type = lookup_type(arg.attrib["type"], arg)
                    arg_name = arg.attrib["name"]
                    print(f", {arg_name}: {arg_type}", end = "")
            print(f") void")
            print(f"{{ std.debug.warn(\"{interface.attrib['name']}_{child.attrib['name']} not implemented\\n\", .{{}}); std.os.exit(2);}}\n\n", end='')

    print(f"pub var {interface.attrib['name'].upper()} = {interface.attrib['name']}_interface {{")
    for child in interface:
        if child.tag == "request":
            print(f"\t.{child.attrib['name']} = {interface.attrib['name']}_{child.attrib['name']}_default,")
    print(f"}};\n")

def generate_interface_global(interface):
    print(f"pub var {interface.attrib['name'].upper()} = {interface.attrib['name']}_interface {{")
    for child in interface:
        if child.tag == "request":
            print(f"\t.{child.attrib['name']} = null,")
    print(f"}};\n")

# Generate send
def generate_send(interface):
    i = 0
    for child in interface:
        if child.tag == "event":
            for desc in child:
                if desc.tag == "description":
                    print(f"\n")
                    lines = desc.text.split('\n')
                    for line in lines:
                        line = line.replace('\t', '')
                        print(f"// {line}")
            print(f"pub fn {interface.attrib['name']}_send_{child.attrib['name']}(object: Object", end = '')
            for arg in child:
                if arg.tag == "arg":
                    print(f", {arg.attrib['name']}: {put_type_arg(arg.attrib['type'])}", end = '')
            print(f") void {{")
            print(f"\tobject.context.startWrite();")
            for arg in child:
                if arg.tag == "arg":
                    print(f"\tobject.context.put{put_type(arg.attrib['type'])}({arg.attrib['name']});")
            print(f"\tobject.context.finishWrite(object.id, {i});")
            print(f"}}")
            i = i + 1

def lookup_type(type, arg):
    if type == "object":
        # return "*" + arg.attrib["interface"]
        return "Object"
    else:
        types = {
            "int": "i32",
            "uint": "u32",
            "new_id": "u32",
            "fd": "i32",
            "string": "[]u8",
            "array": "[]u32"
        }
        return types[type]

generate(sys.argv[1:])