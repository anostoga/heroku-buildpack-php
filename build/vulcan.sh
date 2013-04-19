#!/bin/bash
set -e

DIR_PATH=/app/local
mkdir -p $DIR_PATH/lib
mkdir -p $DIR_PATH/bin
mkdir -p $DIR_PATH/include
mkdir /app/apache
mkdir /app/php

export APACHE_MIRROR_HOST="http://apache.mirrors.tds.net"
PATH=$PATH:$DIR_PATH/bin
export CFLAGS='-g0 -O2 -s -m64 -march=core2 -mtune=generic -pipe '
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I$DIR_PATH/include"
export LDFLAGS="-L$DIR_PATH/lib"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DIR_PATH/lib
export MAKE="/usr/bin/make"

cd /tmp
curl -O http://mirrors.us.kernel.org/ubuntu/pool/universe/m/mcrypt/mcrypt_2.6.8-1_amd64.deb
curl -O http://mirrors.us.kernel.org/ubuntu/pool/universe/libm/libmcrypt/libmcrypt4_2.5.8-3.1_amd64.deb
curl -O http://mirrors.us.kernel.org/ubuntu/pool/universe/libm/libmcrypt/libmcrypt-dev_2.5.8-3.1_amd64.deb
curl -O http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl0.9.8_0.9.8g-4ubuntu3.20_amd64.deb
curl -O http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl-dev_0.9.8g-4ubuntu3.20_amd64.deb

ls -tr *.deb > packages.txt

while read l; do
    ar x $l
    tar -xzf data.tar.gz
    rm data.tar.gz
done < packages.txt

cp -ar /tmp/usr/include/* $DIR_PATH/include
cp -ar /tmp/usr/lib/* $DIR_PATH/lib

echo "downloading libmemcached"
curl -L https://launchpad.net/libmemcached/1.0/1.0.16/+download/libmemcached-1.0.16.tar.gz -o /tmp/libmemcached-1.0.16.tar.gz
echo "downloading PCRE"
curl -L ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.32.tar.gz -o /tmp/pcre-8.32.tar.gz
echo "downloading apr"
curl -L ${APACHE_MIRROR_HOST}/apr/apr-1.4.6.tar.gz -o /tmp/apr-1.4.6.tar.gz
echo "downloading apr-util"
curl -L ${APACHE_MIRROR_HOST}/apr/apr-util-1.5.1.tar.gz -o /tmp/apr-util-1.5.1.tar.gz
echo "downloading httpd"
curl -L ${APACHE_MIRROR_HOST}/httpd/httpd-2.4.3.tar.gz -o /tmp/httpd-2.4.3.tar.gz
echo "downloading php"
curl -L http://us.php.net/get/php-5.4.11.tar.gz/from/us2.php.net/mirror -o /tmp/php-5.4.11.tar.gz
echo "downloading pecl-memcached"
curl -L http://pecl.php.net/get/memcached-2.1.0.tgz -o /tmp/memcached-2.1.0.tgz
echo "download zlib"
curl -L http://zlib.net/zlib-1.2.7.tar.gz -o /tmp/zlib-1.2.7.tar.gz
echo "downloading imap-2007f"
curl -L ftp://ftp.cac.washington.edu/imap/imap-2007f.tar.gz -o /tmp/imap-2007f.tar.gz

tar -C /tmp -xzf /tmp/libmemcached-1.0.16.tar.gz
tar -C /tmp -xzf /tmp/pcre-8.32.tar.gz
tar -C /tmp -xzf /tmp/httpd-2.4.3.tar.gz

tar -C /tmp/httpd-2.4.3/srclib -xzf /tmp/apr-1.4.6.tar.gz
mv /tmp/httpd-2.4.3/srclib/apr-1.4.6 /tmp/httpd-2.4.3/srclib/apr

tar -C /tmp/httpd-2.4.3/srclib -xzf /tmp/apr-util-1.5.1.tar.gz
mv /tmp/httpd-2.4.3/srclib/apr-util-1.5.1 /tmp/httpd-2.4.3/srclib/apr-util

tar -C /tmp -xzf /tmp/php-5.4.11.tar.gz
tar -C /tmp -xzf /tmp/memcached-2.1.0.tgz
tar -C /tmp -xzf /tmp/zlib-1.2.7.tar.gz

tar -C /tmp -xzf /tmp/imap-2007f.tar.gz
cd /tmp/imap-2007f
${MAKE} slx SSLINCLUDE="$DIR_PATH/include" EXTRACFLAGS="-fPIC" IP6=4 EXTRALDFLAGS="-L$DIR_PATH/lib -lssl -lcrypto"

cd /tmp/zlib-1.2.7
./configure --prefix=$DIR_PATH --64
${MAKE} && ${MAKE} install

cd /tmp/pcre-8.32
./configure --prefix=$DIR_PATH --enable-jit --enable-utf8
${MAKE} && ${MAKE} install

cd /tmp/httpd-2.4.3
./configure --prefix=/app/apache \
            --enable-rewrite \
            --enable-so \
            --enable-deflate \
            --enable-expires \
            --enable-headers \
            --enable-proxy-fcgi \
            --with-mpm=event \
            --with-included-apr \
            --with-pcre=$DIR_PATH
${MAKE} && ${MAKE} install

cd /tmp
git clone git://github.com/ByteInternet/libapache-mod-fastcgi.git
cd /tmp/libapache-mod-fastcgi/
patch -p1 < debian/patches/byte-compile-against-apache24.diff
sed -e "s%/usr/local/apache2%/app/apache%" Makefile.AP2 > Makefile
${MAKE} && ${MAKE} install

cd /tmp/php-5.4.11
./configure --prefix=/app/php \
            --with-pgsql \
            --with-pdo-pgsql \
            --with-mysql=mysqlnd \
            --with-pdo-mysql=mysqlnd \
            --with-iconv \
            --with-gd \
            --with-curl=/usr/lib \
            --with-config-file-path=/app/php \
            --enable-soap=shared \
            --with-openssl \
            --enable-mbstring \
            --with-mhash \
            --enable-mysqlnd \
            --with-pear \
            --with-mysqli=mysqlnd \
            --with-jpeg-dir \
            --with-png-dir \
            --with-mcrypt=$DIR_PATH \
            -enable-static \
            --enable-fpm \
            --with-pcre-dir=$DIR_PATH \
            --disable-cgi \
            --enable-zip \
            --with-imap=/tmp/imap-2007f \
            --with-imap-ssl
${MAKE}
${MAKE} install

/app/php/bin/pear config-set php_dir /app/php
echo " " | /app/php/bin/pecl install memcache
echo " " | /app/php/bin/pecl install apc-3.1.13
/app/php/bin/pecl install igbinary

cd /tmp/libmemcached-1.0.16
./configure --prefix=$DIR_PATH
# the configure script detects sasl, but is still foobar'ed
# sed -i 's/LIBMEMCACHED_WITH_SASL_SUPPORT 0/LIBMEMCACHED_WITH_SASL_SUPPORT 1/' Makefile
${MAKE} && ${MAKE} install

cd /tmp/memcached-2.1.0
/app/php/bin/phpize
./configure --with-libmemcached-dir=$DIR_PATH \
  --prefix=/app/php \
  --enable-memcached-igbinary \
  --enable-memcached-json \
  --with-php-config=/app/php/bin/php-config \
  --enable-static
${MAKE} && ${MAKE} install

# cd /tmp/zip-1.10.2
# /app/php/bin/phpize
# ./configure --prefix=/app/php --with-php-config=/app/php/bin/php-config --enable-static
# ${MAKE} && ${MAKE} install

echo '2.4.3' > /app/apache/VERSION
echo '5.4.11' > /app/php/VERSION
mkdir /tmp/build
mkdir /tmp/build/local
mkdir /tmp/build/local/lib
mkdir /tmp/build/local/lib/sasl2
cp -a /app/apache /tmp/build/
cp -a /app/php /tmp/build/
cp -aL $DIR_PATH/lib/libmcrypt.so.4 /tmp/build/local/lib/
cp -aL $DIR_PATH/lib/libmemcached.so.11 /tmp/build/local/lib/
cp -aL $DIR_PATH/lib/libpcre.so.1 /tmp/build/local/lib/

rm -rf /tmp/build/apache/manual