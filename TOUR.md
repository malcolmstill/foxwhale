# Purpose

This document serves as a primer on the organisation of foxwhale (conceptually and
in terms of this repo).

# Repo

- `src/wl`: this directory contains the implementation of the Wayland wire protocol
   and the code generated from the XML protocol specifications.
   
   The `txrx.zig` file is a small wrapper around the `sendMsg` and `recvMsg` system
   calls (tx meaning transmit, rx meaning receive). Whilst it's straightforward to
   pass in the data buffer, sending and receiving of file descriptors from the
   socket ancilliary data is a bit more involved and takes up a large part of the code.

   `context.zig` (which makes use of `txrx.zig`) defines a Context structure that
   contains buffers for sending / receiving data and file descriptors. It also 
   contains functions for reading / writing the Wayland header and reading / writing
   Wayland protocol types from the buffers. A hashmap is used to store and allocate
   objects as requested.

- `src/`: the code directly under `src/` then is the "bulk" of the implementation of
   compositor-specific code such as in`window.zig`. A lot of the logic is also contained
   in `src/implementations` (see below) but for the sake of organising the repo those
   are kept separately.

   The foxwhale binary is generated from `src/main.zig`.

   Finally, `protocols.zig` is generated code from XML-specified protocols. This generated
   code is what is actually used by the compositor code.

- `src/implementations`: It has files that implement functions that are dispatched on incoming
   Wayland messages (e.g. `wl_surface.zig` and `xdg_surface.zig`)

- `src/backend`: this directory contains implementations of backend specific code.
   Examples of backends are GLFW and Headless.

- `src/shaders`: just a bunch of GLSL files used by the compositor for rendering.

- `src/foxwhalectl/`: implementation of a command-line tool for inspecting and debugging
  the state of the compositor. It implements `fw_control.xml`.

- `procotols/`: contains custom protocols. The only custom protocol that currently exists
   is `fw_control.xml`. This provides a protocol implement both by the compositor and
   `foxwhalectl` that allows inspecting compositor state (for debugging purposes) but
   in the future may also allow for setting state.

- `assets/`: contains any other assets used by the compositor such as cursor images