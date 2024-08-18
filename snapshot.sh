#!/bin/bash

# GLOBALS
DISKS=5

# -------------------------------------------------------
# FUNCTIONS

usage() {
    echo "Usage: $0 OPT NAME"
    echo "OPT must be either 'create' or 'revert'"
    exit 1
}

create() {
    # create snapshot
    echo "listing current snapshots: "
    sudo virsh snapshot-list $NAME
    echo "Detaching disks."
    for J in $(seq 1 $(( $DISKS )) ); do
        L=$(echo $J | tr 0123456789 abcdefghij)
        sudo virsh detach-disk $NAME vd$L
    done
    sleep 3
    sudo virsh snapshot-create-as --atomic --domain $NAME --name clean
    sudo virsh snapshot-list $NAME
    sudo virsh snapshot-info --snapshotname clean $NAME

    echo "Restarting $NAME (Disks should re-attach on restart)"
    sudo virsh destroy $NAME
    sudo virsh start $NAME
}

revert() {
    # revert to snapshot
    sudo virsh snapshot-revert --domain $NAME --snapshotname clean
}

# -------------------------------------------------------
# VALIDATIONS

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    usage
fi

OPT=$1
NAME=$2

# Validate OPT argument
if [ "$OPT" != "create" ] && [ "$OPT" != "revert" ]; then
    usage
fi

if [[ -z $NAME ]]; then
    usage
fi

# Ensure VM $NAME exists
sudo virsh list --all --name | grep -q $NAME
if [[ $? -gt 0 ]]; then
    echo "There is no VM named \"$NAME\""
    exit 1
fi

# Ensure VM $NAME is running
sudo virsh list --name | grep -q $NAME
if [[ $? -gt 0 ]]; then
    echo "VM \"$NAME\" is not running. Please start it before snapshotting."
    exit 1
fi
# -------------------------------------------------------
# MAIN

case $OPT in
    create)
        echo "Creating $NAME..."
        create
        ;;
    revert)
        echo "Reverting $NAME..."
        revert
        ;;
esac

exit 0
