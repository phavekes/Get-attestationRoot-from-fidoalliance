This wil download all FIDO2 certified attestation certificates from the Fidoalliance metadata reposirory.

Install the 'step' tool (Debian/Ubuntu Linux):

	Install step using dpkg, where X.Y.Z is the latest release:
	$ wget https://github.com/smallstep/cli/releases/download/X.Y.Z/step_X.Y.Z_amd64.deb
	$ sudo dpkg -i step_X.Y.Z_amd64.deb

Install 'jq':
	$ apt install jq

Register for an token on 
	https://mds2.fidoalliance.org/tokens/

Put the token in a file named '.token' in this directory.

Run ./update.sh

