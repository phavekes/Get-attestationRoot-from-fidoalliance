#!/bin/bash
if [ ! -f ".token" ]; then
    echo "The file .token does not exist".
    echo "Please request a token at https://mds2.fidoalliance.org/tokens/"
    echo "and put the token in a file called 'token'"
    exit 1
fi
# Get the token for accessing the toc
TOKEN=`cat .token`
# Get the root certificate for validating the output
wget --quiet --backups=1 https://mds.fidoalliance.org/Root.cer
# get the jwt for the toc
curl "https://mds2.fidoalliance.org/?token=$TOKEN" --silent --output toc.jwt
# Extract the CA cert and the signing cert
step crypto jwt inspect --insecure < toc.jwt | jq -r '.header.x5c[1]' | base64 -d | openssl x509 -inform der -out CA-1.pem
step crypto jwt inspect --insecure < toc.jwt | jq -r '.header.x5c[0]' | base64 -d | openssl x509 -inform der -out MetadataTOCSigner3.pem
# Validate the certs
openssl verify -CAfile Root.cer CA-1.pem 
openssl verify -CAfile Root.cer -untrusted CA-1.pem MetadataTOCSigner3.pem 
# TODO: Exit if validation fails
openssl x509 -in MetadataTOCSigner3.pem -noout -pubkey > MetadataTOCSigner3.pub
# Extract the json from the jwt
step crypto jwt verify --key MetadataTOCSigner3.pub --subtle < toc.jwt | jq .payload > toc.json
rm toc.jwt
# Convert the interesting parts of the json to a line for looping over it
for k in $(jq -c -r '.entries[]|[.url,.statusReports[0].status,.statusReports[0].certificationDescriptor,.aaid,.aaguid]| @csv' toc.json | sed 's/\ /_/g'); do
	# Extract the fields to variables, and clean them up
	URL=`echo $k | awk -F',' '{print $1}' | sed 's/"//g'`
	STATUS=`echo $k | awk -F',' '{print $2}' | sed 's/"//g'`
	NAME=`echo $k | awk -F',' '{print $3}' | sed 's/"//g'`
	AAID=`echo $k | awk -F',' '{print $4}' | sed 's/"//g'`
	AAGUID=`echo $k | awk -F',' '{print $5}' | sed 's/"//g'`
	# Create an uniq name for the cert output
	NAME="${NAME}_${AAID}_${AAGUID}" 
	# If the key is certified, get the jwt and write the certificate to file
	case $STATUS in 
		'FIDO_CERTIFIED'|"FIDO_CERTIFIED_L1"|"FIDO_CERTIFIED_L2" )
		echo "$NAME is certified"
		curl "$URL/?token=$TOKEN" --silent --output $NAME.jwt
		if test -f "$NAME.jwt"; then
			CERT=`cat $NAME.jwt | step base64 -d | jq -r -c '[.attestationRootCertificates]' | sed 's/\[\[\"//g' | sed 's/\"\]\]//g' | sed -e "s/.\{64\}/&\n/g"`
			if [[ $CERT = MII* ]]; then  
				echo "-----BEGIN CERTIFICATE-----
$CERT
-----END CERTIFICATE-----
" > $NAME.pem
			fi
			rm $NAME.jwt
		fi
		;;
		*)
		echo "$NAME is $STATUS"
	esac
done
# Cleanup
rm toc.json
rm Root.cer
rm CA-1.pem
rm MetadataTOCSigner*.pem
rm MetadataTOCSigner3.pub

