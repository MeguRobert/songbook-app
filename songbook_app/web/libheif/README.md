# libheif, vendored

`libheif.js` and `libheif.wasm` are an unmodified copy of the `libheif-wasm`
build shipped in [`libheif-js`](https://www.npmjs.com/package/libheif-js)
**1.19.8**, which wraps [libheif](https://github.com/strukturag/libheif) 1.19.8
compiled to WebAssembly by Emscripten. Only the decoder is used.

```
npm pack libheif-js@1.19.8
tar -xzf libheif-js-1.19.8.tgz
cp package/libheif-wasm/libheif.js   songbook_app/web/libheif/
cp package/libheif-wasm/libheif.wasm songbook_app/web/libheif/
cp package/libheif-wasm/LICENSE      songbook_app/web/libheif/
```

sha384 of the two files as vendored, so a replacement can be checked:

```
libheif.js    e1a7b05404fdfb566bb308a7100af727d15445150e4f334285b331c282a735f44b38cd319f200c4b7f6896c22082601a
libheif.wasm  c664bcf8af1bd9f98f6ba87edd9ceb8841fd529ca9ab305c2717903ec234acec969a2603117527b7a42ab29bf235fbc2
```

## Why these files are in the repository rather than on a CDN

They are 1.1 MB raw and **367 KB over the wire** (gzip: 26 KB of glue, 341 KB of
WebAssembly), and they are fetched only by `heif_decoder_web.dart`, only after
the browser has already refused to decode a file whose leading bytes say HEIC or
HEIF. A visitor who never photographs a page, and a visitor whose phone writes
JPEG, never request either file.

Self-hosting is what keeps `web/index.html`'s Content-Security-Policy untouched:
`script-src 'self'` covers the glue, `connect-src 'self'` covers the `fetch` the
glue makes for the `.wasm`, and `'wasm-unsafe-eval'` — already there for CanvasKit
— covers instantiating it. A CDN copy would have needed neither host added, since
`cdn.jsdelivr.net` is already allowed, but it would have put a third party in the
path of a feature that otherwise needs no network at all. Tesseract is fetched
from unpkg today and that is a known failure mode when a filter blocks the CDN;
one instance of it is enough.

It does **not** cost every user 1.1 MB of install. Flutter's generated service
worker downloads only `CORE` eagerly — `main.dart.js`, `index.html`,
`flutter_bootstrap.js` and the two manifests. Everything else in this directory
lands in `RESOURCES`, which the `fetch` handler caches lazily, on first request.
So the file is free until it is used and durably cached afterwards, which is
strictly better than the ordinary HTTP cache Tesseract's core relies on.

No subresource integrity attribute is set on the injected `<script>`. It would
assert nothing: the file is served from this app's own origin, by the same
deploy that served the page asking for it.

## Licence

libheif is **LGPL-3.0**; the full text is in `LICENSE`. It is shipped here as a
separate, unmodified, dynamically loaded library, so replacing it is a matter of
overwriting the two files above.
