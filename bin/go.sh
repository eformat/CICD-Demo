#!/bin/bash

cd $(dirname $0)/..
DIR=`pwd`

. environment

if ! which java &>/dev/null; then
  echo 'Please install Java! :)'
  echo 'hint: yum -y install java-1.8.0-openjdk-headless'
  exit 1
fi

[ "$USER" -ne "root" ]; exit "please run as root on ose-master"

$DIR/bin/cache.sh

htpasswd -b /etc/openshift/openshift-passwd $DEMOUSER $DEMOPW

for img in $STI_IMAGESTREAMS; do
  oc create -n openshift -f - <<EOF
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

for proj in $INTEGRATION $DEMOUSER; do
  oadm new-project $proj --display-name="$proj" --description="CICD $proj" --admin=$DEMOUSER
 
  for repo in $INTEGRATION_REPOS; do  	
  	su $DEMOUSER <<EOF
		oc login -u $DEMOUSER -p $DEMOPW $OSEARGS
		oc project $proj
		$DIR/monster/$repo/deploy.sh  	
EOF

  	su $DEMOUSER <<EOF
  		oc login -u $DEMOUSER -p $DEMOPW $OSEARGS
  		oc project $proj
   		[ -e $DIR/monster/$repo/build.sh ] && $DIR/monster/$repo/build.sh
EOF
   		
  done
done

for proj in $PROD; do
  oadm new-project $proj --display-name="$proj" --description="CICD $proj" --admin=$DEMOUSER

  for repo in $PROD_REPOS; do
		oc login -u $DEMOUSER -p $DEMOPW $OSEARGS
		oc project $proj
		$DIR/monster/$repo/deploy.sh
  done
done

for proj in $INFRA; do
  oadm new-project $proj --admin=$DEMOUSER

  for repo in $INFRA_REPOS; do
    infra/$repo/deploy.sh
  done
done

# serviceAccount required for containers running as root
echo '{"kind": "ServiceAccount", "apiVersion": "v1", "metadata": {"name": "root"}}' | sudo oc create -n infra -f -
(sudo oc get -o yaml scc privileged; echo - system:serviceaccount:infra:root) | sudo oc update scc privileged -f -
