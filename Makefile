TEAM_ID=0000000000
TEAM_NAME=Example Inc.
PROFILE_NAME=Example mobileprovision
BUNDLE_IDENTIFIER=*
APP_ID_NAME=Example App
APP_ID_PREFIX=$(TEAM_ID)
APP_ID=$(APP_ID_PREFIX).$(BUNDLE_IDENTIFIER)
USER_NAME=user
USER_EMAIL=user@example.com
USER_COUNTRY=US
KEYCHAIN_PATH=~/Library/Keychains/login.keychain-db

.PHONY: all clean distclean install uninstall

all: example.mobileprovision

clean:
	$(RM) ca.srl sign.csr example.plist

distclean: clean
	$(RM) ca.cer ca_key.pem sign_key.pem sign.cer example.mobileprovision

install: sign.cer sign_key.pem example.mobileprovision
	security import ca.cer -k $(KEYCHAIN_PATH)
	security import sign.cer -k $(KEYCHAIN_PATH)
	security import sign_key.pem -k $(KEYCHAIN_PATH)
	xed example.mobileprovision

uninstall:
	security delete-certificate -tZ "$$(openssl sha256 ca.cer | cut -d ' ' -f 2)" $(KEYCHAIN_PATH)
	security delete-identity -tZ "$$(openssl sha256 sign.cer | cut -d ' ' -f 2)" $(KEYCHAIN_PATH)
	find ~/Library/MobileDevice/Provisioning\ Profiles -type f -name '*.mobileprovision' -exec grep -aq '$(PROFILE_NAME)' {} \; -delete

ca.cer ca.srl: ca_key.pem
	openssl req \
		-x509 \
		-new \
		-noenc \
		-key $< \
		-sha1 \
		-days 365 \
		-subj '/C=US/O=SELFSIGNED/OU=SELFSIGNED Certification Authority/CN=SELFSIGNED Root CA' \
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
		-subj '/emailAddress=$(USER_EMAIL)/CN=$(USER_NAME)/C=$(USER_COUNTRY)' \
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
		-subj '/UID=0000000000/CN=iPhone Developer: $(USER_EMAIL) (0000000000)/OU=0000000000/C=US' \
		-extfile codesign_cert.conf

example.plist: example.plist.in sign.cer
	m4 \
		-D '__APP_ID_NAME__=$(APP_ID_NAME)' \
		-D '__APP_ID_PREFIX__=$(APP_ID_PREFIX)' \
		-D '__APP_ID__=$(APP_ID)' \
		-D "__CREATION_DATE__=$$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		-D "__DEVELOPER_CERTIFICATES__=$$(openssl x509 -inform DER -in sign.cer -outform PEM | sed -e '/-----/d' | tr -d '\n')" \
		-D "__EXPIRATION_DATE__=$$(openssl x509 -enddate -dateopt iso_8601 -noout -inform DER -in sign.cer | cut -d= -f2 | tr ' ' T)" \
		-D '__NAME__=$(PROFILE_NAME)' \
		-D '__TEAM_NAME__=$(TEAM_NAME)' \
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
