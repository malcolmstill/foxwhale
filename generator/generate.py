import xml.etree.ElementTree as Tree
import sys

wl_registry_fixed = False

def power_of_two(n):
    return (n != 0) and (n & (n-1) == 0)

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
    print(f'const builtin = @import("builtin");')
    print(f'const WireFn = @import("wire.zig").Wire;')

    interfacesMap = {}
    for file in files:
        tree = Tree.parse(file)
        protocol = tree.getroot()
        if protocol.tag == "protocol":
            generate_interface_map(protocol, interfacesMap)

    print(f'')
    print(f'pub fn Wayland(comptime ResourceMap: struct {{')
    for key in interfacesMap:
        print(f'{key}: type = ?void,')
    print(f'}}) type {{')
    print(f" return struct {{")
    print(f'pub const Wire = WireFn(WlMessage);')

    msgs = []
    for file in files:
        tree = Tree.parse(file)
        protocol = tree.getroot()
        if protocol.tag == "protocol":
            generate_protocol(protocol, sendType, receiveType, msgs, interfacesMap)

    # msgs.reverse()
    generate_message_union(msgs)

    print(f'}};')
    print(f'}}')


def generate_interface_map(protocol, interfacesMap):
    for interface in protocol:
        if interface.tag == "interface":
            interfacesMap[interface.attrib["name"]] = camelCase(interface.attrib["name"])


def generate_protocol(protocol, sendType, receiveType, msgs, interfacesMap):
    global_enum_map = {}
    for child in protocol:
        if child.tag == "interface":
            make_enum_map(child, global_enum_map)

    for child in protocol:
        if child.tag == "interface":
            print(f"\n// {child.attrib['name']}")
            generate_interface_struct(child, receiveType, sendType, global_enum_map)
            msgs.append(child.attrib['name'])


def make_enum_map(interface, global_enum_map):
    for child in interface:
        if child.tag == "enum":
            enum_name = child.attrib['name']
            if "bitfield" in child.attrib:
                global_enum_map[interface.attrib["name"] + "." + enum_name] = "bitfield"
            else:
                global_enum_map[interface.attrib["name"] + "." + enum_name] = "enum"

def generate_interface_struct(interface, receiveType, sendType, global_enum_map):
    interfaceName = camelCase(interface.attrib['name'])
    resourceType = f'ResourceMap.{interface.attrib["name"]}'
    print(f"pub const {interfaceName} = struct {{")
    print(f"\t\twire: *Wire,")
    print(f"\t\tid: u32,")
    print(f"\t\tversion: u32,")
    print(f'resource: {resourceType},')
    print(f"")
    print("const Self = @This();")
    print(f"")
    print(f"pub fn init(id: u32, wire: *Wire, version: u32, resource: {resourceType}) Self {{")
    print(f"\treturn Self {{")
    print(f"\t\t.id = id,")
    print(f"\t\t.wire = wire,")
    print(f"\t\t.version = version,")
    print(f"\t\t.resource = resource,")
    print(f"\t}};")
    print(f"}}")

    print(f"")
    local_enum_map = generate_enum(interface)
    for key in local_enum_map:
        global_enum_map[interface.attrib['name'] + "." + key] = local_enum_map[key]
    print(f"")
    generate_dispatch_function(interface, receiveType, local_enum_map, global_enum_map)
    # print(f"// {local_enum_map}")
    generate_send(interface, sendType, local_enum_map, global_enum_map)

    print(f"}};\n")

def generate_message_union(msgs):
    # Enum
    print(f"")
    print(f"pub const WlInterfaceType = enum(u8) {{")
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
    print(f"pub fn readMessage(self: *WlObject, objects: anytype, comptime field: []const u8, opcode: u16) !WlMessage {{")
    print(f"return switch (self.*) {{")
    for m in msgs:
        print(f".{m} => |*o| WlMessage{{ .{m} = try o.readMessage(objects, field, opcode) }},")
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
    local_map = {}
    for child in interface:
        if child.tag == "enum":
            enum_name = child.attrib['name']
            if "bitfield" in child.attrib:
                local_map[enum_name] = 'bitfield'
                print(f"\npub const {camelCase(enum_name)} = packed struct(u32) {{ // bitfield ")
                i = 0
                for value in child:
                    if value.tag == "entry":
                        field_value = int(value.attrib['value'], 0)
                        if  power_of_two(field_value):
                            i += 1
                            print(f"\t{value.attrib['name']}: bool = false, // {field_value}")
                        else:
                            print(f"// {value.attrib['name']} {field_value} (removed from bitfield) ")

                print(f"_padding: u{32-i} = 0,")
                print(f"}};")
            else:
                local_map[enum_name] = 'enum'
                print(f"\npub const {camelCase(enum_name)} = enum(u32) {{")
                for value in child:
                    if value.tag == "entry":
                        if value.attrib['name'].isdigit():
                            print(f"\t@\"{value.attrib['name']}\" = {value.attrib['value']},")
                        else:
                            print(f"\t{value.attrib['name']} = {value.attrib['value']},")
                print(f"}};")
    return local_map

# Generate Dispatch function
def generate_dispatch_function(interface, receiveType, local_enum_map, global_enum_map):
    interfaceName = f"{camelCase(interface.attrib['name'])}"
    print(f"pub fn readMessage(self: *Self, objects: anytype, comptime field: []const u8, opcode: u16) anyerror!Message {{")
    print(f"if (builtin.mode == .Debug and builtin.mode == .ReleaseFast) std.log.info(\"{{any}}, {{s}}\", .{{&objects, &field}});")
    print(f"\tswitch(opcode) {{")
    i = 0
    for child in interface:
        if child.tag == receiveType:
            fix_wl_registry(interface, child)
            generate_receive_dispatch(i, child, interface, local_enum_map, global_enum_map)
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

def generate_receive_dispatch(index, receive, interface, local_enum_map, global_enum_map):
    name = escapename(receive.attrib['name'])
    print(f"// {receive.attrib['name']}")
    print(f"{index} => {{")
    for arg in receive:
        if arg.tag == "arg":
            generate_next(arg, local_enum_map, global_enum_map)

    messageName = f"{camelCase(receive.attrib['name'])}Message"
    print(f"return Message{{ .{receive.attrib['name']} = {messageName}{{")
    print(f".{interface.attrib['name']} = self.*,")
    for arg in receive:
        if arg.tag == "arg":
            arg_name = arg.attrib["name"]
            print(f".{arg_name} = {arg_name},")
    print(f"}}, }};")
    print(f"\t\t\t}},")

def generate_next(arg, local_enum_map, global_enum_map):
    name = arg.attrib["name"]
    atype = lookup_type(arg.attrib["type"], arg)
    if arg.attrib["type"] == "object":
        if "allow-null" in arg.attrib and arg.attrib["allow-null"] == "true":
            if "interface" in arg.attrib:
                object_interface = arg.attrib["interface"]
                object_type = camelCase(arg.attrib["interface"])
                print(f"\t\t\tconst {name}: ?{object_type} = if (@field(objects, field)(try self.wire.nextU32())) |obj|  switch (obj) {{ .{object_interface} => |o| o, else => return error.MismtachObjectTypes, }} else null;")
            else:
                print(f"\t\t\tconst {name}: ?WlObject = try @field(objects, field)(try self.wire.next_u32());")
        else:
            if "interface" in arg.attrib:
                object_interface = arg.attrib["interface"]
                object_type = camelCase(arg.attrib["interface"])
                print(f"\t\t\tconst {name}: {object_type} = if (@field(objects, field)(try self.wire.nextU32())) |obj|  switch (obj) {{ .{object_interface} => |o| o, else => return error.MismtachObjectTypes, }} else return error.ExpectedObject;")
            else:
                print(f"\t\t\tconst {name}: WlObject = try @field(objects, field)(try self.wire.next_u32());")
    else:
        if "enum" in arg.attrib:
            enum_name = arg.attrib["enum"]
            enum_type = local_enum_map.get(enum_name, global_enum_map.get(enum_name, None))
            if enum_type == "bitfield":
                print(f"\t\t\t\tconst {name}: {atype} = @bitCast({camelCase(arg.attrib['enum'])}, try self.wire.next{next_type(arg.attrib['type'])}()); // {enum_type}")
            else:
                print(f"\t\t\t\tconst {name}: {atype} = @intToEnum({camelCase(arg.attrib['enum'])}, try self.wire.next{next_type(arg.attrib['type'])}()); // {enum_type}")
        else:   
            print(f"\t\t\t\tconst {name}: {atype} = try self.wire.next{next_type(arg.attrib['type'])}();")

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
        "array": "[]u8",
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
def generate_send(interface, sentType, local_enum_map, global_enum_map):
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
            print(f"\ttry self.wire.startWrite();")
            for arg in child:
                if arg.tag == "arg":
                    if "enum" in arg.attrib:
                        enum_name = arg.attrib['enum']
                        # print(f"// {enum_name} {local_enum_map}, {global_enum_map}")
                        enum_type = local_enum_map.get(enum_name, global_enum_map.get(enum_name, None))
                        if enum_type ==  "bitfield":
                            print(f"\ttry self.wire.putU32(@bitCast(u32, {arg.attrib['name']})); // {enum_type}")
                        else:
                            print(f"\ttry self.wire.putU32(@enumToInt({arg.attrib['name']})); // {enum_type}")
                    else:
                        print(f"\ttry self.wire.put{put_type(arg.attrib['type'])}({arg.attrib['name']});")
            print(f"\ttry self.wire.finishWrite(self.id, {i});")
            print(f"}}")
            i = i + 1

def lookup_type(type, arg):
    if "enum" in arg.attrib:
        return camelCase(arg.attrib['enum'])
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
            "array": "[]u8",
            "fixed": "f32"
        }
        return types[type]

def camelCase(string):
    words = string.split('_')
    return ''.join([*map(str.title, words)])

generate(sys.argv[1], sys.argv[2], sys.argv[3:])
