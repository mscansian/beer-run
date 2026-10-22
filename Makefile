DEVICE    ?= fr955
GARMIN_DEV := tools/garmin-dev/scripts/host/garmin-dev.sh
# The launcher names the container after the project path relative to $HOME.
CONTAINER := gd-$(subst /,-,$(patsubst $(HOME)/%,%,$(CURDIR)))
PRG       := bin/beer-$(DEVICE).prg
KEY       := $(HOME)/.connectiq/developer_key.der
CLI       := ~/go/bin/connect-iq-sdk-manager-cli

# The desktop mounts the watch over MTP. 091e is Garmin's USB vendor ID.
WATCH_MOUNT = $$(ls -d /run/user/$$(id -u)/gvfs/mtp:host=091e_* 2>/dev/null | head -1)
WATCH_URI   = $$(gio mount -l 2>/dev/null | grep -o 'mtp://091e_[^/ ]*/' | head -1)
NO_WATCH    = echo "error: no Garmin watch is mounted. Plug it in over USB and wait for it to show up in the file manager." >&2; exit 1

.PHONY: image login sdk up down build sim upload eject clean

# Build the toolchain image. Needed once, or after changing tools/garmin-dev.
image:
	tools/garmin-dev/scripts/host/build.sh

# Accept the SDK license and sign in to Garmin in the browser. The token is
# saved in ~/.Garmin/ConnectIQ and renews itself, so this is only needed
# again if SDK or device downloads start failing with a login error.
# --network host lets the browser reach the CLI's local callback server.
login:
	docker run --rm -it --network host \
		-v $(HOME)/.Garmin:$(HOME)/.Garmin \
		--entrypoint bash garmin-dev:latest \
		-c '$(CLI) agreement accept && $(CLI) login'

# Download the newest SDK and the device files for the devices in manifest.xml.
sdk: up
	docker exec -w $(CURDIR) $(CONTAINER) bash -c \
		'$(CLI) sdk set ">=0.0.0" && $(CLI) device download --manifest manifest.xml --include-fonts && verify-connectiq'

up:
	$(GARMIN_DEV) up $(CURDIR)

down:
	$(GARMIN_DEV) down $(CURDIR)

build: up
	docker exec -w $(CURDIR) $(CONTAINER) monkeyc -d $(DEVICE) -f beer.jungle -o $(PRG) -y $(KEY) -l 3 -w

# Build and open the app in the simulator window.
sim: up
	$(GARMIN_DEV) sim $(CURDIR) $(DEVICE)

# Copy the app to the watch. The watch installs it once it is ejected.
upload: build
	@watch="$(WATCH_MOUNT)"; [ -n "$$watch" ] || { $(NO_WATCH); }; \
	gio copy $(PRG) "$$watch/Internal Storage/GARMIN/Apps/BEER.PRG" && \
	echo "Copied to the watch. Run 'make eject' before unplugging."

eject:
	@uri="$(WATCH_URI)"; [ -n "$$uri" ] || { $(NO_WATCH); }; \
	gio mount -u "$$uri" && echo "Ejected. Safe to unplug."

clean:
	rm -rf bin
