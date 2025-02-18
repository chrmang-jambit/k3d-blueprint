#!/bin/bash

get_workdir() {
    DIRPATH=$(dirname $0)
    cd $DIRPATH
    pwd
    cd - >/dev/null
}

start() {
    # network
    docker network ls | grep $NETWORK >/dev/null 2>&1 && echo network $NETWORK already exists || docker network create $NETWORK

    # registry
    if [ "$REGISTRY" != "null" ]; then
        mkdir -p $HOME/k3d/registry
        k3d registry list $REGISTRY_HOST >/dev/null 2>&1 && echo registry $REGISTRY_HOST already exists || k3d registry create --default-network $NETWORK --port 127.0.0.1:$REGISTRY_PORT --volume $HOME/k3d/registry:/var/lib/registry ${REGISTRY_HOST:4}
    fi

    # cluster
    k3d cluster list $CLUSTER >/dev/null 2>&1 && k3d cluster start $CLUSTER || k3d cluster create -c $WORKDIR/k3d-config.yaml --kubeconfig-update-default=false

    # write kubeconfig.yaml
    k3d kubeconfig get laptop >kubeconfig.yaml
}

stop() {
    k3d cluster list $CLUSTER >/dev/null 2>&1 && k3d cluster stop $CLUSTER || echo Cluster was already stopped
    if [ "$REGISTRY" != "null" ]; then
        k3d registry list $REGISTRY_HOST >/dev/null 2>&1 && k3d registry delete $REGISTRY_HOST && echo registry $REGISTRY_HOST stopped || echo registry $REGISTRY_HOST already stopped
    fi
}

delete() {
    k3d cluster list $CLUSTER >/dev/null 2>&1 && k3d cluster delete $CLUSTER || echo Cluster was already deleted
    k3d registry list $REGISTRY_HOST >/dev/null 2>&1 && k3d registry delete $REGISTRY_HOST && echo Registry deleted || echo Registry was already deleted
    docker network ls | grep $NETWORK >/dev/null 2>&1 && docker network rm $NETWORK >/dev/null && echo Network deleted || echo Network was already deleted
    if [ -e kubeconfig.yaml ]; then
        rm kubeconfig.yaml
    fi
}

export WORKDIR=$(get_workdir)
export NETWORK=$(cat k3d-config.yaml | yq ".network")
export REGISTRY=$(cat k3d-config.yaml | yq ".registries.use[0]")
REG=(${REGISTRY//:/ })
export REGISTRY_HOST=${REG[0]}
export REGISTRY_PORT=${REG[1]}
export CLUSTER=$(cat k3d-config.yaml | yq ".metadata.name")

CMDS=(k3d kubectl k9s direnv)
for c in ${CMDS[@]}; do
    if ! command -v $c &>/dev/null; then
        echo "${c} not found"
        exit
    fi
done

case $1 in
start)
    start
    ;;
stop)
    stop
    ;;
delete)
    delete
    ;;
*)
    echo "$0 <start|delete|stop>"
    ;;
esac

direnv reload
