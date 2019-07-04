#!/bin/bash

###########################################################################################
# variables
###########################################################################################

[ -f common.bash  ] && source common.bash
[ -f dynamic.bash ] && source dynamic.bash
[ -f local.bash   ] && source local.bash

TF_ARGS=""
NUM_MASTERS=3
NUM_WORKERS=2

cd $E2E_ENV
[ -f "ci.tfvars" ] && [ "$CI" = "true" ] && TF_ARGS="$TF_ARGS -var-file=ci.tfvars"

###########################################################################################
# increase one master
###########################################################################################

echo ">>> Adding one master..."
TF_VAR_master_count=$NUM_MASTERS TF_VAR_worker_count=$NUM_WORKERS \
    terraform apply -auto-approve $TF_ARGS
if [ $? -ne 0 ] ; then
    echo ">>> FAILED: could not add one master"
    exit 1
fi

###########################################################################################
# checks
###########################################################################################

echo ">>> Checking we can get cluster info with kubectl..."
kubectl --kubeconfig=kubeconfig.local get nodes
if [ $? -ne 0 ] ; then
    echo ">>> FAILED: could not get the nodes with kubectl"
    exit 1
fi

OUT=$(kubectl --kubeconfig=kubeconfig.local get nodes --show-labels)
if [ $? -ne 0 ] ; then
    echo ">>> FAILED: could not get the number of nodes with kubectl"
    exit 1
fi

EXP_NUM_NODES=$((NUM_MASTERS + NUM_WORKERS))
echo ">>> Checking we have $EXP_NUM_NODES nodes..."
CURR_NUM_NODES=$(echo "$OUT" | grep -c "kubernetes.io/hostname")
if [ $CURR_NUM_NODES -ne $EXP_NUM_NODES ] ; then
    echo ">>> FAILED: current number of nodes, $CURR_NUM_NODES, do not match $EXP_NUM_NODES"
    exit 1
fi

EXP_NUM_MASTERS=$NUM_MASTERS
echo ">>> Checking we have $EXP_NUM_MASTERS masters..."
CURR_NUM_MASTERS=$(echo "$OUT" | grep -c "node-role.kubernetes.io/master")
if [ $CURR_NUM_MASTERS -ne $EXP_NUM_MASTERS ] ; then
    echo ">>> FAILED: current number of masters, $CURR_NUM_MASTERS, do not match $EXP_NUM_MASTERS"
    exit 1
fi

