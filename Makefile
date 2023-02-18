.PHONY: all clean distclean

all: example.mobileprovision

clean:
	$(RM) ca.cer ca_key.pem ca.srl sign_key.pem sign.csr sign.cer example.plist

distclean: clean
	$(RM) example.mobileprovision

ca.cer ca.srl: ca_key.pem
	openssl req \
		-x509 \
		-new \
		-noenc \
		-key $< \
		-sha1 \
		-days 365 \
		-subj '/C=US/O=Example Inc./OU=Example Certification Authority/CN=Example Root CA' \
		-addext 'keyUsage=critical,keyCertSign,cRLSign' \
		-outform DER \
		-out $@

ca_key.pem:
	openssl genrsa -out $@ 2048

sign.csr: sign_key.pem
	openssl req \
		-new \
		-noenc \
		-key $< \
		-sha256 \
		-subj '/emailAddress=user@example.com/CN=user/C=JP' \
		-out sign.csr

sign_key.pem:
	openssl genrsa -out $@ 2048

sign.cer: ca.cer ca_key.pem sign.csr codesign_cert.conf
	openssl x509 \
		-req \
		-CA ca.cer \
		-CAkey ca_key.pem \
		-in sign.csr \
		-outform DER \
		-out $@ \
		-days 365 \
		-CAcreateserial \
		-subj '/UID=0000000000/CN=iPhone Developer: user@example.com (0000000000)/OU=0000000000/C=US' \
		-extfile codesign_cert.conf

example.plist: example.plist.in sign.cer
	m4 \
		-D '__APP_ID_NAME__=Example App' \
		-D '__APP_ID_PREFIX__=com.example' \
		-D "__CREATION_DATE__=$$(date -u +%Y-%m-%dT%H-%M-%SZ)" \
		-D "__DEVELOPER_CERTIFICATES__=$$(openssl x509 -inform DER -in sign.cer -outform PEM | sed -e '/-----/d' | tr -d '\n')" \
		-D "__EXPIRATION_DATE__=$$(openssl x509 -enddate -dateopt iso_8601 -noout -inform DER -in sign.cer | cut -d= -f2 | tr ' ' T)" \
		-D '__NAME__=Example mobileprovision' \
		-D '__TEAM_NAME__=Example Inc.' \
		-D '__TIME_TO_LIVE__=365' \
		-D "__UUID__=$$(uuidgen)" \
		$< > $@

example.mobileprovision: example.plist sign.cer sign_key.pem
	openssl cms \
		-sign \
		-md sha1 \
		-binary \
		-nodetach \
		-signer sign.cer \
		-keyform PEM \
		-inkey sign_key.pem \
		-in $< \
		-outform DER \
		-out $@
