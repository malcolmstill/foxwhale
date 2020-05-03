import xml.etree.ElementTree as Tree
import sys

def generate(file):
    tree = Tree.parse(file)
    root = tree.getroot()
    print(f'const Context = @import("context.zig").Context;')
    print(f'const Object = @import("object.zig").Object;\n')
    if root.tag == "protocol":
        generate_protocol(root)

def generate_protocol(protocol):
    for child in protocol:
        if child.tag == "interface":
            generate_new_object(child)
            generate_object(child)
            generate_interface(child)
    print(f"const TypeTag = enum {{")
    for child in protocol:
        if child.tag == "interface":
            interface = child.attrib["name"]
            print(f"\t{interface}_tag,")
    print(f"}};")
    print(f"const WlResource = union(TypeTag) {{")
    for child in protocol:
        if child.tag == "interface":
            interface = child.attrib["name"]
            print(f"\t{interface}_tag: {interface},")
    print(f"}};")

# Generate new object
def generate_new_object(interface):
    print(f"pub fn new_{interface.attrib['name']}() {interface.attrib['name']} {{")
    print(f"\treturn Object {{")
    print(f"\t\t.dispatch = {interface.attrib['name']}_dispatch,")
    print(f"\t}};")
    print(f"}}")

# Generate Object
def generate_object(interface):
    print(f"pub const {interface.attrib['name']} = struct {{")
    print(f"\tcontext: *Context,")
    print(f"\tconst Self = @This();")
    print("")
    print(f"\tpub fn dispatch(self: *Self, opcode: u16) void {{")
    print(f"\t\tswitch(opcode) {{")
    i = 0
    for child in interface:
        if child.tag == "request":
            generate_request_dispatch(i, child)
            i = i + 1
    print(f"\t\t}}")
    print(f"\t}}")
    print(f"}};\n")

def generate_request_dispatch(index, request):
    print(f"\t\t\t{index} => {{")
    for arg in request:
        if arg.tag == "arg":
            generate_next(arg)
    print(f"\t\t\t}},")

def generate_next(arg):
    name = arg.attrib["name"]
    atype = lookup_type(arg.attrib["type"], arg)
    print(f"\t\t\t\tvar {name}: {atype} = self.context.Next{arg.attrib['type']}();")

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
    print(f"\t{name}: fn(", end = '')
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

def lookup_type(type, arg):
    types = {
        "int": "i32",
        "uint": "u32",
        "new_id": "i32",
        "fd": "i32",
        "string": "[]u8"
    }
    if type == "object":
        return "*" + arg.attrib["interface"]
    else:
        types = {
            "int": "i32",
            "uint": "u32",
            "new_id": "i32",
            "fd": "i32",
            "string": "[]u8",
            "array": "[]u32"
        }
        return types[type]

generate(sys.argv[1])