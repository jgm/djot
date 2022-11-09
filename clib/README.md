# libdjot

Some experiments in creating a C library that embeds the djot lua code.

`make` builds a static library `libdjot.a` and an executable
`tests`, then runs the tests.

Note: you may need to adjust the paths in the Makefile pointing
to your lua library installation.

For documentation, see the comments in `djot.h`.

For an example of the use of the library, see `tests.c`.

If you have emscripten installed (`emcc`), you can compile to
wasm/js and run djot in the browser:

```
$ make wasm
$ cd web/dist
$ python3 -m http.server
$ open http://localhost:8000/
```

