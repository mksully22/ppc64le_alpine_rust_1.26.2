#
# Usage:
# $ sudo docker run --name alpine_rustbuild  -it -v /rust-alpine-ppc64le:/mnt alpine:3.7
# $ sudo docker exec -it alpine_rustbuild  /bin/bash
# $ sudo docker ps
# In container:
#   edit /etc/apk/repositories to point to edge
#   apk update
#   apk upgrade
#   Copy build_rust26.sh and all patches to /root/test262/.
# # Invoke /root/test262/build_rust.sh
# TODOS:

set -ex

user=rustbuild262
sourcedir=/root/test262

as_user() {
    su -c 'bash -c "'"${@}"'"' $user
}

mk_user() {
    adduser -D $user
}

fetch_rust() {
    cd /home/$user; rm -rf /home/$user/test262; cp -r $sourcedir /home/$user/.; chown -R rustbuild262:rustbuild262 /home/$user/test262;
    as_user "
    rm -rf ~/rust262; tar -xzf ~/test262/rustc-1.26.2-src.tar.gz;
    mv rustc-1.26.2-src rust262
    rm -rf ~/.cargo
"
}

install_deps() {
        apk add alpine-sdk openssl openssl-dev gcc llvm-libunwind-dev cmake file libffi-dev llvm5-dev llvm5-test-utils python2 tar zlib-dev gcc llvm-libunwind-dev musl-dev util-linux bash
        apk add --allow-untrusted $sourcedir/rust-stdlib-1.26.0-r2.apk $sourcedir/rust-1.26.0-r2.apk $sourcedir/cargo-1.26.0-r2.apk
}

apply_patches() {
    # TODO upstream these patches to rust-lang/llvm
    as_user "
cd ~/rust262
rm -Rf src/llvm/
patch -p1 -b < ~/test262/minimize-rpath.patch
patch -p1 -b < ~/test262/static-pie.patch
patch -p1 -b < ~/test262/need-rpath.patch
patch -p1 -b < ~/test262/musl-fix-static-linking.patch
patch -p1 -b < ~/test262/musl-fix-linux_musl_base.patch
patch -p1 -b < ~/test262/llvm-with-ffi.patch
patch -p1 -b < ~/test262/alpine-target.patch
patch -p1 -b < ~/test262/alpine-move-py-scripts-to-share.patch
patch -p1 -b < ~/test262/alpine-change-rpath-to-rustlib.patch
patch -p1 -b < ~/test262/s7_ppc64le_target.patch
patch -p1 -b < ~/test262/fix-configure-tools.patch
patch -p1 -b < ~/test262/bootstrap-tool-respect-tool-config.patch
patch -p1 -b < ~/test262/ensure-stage0-libs-have-unique-metadata.patch
patch -p1 -b < ~/test262/install-template-shebang.patch
patch -p1 -b < ~/test262/cargo-libressl27x.patch
patch -p1 -b < ~/test262/cargo-tests-fix-build-auth-http_auth_offered.patch
patch -p1 -b < ~/test262/cargo-tests-ignore-resolving_minimum_version_with_transitive_deps.patch
cd ~/rust262/src/liblibc
patch -p1 -b < ~/test262/libc_1.26.2_modrs.patch       
patch -p1 -b < ~/test262/libc_1.26.2_b64x86_64.patch   
patch -p1 -b < ~/test262/libc_1.26.2_b64powerpc64.patch
patch -p1 -b < ~/test262/libc_1.26.2_b64modrs.patch    
patch -p1 -b < ~/test262/libc_1.26.2_b32modrs.patch    
cd ~/rust262/src/vendor/libc
patch -p1 -b < ~/test262/libc_1.26.2_modrs.patch       
patch -p1 -b < ~/test262/libc_1.26.2_b64x86_64.patch   
patch -p1 -b < ~/test262/libc_1.26.2_b64powerpc64.patch
patch -p1 -b < ~/test262/libc_1.26.2_b64modrs.patch    
patch -p1 -b < ~/test262/libc_1.26.2_b32modrs.patch    
patch -p1 -b < ~/test262/libc_1.26.2_vendor_checksum.patch
"
}


mk_rustc() {
    dir=$(pwd)
    as_user "
cd ~/rust262
./configure \
                --build="powerpc64le-alpine-linux-musl" \
                --host="powerpc64le-alpine-linux-musl" \
                --target="powerpc64le-alpine-linux-musl" \
                --prefix="/usr" \
                --release-channel="stable" \
                --enable-local-rust \
                --local-rust-root="/usr" \
                --llvm-root="/usr/lib/llvm5" \
                --musl-root="/usr" \
                --disable-docs \
                --enable-extended \
		--enable-llvm-link-shared \
		--enable-option-checking \
		--enable-locked-deps \
		--enable-vendor \
                --disable-jemalloc

                unset MAKEFLAGS
                date > build_dist.log
                RUSTFLAGS='$RUSTFLAGS -A warnings'  RUST_BACKTRACE=1 RUSTC_CRT_STATIC="false" taskset 0x100 ./x.py dist -j1 -v >> build_dist.log 2>&1
                date >> build_dist.log
"
}


main() {
   mk_user
   install_deps
   fetch_rust
   apply_patches
   mk_rustc
}

main
