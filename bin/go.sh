#!/bin/bash

cd $(dirname $0)/..
DIR=`pwd`

. environment

if ! which java &>/dev/null; then
  echo 'Please install Java! :)'
  echo 'hint: yum -y install java-1.8.0-openjdk-headless'
  exit 1
fi

if [ "$USER" != "root" ]; then exit "please run as root on ose-master"; fi

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

for key in administrator $DEMOUSER; do
  [ -e ~/.ssh/id_rsa_$key ] || ssh-keygen -f ~/.ssh/id_rsa_$key -N ''
done

for proj in $INTEGRATION $DEMOUSER; do
  oadm new-project $proj --display-name="$proj" --description="$proj" --admin=$DEMOUSER
 
  sleep 1;
   
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
  oadm new-project $proj --display-name="$proj" --description="$proj" --admin=$DEMOUSER

  sleep 1;  

  for repo in $PROD_REPOS; do
	su $DEMOUSER <<EOF		
		oc login -u $DEMOUSER -p $DEMOPW $OSEARGS
		oc project $proj
		$DIR/monster/$repo/deploy.sh
EOF
		
  done
done

for proj in $INFRA; do
  oadm new-project $proj --display-name="$proj" --description="$proj" --admin=$DEMOUSER
  
  sleep 1;
  
  # serviceAccount required for containers running as root
  echo '{"kind": "ServiceAccount", "apiVersion": "v1", "metadata": {"name": "root"}}' | oc create -n infra -f -
  (oc get -o yaml scc privileged; echo - system:serviceaccount:infra:root) | oc update scc privileged -f -

  for repo in $INFRA_REPOS; do
	su $DEMOUSER <<EOF		
		oc login -u $DEMOUSER -p $DEMOPW $OSEARGS
		oc project $proj  
		$DIR/infra/$repo/deploy.sh
EOF

  done
done
