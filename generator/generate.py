import xml.etree.ElementTree as Tree
import sys

def generate(file):
    tree = Tree.parse(file)
    root = tree.getroot()
    print(f'const std = @import("std");')
    print(f'const Context = @import("context.zig").Context;')
    print(f'const Header = @import("context.zig").Header;')
    print(f'const Object = @import("context.zig").Object;\n')
    if root.tag == "protocol":
        generate_protocol(root)

def generate_protocol(protocol):
    for child in protocol:
        if child.tag == "interface":
            print(f"\n// {child.attrib['name']}")
            generate_interface(child)
            generate_interface_global(child)
            generate_new_object(child)
            generate_dispatch_function(child)
            generate_enum(child)
            generate_send(child)
    # print(f"const TypeTag = enum {{")
    # for child in protocol:
    #     if child.tag == "interface":
    #         interface = child.attrib["name"]
    #         print(f"\t{interface}_tag,")
    # print(f"}};")
    # print(f"const WlResource = union(TypeTag) {{")
    # for child in protocol:
    #     if child.tag == "interface":
    #         interface = child.attrib["name"]
    #         print(f"\t{interface}_tag: {interface},")
    # print(f"}};")

# Generate enum
def generate_enum(interface):
    for child in interface:
        if child.tag == "enum":
            print(f"\nconst {interface.attrib['name']}_{child.attrib['name']} = enum {{")
            for value in child:
                if value.tag == "entry":
                    if value.attrib['name'].isdigit():
                        print(f"\t@\"{value.attrib['name']}\" = {value.attrib['value']},")
                    else:
                        print(f"\t{value.attrib['name']} = {value.attrib['value']},")
            print(f"}};")

# Generate new object
def generate_new_object(interface):
    print(f"pub fn new_{interface.attrib['name']}(context: *Context, id: u32) Object {{")
    print(f"\tvar object =  Object {{")
    print(f"\t\t.id = id,")
    print(f"\t\t.dispatch = {interface.attrib['name']}_dispatch,")
    print(f"\t\t.context = context,")
    print(f"\t}};")
    print(f"\tcontext.register(object) catch |err| {{")
    print(f"\t\tstd.debug.warn(\"Couldn't register id: {{}}\\n\", .{{id}});")
    print(f"\t}};")
    print(f"\treturn object;")
    print(f"}}\n")

# Generate Dispatch function
def generate_dispatch_function(interface):
    print(f"fn {interface.attrib['name']}_dispatch(context: *Context, opcode: u16) void {{")
    print(f"\tswitch(opcode) {{")
    i = 0
    for child in interface:
        if child.tag == "request":
            generate_request_dispatch(i, child, interface)
            i = i + 1
    print(f"\t\telse => {{}},")
    print(f"\t}}")
    print(f"}}")

def generate_request_dispatch(index, request, interface):
    print(f"\t\t\t// {request.attrib['name']}")
    print(f"\t\t\t{index} => {{")
    for arg in request:
        if arg.tag == "arg":
            generate_next(arg)
    print(f"\t\t\t\tif ({interface.attrib['name'].upper()}.{request.attrib['name']}) |{request.attrib['name']}| {{", end = '')
    print(f"{request.attrib['name']}(", end = '')
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
        print(f"\t\t\tvar {name}: Object = new_{arg.attrib['interface']}(context, context.next_u32());")
    else:    
        print(f"\t\t\t\tvar {name}: {atype} = context.next_{next_type(arg.attrib['type'])}();")

def next_type(type):
    types = {
        "int": "i32",
        "uint": "u32",
        "new_id": "u32",
        "fd": "i32",
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
        "string": "[]u8",
        "array": "[]u32",
        "object": "u32",
        "fixed": "f32"
    }
    return types[type]

def put_type(type):
    types = {
        "int": "i32",
        "uint": "u32",
        "new_id": "u32",
        "fd": "i32",
        "string": "string",
        "array": "array",
        "object": "u32",
        "fixed": "fixed"
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
            generate_request(child)
        if child.tag == "event":
            generate_event(child)
    print(f"}};\n")

def generate_request(request):
    name = request.attrib["name"]
    print(f"\t{name}: ?fn(", end = '')
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
def generate_interface_global(interface):
    print(f"pub var {interface.attrib['name'].upper()} = {interface.attrib['name']}_interface {{")
    for child in interface:
        if child.tag == "request":
            print(f"\t.{child.attrib['name']} = null,")
    print(f"}};\n")

# Generate send
def generate_send(interface):
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
            print(f"\tvar offset = object.context.tx_write_offset;")
            print(f"\tobject.context.tx_write_offset += @sizeOf(Header);")
            for arg in child:
                if arg.tag == "arg":
                    print(f"\tobject.context.put_{put_type(arg.attrib['type'])}({arg.attrib['name']});")
            print(f"}}")

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

generate(sys.argv[1])