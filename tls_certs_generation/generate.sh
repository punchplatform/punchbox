#!/bin/bash -ue

SECDIR=../punch/resources/security/platform_certs
rm -rf ${SECDIR}/server*
./create-server-cert.sh
./create-gateway-cert.sh

cd $SECDIR

for srv in 1 2 3 4 5 ;  do
	cd server${srv}
	mv server.crt server-cert.pem
	[[ -e admin.crt ]] && mv admin.crt admin-server-cert.pem && git add admin-server-cert.pem
	[[ -e admin.pem ]] && mv admin.pem admin-server-key.pem && git add admin-server-key.pem

	for secret_file in operator_user_secrets.json gateway_user_secrets.json shiva_secrets.json ; do
		git checkout "${secret_file}"  2>/dev/null 1>&2 || true
	done

	rm *.p12

	mv server.pem server-key.pem
	mv server.jks server-keystore.jks
	#git checkout operator_user_secrets.json
	git add server-cert.pem server-key.pem server-keystore.jks
	cd ..
done

mv root-ca.crt ca.pem
git add ca.pem
git add truststore.jks
