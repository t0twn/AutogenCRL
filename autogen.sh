BASE_DIR="."
SUB_DIR="tls"
WORKING_DIR=""

CA_KEY="private/cakey.pem"
CA_CRT="certs/cacert.pem"

SERVER_KEY="server.key.pem"

OPENSSL_CNF="openssl.cnf"
EXT_TEMPLATE_CNF="ext_template.cnf"

NU_CRT=3

prepare(){
    # update path to absolute
    WORKING_DIR=`realpath $BASE_DIR/$SUB_DIR`
    CA_KEY=$WORKING_DIR/$CA_KEY
    CA_CRT=$WORKING_DIR/$CA_CRT

    # update openssl.cnf dir
    sed -i "s|ToBeReplaced|$WORKING_DIR|" openssl.cnf 

    # create directory structure
    if [ -e $WORKING_DIR ];then 
        return
    fi

    mkdir $WORKING_DIR
    cp $OPENSSL_CNF $WORKING_DIR
    cp $EXT_TEMPLATE_CNF $WORKING_DIR

    cd $WORKING_DIR

    mkdir certs private crl
    touch index.txt serial
    touch crlnumber
    echo 01 > serial
    echo 1000 > crlnumber
}

gen_ca(){

    ## navigate inside your tls path
    cd $WORKING_DIR

    ## generate rootca private key
    [ -e $CA_KEY ] || openssl genrsa  -out $CA_KEY 4096

    ## generate rootCA certificate
    [ -e $CA_CRT ] || openssl req -new -x509 -days 3650 -batch -config $OPENSSL_CNF  -key $CA_KEY -out $CA_CRT

    ## Verify the rootCA certificate content and X.509 extensions
    openssl x509 -noout -text -in $CA_CRT
}

gen_crt(){

    cd $WORKING_DIR

    ## generate server private key
    [ -e $SERVER_KEY ] || openssl genrsa -out $SERVER_KEY 4096

    for i in `seq 1 $NU_CRT`;
    do
        ## generate certificate signing request
        [ -e certs/server-$i.csr ] || openssl req -config $OPENSSL_CNF -batch -new -key $SERVER_KEY -out certs/server-$i.csr -subj "/CN=server$i.example.com"

        ## generate and sign the server certificate using rootca certificate
        [ -e certs/server-$i.crt ] || openssl ca -config $OPENSSL_CNF -batch -notext -in certs/server-$i.csr -out certs/server-$i.crt -extfile $EXT_TEMPLATE_CNF
    done
}

gen_crl(){
    cd $WORKING_DIR

    for i in `seq 1 $NU_CRT`;
    do
        openssl ca -config $OPENSSL_CNF -revoke certs/server-$i.crt
    done
    openssl ca -config $OPENSSL_CNF -gencrl -out crl/rootca.crl
    openssl crl -in crl/rootca.crl -text -noout
}

main(){
    prepare
    gen_ca
    gen_crt
    gen_crl
}

main
#<<<END
