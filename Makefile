.PHONY: all clean distclean

all: sign.cer

clean:
	$(RM) ca.cer ca_key.pem ca.srl sign_key.pem sign.csr

distclean: clean
	$(RM) sign.cer

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

sign_key.pem sign.csr:
	openssl req \
		-new \
		-newkey rsa:2048 \
		-keyout sign_key.pem \
		-sha256 \
		-nodes \
		-subj '/emailAddress=user@example.com/CN=user/C=JP' \
		-out sign.csr

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
