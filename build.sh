#!/bin/bash

echo -e "Creating configuration directory under /etc/cas"
mkdir -p /etc/cas/config

echo -e "Copying configuration files"
cp -rfv etc/cas/* /etc/cas

function help() {
	echo "Usage: build.sh [clean|package|install|run]"	
}

function clean() {
	./mvnw clean
}

function package() {
	./mvnw clean package -T 5
}

function install() {
	./mvnw clean package install -T 5
}

function run() {
	install && java -Xdebug -Xrunjdwp:transport=dt_socket,address=5000,server=y,suspend=n -jar target/cas.war 
}

if [ $# -eq 0 ]; then
    echo -e "No commands provided. Defaulting to [run]\n"
    run
    exit 0
fi

for var in "$@"
do
    case "$var" in
	"clean")
	    clean
	    ;;   
	"package")
	    package
	    ;;
	"install")
	    install
	    ;;
	"run")
	    run
	    ;;
	*)
	    help
	    ;;
	esac
done
