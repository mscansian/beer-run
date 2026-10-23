# Beer Counter

A Connect IQ watch app for Garmin Forerunner watches (955 / 955 Solar, 255 / 255S and their Music versions, and 55) that counts the beers in a drinking session.

- Press START (or double-tap the screen) to add a beer. The watch buzzes, and the screen shows how long ago the last one was.
- UP and DOWN move through three pages, which loop: the counter, stats for the current session laid out like a running app (a live timer, litres, beers, and the pace in time per litre), and the history of past sessions.
- Hold UP on any page to open the menu: undo the last beer, finish the session (saves it to history), set a size, set a goal, or discard the session without saving. Finishing and discarding ask you to confirm.
- A session also ends by itself: after 8 hours without a beer, the next one starts a new session.
- The goal is a scroll wheel from 1 to 30. It starts at "No goal". With a goal set, a ring around the edge fills up as you drink and turns red when you go over.
- Every beer counts as the current size: small 330 ml, can 350 ml, pint 473 ml or bottle 600 ml. It starts as a pint.
- The glance (not on the Forerunner 55) shows the count, the time since the last beer and, with a goal set, a progress bar. Select the glance to open the app.
- Everything is saved on the watch, so closing the app does not lose it.

## Quickstart

The toolchain runs in Docker (`tools/garmin-dev`), because the Connect IQ simulator needs a WebKit version that current Fedora does not ship. The Garmin SDK, the device files and your login live in `~/.Garmin`. The signing key lives in `~/.connectiq`. Both are mounted into the container.

First time only:

```bash
make image   # build the toolchain image
make login   # accept the SDK license and sign in to Garmin in the browser
make sdk     # download the SDK and the device files
```

`make login` saves a token that renews itself. Run it again only if `make sdk` fails with a login error.

Develop:

```bash
make sim     # build and open the app in the simulator
make build   # build bin/beer-fr955.prg
make package # build bin/beer.iq for the Connect IQ Store
make down    # stop the container
```

Install on the watch (plug it in over USB first):

```bash
make upload  # build and copy the app to the watch
make eject   # eject it; the watch installs the app once unplugged
```
