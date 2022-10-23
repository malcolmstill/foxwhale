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
    print(f'const Context = @import("wl/context.zig").Context;')

    msgs = []
    for file in files:
        tree = Tree.parse(file)
        protocol = tree.getroot()
        if protocol.tag == "protocol":
            generate_protocol(protocol, sendType, receiveType, msgs)

    # msgs.reverse()
    generate_message_union(msgs)


def generate_protocol(protocol, sendType, receiveType, msgs):
    for child in protocol:
        if child.tag == "interface":
            print(f"\n// {child.attrib['name']}")
            generate_interface_struct(child, receiveType, sendType)
            msgs.append(child.attrib['name'])

def generate_interface_struct(interface, receiveType, sendType):
    interfaceName = camelCase(interface.attrib['name'])
    print(f"pub const {interfaceName} = struct {{")
    print(f"\t\tid: u32,")
    print(f"\t\tcontext: *Context,")
    print(f"\t\tversion: usize,")
    print(f"\t\tcontainer: usize,")
    print(f"")
    print("const Self = @This();")
    print(f"")
    print(f"pub fn init(id: u32, context: *Context, version: u32, container: usize) Self {{")
    print(f"\treturn Self {{")
    print(f"\t\t.id = id,")
    print(f"\t\t.context = context,")
    print(f"\t\t.version = version,")
    print(f"\t\t.container = container,")
    print(f"\t}};")
    print(f"}}")

    print(f"")
    generate_dispatch_function(interface, receiveType)
    generate_send(interface, sendType)


    generate_enum(interface)

    print(f"}};\n")

def generate_message_union(msgs):
    # Enum
    print(f"")
    print(f"pub const WlInterfaceType = enum {{")
    for m in msgs:
        print(f"{m},")
    print(f"}};")
    print(f"")
    # Union
    print(f"pub const WlMessage = union(WlInterfaceType) {{")
    for m in msgs:
        print(f"{m}: {camelCase(m)}.Message,")
    print(f"}};")
    # Object
    print(f"")
    print(f"pub const WlObject = union(WlInterfaceType) {{")
    for m in msgs:
        print(f"{m}: {camelCase(m)},")
    print(f"")
    # 
    print(f"pub fn readMessage(self: *WlObject, opcode: u16) !WlMessage {{")
    print(f"return switch (self.*) {{")
    for m in msgs:
        print(f".{m} => |*o| WlMessage{{ .{m} = try o.readMessage(opcode) }},")
    print(f"}};")
    print(f"}}")
    print(f"// end of dispatch")
    # 
    print(f"pub fn id(self: WlObject) u32 {{")
    print(f"return switch (self) {{")
    for m in msgs:
        print(f".{m} => |o| o.id,")
    print(f"}};")
    print(f"}}")
    print(f"// end of id")

    print(f"}};")

# Generate enum
def generate_enum(interface):
    for child in interface:
        if child.tag == "enum":
            print(f"\npub const {camelCase(child.attrib['name'])} = enum(u32) {{")
            for value in child:
                if value.tag == "entry":
                    if value.attrib['name'].isdigit():
                        print(f"\t@\"{value.attrib['name']}\" = {value.attrib['value']},")
                    else:
                        print(f"\t{value.attrib['name']} = {value.attrib['value']},")
            print(f"}};")

# Generate Dispatch function
def generate_dispatch_function(interface, receiveType):
    interfaceName = f"{camelCase(interface.attrib['name'])}"
    print(f"pub fn readMessage(self: *Self, opcode: u16) anyerror!Message {{")
    print(f"\tswitch(opcode) {{")
    i = 0
    for child in interface:
        if child.tag == receiveType:
            fix_wl_registry(interface, child)
            generate_receive_dispatch(i, child, interface)
            i = i + 1
    print(f"\t\telse => {{std.log.info(\"{{}}\", .{{self}}); return error.UnknownOpcode;}},")
    print(f"\t}}")
    print(f"}}")
    # Generate enum
    print(f"")
    i = 0
    print(f"const MessageType = enum(u8) {{")
    for child in interface:
        if child.tag == receiveType:
            print(f"{child.attrib['name']},")
            i = i + 1
    print(f"}};")
    print(f"")
    # Generate Union
    print(f"")
    messageCount = 0
    for child in interface:
        if child.tag == receiveType:
            messageCount = messageCount + 1
            
    if (messageCount > 0):
        print(f"pub const Message = union(MessageType) {{")
        i = 0
        for child in interface:
            if child.tag == receiveType:
                print(f"{child.attrib['name']}: {camelCase(child.attrib['name'])}Message,")
                i = i + 1
        print(f"}};")
    else: 
        print(f"const Message = struct {{}};")
    print(f"")
    # Generate *Message
    i = 0
    for child in interface:
        if child.tag == receiveType:
            generate_msg(i, child, interface)
            i = i + 1

def generate_msg(i, receive, interface):
    enumName = f"{interface.attrib['name']}_{receive.attrib['name']}"
    messageName = f"{camelCase(receive.attrib['name'])}Message"
    print(f"")
    print(f"const {messageName} = struct {{")
    # print(f"// TODO: should we include the interface's Object?")
    print(f"{interface.attrib['name']}: {camelCase(interface.attrib['name'])},")
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

    messageName = f"{camelCase(receive.attrib['name'])}Message"
    print(f"return Message{{ .{receive.attrib['name']} = {messageName}{{")
    print(f".{interface.attrib['name']} = self.*,")
    for arg in receive:
        if arg.tag == "arg":
            arg_name = arg.attrib["name"]
            print(f".{arg_name} = {arg_name},")
    print(f"}}, }};")
    print(f"\t\t\t}},")

def generate_next(arg):
    name = arg.attrib["name"]
    atype = lookup_type(arg.attrib["type"], arg)
    if arg.attrib["type"] == "object":
        if "allow-null" in arg.attrib and arg.attrib["allow-null"] == "true":
            if "interface" in arg.attrib:
                object_interface = arg.attrib["interface"]
                object_type = camelCase(arg.attrib["interface"])
                print(f"\t\t\tconst {name}: ?{object_type} = if (self.context.objects.get(try self.context.nextU32())) |obj|  switch (obj) {{ .{object_interface} => |o| o, else => return error.MismtachObjectTypes, }} else null;")
            else:
                print(f"\t\t\tconst {name}: ?WlObject = try self.context.objects.get(try self.context.next_u32());")
        else:
            if "interface" in arg.attrib:
                object_interface = arg.attrib["interface"]
                object_type = camelCase(arg.attrib["interface"])
                print(f"\t\t\tconst {name}: {object_type} = if (self.context.objects.get(try self.context.nextU32())) |obj|  switch (obj) {{ .{object_interface} => |o| o, else => return error.MismtachObjectTypes, }} else return error.ExpectedObject;")
            else:
                print(f"\t\t\tconst {name}: WlObject = try self.context.objects.get(try self.context.next_u32());")
    else:    
        print(f"\t\t\t\tconst {name}: {atype} = try self.context.next{next_type(arg.attrib['type'])}();")

def next_type(type):
    types = {
        "int": "I32",
        "uint": "U32",
        "new_id": "U32",
        "fd": "Fd",
        "string": "String",
        "array": "Array",
        "object": "OBJECT",
        "fixed": "Fixed"
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
            print(f"")
            fix_wl_registry(interface, child)
            for desc in child:
                if desc.tag == "description":
                    print(f"\n")
                    if desc.text != None:
                        lines = desc.text.split('\n')
                        for line in lines:
                            line = line.replace('\t', '')
                            print(f"// {line}")
            print(f"pub fn send{camelCase(child.attrib['name'])}(self: Self", end = '')
            for arg in child:
                if arg.tag == "arg":
                    if "enum" in arg.attrib:
                        # We have an enum...use enum instead
                        print(f", {arg.attrib['name']}: {camelCase(arg.attrib['enum'])}", end = '')
                    else:
                        print(f", {arg.attrib['name']}: {put_type_arg(arg.attrib['type'])}", end = '')
            print(f") anyerror!void {{")
            print(f"\tself.context.startWrite();")
            for arg in child:
                if arg.tag == "arg":
                    if "enum" in arg.attrib:
                        print(f"\tself.context.put{put_type(arg.attrib['type'])}(@enumToInt({arg.attrib['name']}));")
                    else:
                        print(f"\tself.context.put{put_type(arg.attrib['type'])}({arg.attrib['name']});")
            print(f"\ttry self.context.finishWrite(self.id, {i});")
            print(f"}}")
            i = i + 1

def lookup_type(type, arg):
    if type == "object":
        if "allow-null" in arg.attrib and arg.attrib["allow-null"]:
            if "interface" in arg.attrib:
                object_type = camelCase(arg.attrib["interface"])
                return f"?{object_type}"
            else:
                return "?Object"
        # return "*" + arg.attrib["interface"]
        else:
            if "interface" in arg.attrib:
                object_type = camelCase(arg.attrib["interface"])
                return object_type
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