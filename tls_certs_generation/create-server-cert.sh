#!/bin/bash -ue
#
#  This is a script to create default certificate
#
#


# Change use_simple_password to false to generate a new password for each keystore
# Change this parameter to true to generate trusstore with password equal to pass_truststore value
# and all keystore with password equal to pass_keystore value 
use_simple_password=true

pass_truststore=secret123
pass_keystore=secret123


cert_dir=../punch/resources/security/platform_certs/

source node.template

umask 027

echo "*************"
echo "Start certificate creation process  ..."
if [ ! -d $cert_dir ];
then
   mkdir -p $cert_dir 
  echo "Directory created: " $cert_dir
else
  echo " "
fi
echo "Certificates will be created in directory: " $PWD/$cert_dir


# Create Root CA
echo "*************"

if [[ ( -f  "$cert_dir/root-ca.crt" ) || ( -f "$cert_dir/root-ca.key" ) ]]; 
then
  echo "ROOT CA already exists";
else
  echo "Start creating Root CA ..."
  openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -config 'root-ca.cnf' -extensions req_ext -keyout $cert_dir/root-ca.key -out $cert_dir/root-ca.crt 
  if [[ $use_simple_password = true ]] 
  then
    echo "Use simple password for Truststore"
    echo $pass_truststore > $cert_dir/truststore-pass
  else
    mktemp -u XXXXXXXXXXXXXXXXXXX > $cert_dir/truststore-pass
  fi
  keytool -import -file $cert_dir/root-ca.crt -alias rootCA -keystore $cert_dir/truststore.jks -trustcacerts -noprompt -storepass $(cat $cert_dir/truststore-pass) 
   cp $cert_dir/root-ca.crt $cert_dir/fullchain.crt
  echo -n '00' > $cert_dir/root-ca.serial
  echo "ROOT CA generated";
fi

# Create Certificates 
echo "*************"
echo "Start creating certificates from node-list.ini"

while IFS=";" read -r n_name n_ip n_name_http n_ip_http 
do 
  if [[ ( -d  "$cert_dir/$n_name" ) ]]; 
then
  echo "Diretory already exists: " $cert_dir/$n_name
  echo "No certificate generated for host : " $n_name
else
   mkdir -p $cert_dir/$n_name
   echo "Directory created: " $cert_dir/$n_name
   subject=$dn_template"/CN="$n_name
   subject_admin=$dn_template"/CN="$n_name"-admin"
   altname="subjectAltName=DNS:"$n_name",IP:"$n_ip",DNS:"$n_name_http",IP:"$n_ip_http
   echo "[ req_ext ]" > $cert_dir/$n_name/$n_name.ext
   echo $altname >> $cert_dir/$n_name/$n_name.ext
   openssl req -new -newkey rsa:2048 -sha256 -nodes -subj "$subject" -addext "$altname" -out $cert_dir/$n_name/$n_name.csr -keyout $cert_dir/$n_name/server.pem
   openssl req -new -newkey rsa:2048 -sha256 -nodes -subj "$subject_admin" -addext "$altname" -out $cert_dir/$n_name/$n_name.admin.csr -keyout $cert_dir/$n_name/admin.pem
   openssl x509 -req -extensions req_ext -extfile $cert_dir/$n_name/$n_name.ext -in $cert_dir/$n_name/$n_name.csr -out $cert_dir/$n_name/server.crt -CA $cert_dir/root-ca.crt -CAkey $cert_dir/root-ca.key -CAserial $cert_dir/root-ca.serial -days 1000 
   openssl x509 -req -extensions req_ext -extfile $cert_dir/$n_name/$n_name.ext -in $cert_dir/$n_name/$n_name.admin.csr -out $cert_dir/$n_name/admin.crt -CA $cert_dir/root-ca.crt -CAkey $cert_dir/root-ca.key -CAserial $cert_dir/root-ca.serial -days 1000 
   rm $cert_dir/$n_name/$n_name.ext
   rm $cert_dir/$n_name/$n_name.csr
   rm $cert_dir/$n_name/$n_name.admin.csr
   echo $n_name" certificate generated"
   if [[ $use_simple_password = true ]] 
   then
     echo "Use simple password for keystore"
     echo $pass_keystore > $cert_dir/$n_name/keystore-pass
   else
     mktemp -u XXXXXXXXXXXXXXXXXXX > $cert_dir/$n_name/keystore-pass
   fi
   openssl pkcs12 -export -in $cert_dir/$n_name/server.crt -inkey $cert_dir/$n_name/server.pem -chain -CAfile  $cert_dir/root-ca.crt -name  $n_name -passout  pass:$(cat $cert_dir/$n_name/keystore-pass) -out $cert_dir/$n_name/server.p12
   keytool -importkeystore -srckeystore $cert_dir/$n_name/server.p12 -srcstoretype pkcs12 -srcstorepass $(cat $cert_dir/$n_name/keystore-pass) -destkeystore $cert_dir/$n_name/server.jks -deststoretype jks -alias $n_name -noprompt -storepass $(cat $cert_dir/$n_name/keystore-pass)
#   keytool -import -trustcacerts -file $cert_dir/root-ca.crt -alias root -keystore $cert_dir/$n_name/server.jks -noprompt -storepass $(cat $cert_dir/$n_name/keystore-pass)
#   keytool -import -file $cert_dir/$n_name/server.crt -alias $n_name.crt -keystore $cert_dir/$n_name/server.jks -noprompt -storepass $(cat $cert_dir/$n_name/keystore-pass)
   echo $n_name" keystore generated"
fi
done < "node.list"

echo "*************"
echo "End of certificate creation process."
