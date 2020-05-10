# Purpose

This document serves as a primer on the organisation of foxwhale (conceptually and
in terms of this repo).

# Repo

- `src/backend`: this directory contains implementations of backend specific code.
   Examples of backends are GLFW and Headless.
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

   Finally, `protocols.zig` is generated code from XML-specified protocols. This generated
   code is what is actually used by the compositor code.
- `src/shaders`: just a bunch of GLSL files used by the compositor for rendering.
- `src/`: the code directly under `src/` then is the "bulk" of the implementation of the
  compositor. It has files that implement the Wayland messages (e.g. `wl_surface.zig` and
  `xdg_surface.zig`) and then files which are more specific to the compositor such as
  `window.zig`. There's an argument to be made for the Wayland implementation functions to
  be in, say, `src/implementations` but this is not currently the case.
- `generator/`: this director contains code for generating `protocols.zig` from Wayland XML
  files. Ostensibly this is also written in zig, but it is actually hacked together in python.
   