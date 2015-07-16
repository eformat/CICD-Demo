#!/bin/bash

cd $(dirname $0)/..

. environment

if ! which java &>/dev/null; then
  echo 'Please install Java! :)'
  echo 'hint: yum -y install java-1.8.0-openjdk-headless'
  exit 1
fi

bin/cache.sh

sudo htpasswd -b /etc/openshift/openshift-passwd $DEMOUSER $DEMOPW

for img in $STI_IMAGESTREAMS; do
  sudo oc create -n openshift -f - <<EOF
kind: ImageStream
apiVersion: v1
metadata:
  name: ${img##*/}
spec:
  dockerImageRepository: $img
  tags:
  - name: latest
EOF
done

su - devops
oc login $OSEARGS -u $DEMOUSER -p $DEMOPW

for proj in $INTEGRATION $DEMOUSER; do
  oc new-project $proj
 
  for repo in $INTEGRATION_REPOS; do
    monster/$repo/deploy.sh
    [ -e monster/$repo/build.sh ] && monster/$repo/build.sh
  done
done

for proj in $PROD; do
  oc new-project $proj

  for repo in $PROD_REPOS; do
    monster/$repo/deploy.sh
  done
done

for proj in $INFRA; do
  oc new-project $proj

  for repo in $INFRA_REPOS; do
    infra/$repo/deploy.sh
  done
done

# serviceAccount required for containers running as root
#echo '{"kind": "ServiceAccount", "apiVersion": "v1", "metadata": {"name": "root"}}' | sudo oc create -n infra -f -
#(sudo oc get -o yaml scc privileged; echo - system:serviceaccount:infra:root) | sudo oc update scc privileged -f -
