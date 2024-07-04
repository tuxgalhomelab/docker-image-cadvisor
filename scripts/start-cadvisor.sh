#!/usr/bin/env bash
set -E -e -o pipefail

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

validate_prereqs() {
    if [ $(id -u) -ne 0 ]; then
        echo "Cannot start this container as non-root!"
        echo "Ability to switch user to cadvisor requires launching as root!"
        echo "Need to run this container as root, however running as ${USER:?} [$(id -a)]"
        exit 1
    fi

    if ! capsh --has-b=cap_syslog; then
        echo "You are attempting to run the container without SYSLOG capability!"
        echo "Without SYSLOG capability, /dev/kmsg cannot be accessed!"
        echo "Please run with --cap-add=SYSLOG instead!"
        exit 1
    fi
}

start_cadvisor() {
    echo "Starting cAdvisor ..."
    echo

    exec capsh \
        --keep=1 \
        --user=cadvisor \
        --inh=cap_syslog \
        --addamb=cap_syslog \
        -- \
        -c "cadvisor -logtostderr $@"
}

set_umask
validate_prereqs
start_cadvisor "$@"
