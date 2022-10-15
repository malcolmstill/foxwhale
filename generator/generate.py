import xml.etree.ElementTree as Tree
import sys

wl_registry_fixed = False

def generate(context, side, files):
    receiveType = None
    sendType = None

    if side == "server":
        receiveType = "request"
        sendType = "event"

    if side == "client":
        receiveType = "event"
        sendType = "request"

    print(f'const std = @import("std");')
    print(f'const Context = @import("{context}").Context;')
    print(f'const Object = @import("{context}").Object;\n')

    for file in files:
        tree = Tree.parse(file)
        protocol = tree.getroot()
        if protocol.tag == "protocol":
            generate_protocol(protocol, sendType, receiveType)

def generate_protocol(protocol, sendType, receiveType):
    for child in protocol:
        if child.tag == "interface":
            print(f"\n// {child.attrib['name']}")
            generate_new_object(child)
            generate_dispatch_function(child, receiveType)
            generate_enum(child)
            generate_send(child, sendType)

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
    print(f"pub fn new_{interface.attrib['name']}(id: u32, context: *Context, container: usize) Object {{")
    print(f"\treturn Object {{")
    print(f"\t\t.id = id,")
    print(f"\t\t.dispatch = {interface.attrib['name']}_dispatch,")
    print(f"\t\t.context = context,")
    print(f"\t\t.version = 0,")
    print(f"\t\t.container = container,")
    print(f"\t}};")
    print(f"}}\n")

# Generate Dispatch function
def generate_dispatch_function(interface, receiveType):
    print(f"fn {interface.attrib['name']}_dispatch(object: Object, opcode: u16) anyerror!WaylandMsg {{")
    print(f"\tswitch(opcode) {{")
    i = 0
    for child in interface:
        if child.tag == receiveType:
            fix_wl_registry(interface, child)
            generate_receive_dispatch(i, child, interface)
            i = i + 1
    print(f"\t\telse => {{return error.UnknownOpcode;}},")
    print(f"\t}}")
    print(f"}}")
    # Generate *Msg
    i = 0
    for child in interface:
        if child.tag == receiveType:
            generate_msg(i, child, interface)
            i = i + 1

def generate_msg(i, receive, interface):
    print(f"const {camelCase(interface.attrib['name'])}{camelCase(receive.attrib['name'])}Msg = struct {{")
    print(f"// TODO: should we include the interface's Object?")
    for arg in receive:
        if arg.tag == "arg":
            generate_msg_field(arg)
    print(f"}};")

def generate_msg_field(arg):
    name = arg.attrib["name"]
    atype = lookup_type(arg.attrib["type"], arg)
    print(f"\t\t\t\t{name}: {atype},")

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

def generate_receive_dispatch(index, receive, interface):
    name = escapename(receive.attrib['name'])
    print(f"// {receive.attrib['name']}")
    print(f"{index} => {{")
    for arg in receive:
        if arg.tag == "arg":
            generate_next(arg)

    print(f"return {camelCase(interface.attrib['name'])}{camelCase(receive.attrib['name'])}Msg {{")
    for arg in receive:
        if arg.tag == "arg":
            arg_name = arg.attrib["name"]
            print(f".{arg_name} = {arg_name},")
    print(f"}};")
    print(f"\t\t\t}},")

def generate_next(arg):
    name = arg.attrib["name"]
    atype = lookup_type(arg.attrib["type"], arg)
    if arg.attrib["type"] == "object":
        if "allow-null" in arg.attrib and arg.attrib["allow-null"] == "true":
            print(f"\t\t\tvar {name}: ?Object = object.context.objects.get(try object.context.next_u32());")
            if "interface" in arg.attrib:
                object_interface = arg.attrib["interface"]
                print(f"\t\t\tif ({name} != null) {{if ({name}.?.dispatch != {object_interface}_dispatch) {{ return error.ObjectWrongType; }} }}")
        else:
            print(f"\t\t\tvar {name}: Object = object.context.objects.get(try object.context.next_u32()).?;")
            if "interface" in arg.attrib:
                object_interface = arg.attrib["interface"]
                print(f"\t\t\tif ({name}.dispatch != {object_interface}_dispatch) {{ return error.ObjectWrongType; }}")
    else:    
        print(f"\t\t\t\tvar {name}: {atype} = try object.context.next_{next_type(arg.attrib['type'])}();")

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
        "fd": "Fd",
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
# def generate_interface(interface, sendType, receiveType):
#     print(f"pub const {interface.attrib['name']}_interface = struct {{")
#     for child in interface:
#         if child.tag == "description":
#             generate_description(child)
#         if child.tag == receiveType:
#             generate_receive(interface, child)
#         # if child.tag == sendType:
#         #     generate_event(child)
#     print(f"}};\n")

def generate_receive(interface, receive):
    fix_wl_registry(interface, receive)
    name = escapename(receive.attrib["name"])
    print(f"\t{name}: ?fn(*Context, Object, ", end = '')
    first = True
    for arg in receive:
        if arg.tag == "arg":
            generate_receive_arg(arg, first)
            if first == True:
                first = False
    print(") anyerror!void,")

def escapename(name):
    if name == "error":
        return "@\"error\""
    else:
        return name

def generate_receive_arg(arg, first):
    arg_type = lookup_type(arg.attrib["type"], arg)
    if first:
        print(f"{arg_type}", end = "")
    else:
        print(f", {arg_type}", end = "")


# Generate send
def generate_send(interface, sentType):
    i = 0
    for child in interface:
        if child.tag == sentType:
            fix_wl_registry(interface, child)
            for desc in child:
                if desc.tag == "description":
                    print(f"\n")
                    if desc.text != None:
                        lines = desc.text.split('\n')
                        for line in lines:
                            line = line.replace('\t', '')
                            print(f"// {line}")
            print(f"pub fn {interface.attrib['name']}_send_{child.attrib['name']}(object: Object", end = '')
            for arg in child:
                if arg.tag == "arg":
                    print(f", {arg.attrib['name']}: {put_type_arg(arg.attrib['type'])}", end = '')
            print(f") anyerror!void {{")
            print(f"\tobject.context.startWrite();")
            for arg in child:
                if arg.tag == "arg":
                    print(f"\tobject.context.put{put_type(arg.attrib['type'])}({arg.attrib['name']});")
            print(f"\ttry object.context.finishWrite(object.id, {i});")
            print(f"}}")
            i = i + 1

def lookup_type(type, arg):
    if type == "object":
        if "allow-null" in arg.attrib and arg.attrib["allow-null"]:
            return "?Object"
        # return "*" + arg.attrib["interface"]
        else:
            return "Object"
    else:
        types = {
            "int": "i32",
            "uint": "u32",
            "new_id": "u32",
            "fd": "i32",
            "string": "[]u8",
            "array": "[]u32",
            "fixed": "f32"
        }
        return types[type]

def camelCase(string):
    words = string.split('_')
    return ''.join([*map(str.title, words)])

generate(sys.argv[1], sys.argv[2], sys.argv[3:])