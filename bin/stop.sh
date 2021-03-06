#!/bin/bash

cd $(dirname $0)/..

. environment

su - devops
oc login $OSEARGS -u $DEMOUSER -p $DEMOPW

for proj in $INTEGRATION $PROD $INFRA $DEMOUSER; do
  oc project $proj
  oc delete all --all
done

