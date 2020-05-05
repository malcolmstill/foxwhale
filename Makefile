protocols:
	python generator/generate.py /usr/share/wayland/wayland.xml /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml > src/wl/protocols.zig
	zig fmt src/wl/protocols.zig