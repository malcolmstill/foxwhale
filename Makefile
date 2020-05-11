.PHONY: protocols
protocols:
	python generator/generate.py client.zig server /usr/share/wayland/wayland.xml /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml protocols/fw_control.xml > src/protocols.zig
	zig fmt src/protocols.zig

foxwhalectl_protocols:
	python generator/generate.py connection.zig client /usr/share/wayland/wayland.xml protocols/fw_control.xml > src/foxwhalectl/protocols.zig
	zig fmt src/foxwhalectl/protocols.zig