Build protocols with:

```
python generator/generate.py /usr/share/wayland/wayland.xml > src/wl/protocols.zig; zig fmt src/wl/protocols.zig
```