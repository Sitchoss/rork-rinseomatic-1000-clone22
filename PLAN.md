# Make CCTV command centre webviews load URLs reliably in Direct mode + isolate per-slot cookies

## What's wrong right now

The 7 CCTV slots each create a fresh WebView, but:

- They all share the same default cookie & data store, so 7 concurrent logins on the same site will step on each other
- There's no guarantee the webview uses Direct internet (if any proxy/tunnel setting lingers from another feature, pages may fail to load — which is the exact symptom you saw before)
- A bad URL string (missing scheme, stray whitespace, typo) silently loads nothing
- One slow site can hang a slot forever without a clear error

## What will change

### Reliable URL loading in Direct mode

- Each of the 7 CCTV slots will explicitly run in **Direct internet mode** — no proxy, no tunnel, no hybrid routing applied to these webviews
- Pages will load exactly like they do in Safari over your normal connection
- Cookie banner blocker keeps working as today

### Smart URL handling

- URLs are cleaned before loading: stray whitespace trimmed, missing `https://www.` prefix auto-added, obvious typos flagged
- If a URL is truly invalid, the slot shows a clear "Invalid URL" badge instead of a blank pane
- The existing 12-second load timeout stays, but a failed load now shows a short error reason (e.g. "Cannot find host") right on the tile

### Per-slot cookie isolation (Ephemeral)

- Each of the 7 slots gets its own private, in-memory cookie/storage jar that lives only while the command centre is running
- Hitting Start wipes all 7 jars clean, so every window logs in from scratch with its own credentials
- Hitting Stop or leaving the screen destroys the jars completely
- Result: you can run the same URL across all 7 windows with 7 different credential sets at once, and none of them will leak into each other

### Media + autoplay

- Videos and embedded media on target sites will play inline without requiring a tap (so recorded flows that interact with video-heavy pages won't stall)

### Preserved behaviour

- The 1-big + 6-small grid, Start/Stop, slot selection, clone button, credential cycling, and flow playback all stay exactly as they are
- The global network mode selector elsewhere in the app is untouched — and only the CCTV command centre slots are pinned to Direct

