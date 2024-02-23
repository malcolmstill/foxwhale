.PHONY: protocols
protocols:
	python3 generator/generate.py client.zig server /usr/share/wayland/wayland.xml /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml /usr/share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml protocols/fw_control.xml > src/wl/protocols.zig
	zig fmt src/wl/protocols.zig

foxwhalectl_protocols:
	python3 generator/generate.py connection.zig client /usr/share/wayland/wayland.xml protocols/fw_control.xml > src/foxwhalectl/protocols.zig
	zig fmt src/foxwhalectl/protocols.zig

build:
	zig build install --prefix ./

build-small:
	zig build install -Drelease-small --prefix ./

build-really-small:
	zig build install -Drelease-small --prefix ./
	strip bin/foxwhale
	upx bin/foxwhale
	strip bin/foxwhalectl
	upx bin/foxwhalectl