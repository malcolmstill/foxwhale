

pub const MessageHeader = packed struct {
    id: u32,
    opcode: u16,
    length: u16,
};

