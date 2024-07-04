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

# We do this to allow the docker socket to be accessible as the
# non-root cadvisor user.
add_cadvisor_user_to_docker_group() {
    if [ -S /var/run/docker.sock ]; then
        local host_docker_gid=$(stat -c '%g' /var/run/docker.sock)
        echo "Creating group 'docker' with gid '${host_docker_gid:?}'"
        groupadd --gid ${host_docker_gid:?} docker
        echo "Adding user 'cadvisor' to the group 'docker'"
        usermod --append --groups ${host_docker_gid:?} cadvisor
    else
        echo "/var/run/docker.sock was not volume mounted! Exiting ..."
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
add_cadvisor_user_to_docker_group
start_cadvisor "$@"
