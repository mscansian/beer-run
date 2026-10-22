# RUNS IN: container (sourced helper, /usr/local/bin/ciq-jungle.sh)
#
# resolve_jungle: set JUNGLE (file) and APP (its stem) from the current
# directory. Honours a pre-set $JUNGLE env var. Derivation is used only when
# unambiguous: a single *.jungle, or a base jungle whose stem prefixes all
# others (foo.jungle among foo-dev.jungle / foo-beta.jungle). Otherwise the
# caller must set JUNGLE explicitly.
resolve_jungle() {
    if [ -n "${JUNGLE:-}" ]; then
        if [ ! -f "$JUNGLE" ]; then
            echo "error: JUNGLE=$JUNGLE not found" >&2
            exit 1
        fi
        APP="$(basename "$JUNGLE" .jungle)"
        return
    fi
    local jungles=() j k stem ok
    for j in *.jungle; do [ -f "$j" ] && jungles+=("$j"); done
    if [ ${#jungles[@]} -eq 0 ]; then
        echo "error: no *.jungle in $PWD; run from a project root (or set JUNGLE=<file>)" >&2
        exit 1
    fi
    if [ ${#jungles[@]} -eq 1 ]; then
        JUNGLE="${jungles[0]}"
    else
        JUNGLE=""
        for j in "${jungles[@]}"; do
            stem="${j%.jungle}"
            ok=1
            for k in "${jungles[@]}"; do
                case "$k" in
                    "$stem.jungle" | "$stem"-*.jungle) ;;
                    *) ok=0 ;;
                esac
            done
            if [ "$ok" = 1 ]; then
                JUNGLE="$j"
                break
            fi
        done
        if [ -z "$JUNGLE" ]; then
            echo "error: ambiguous jungle files in $PWD (${jungles[*]}); set JUNGLE=<file>" >&2
            exit 1
        fi
    fi
    APP="$(basename "$JUNGLE" .jungle)"
}
