#!/bin/bash
# prep release for upload to production container

set -e

# make ipxe directory to store ipxe disks
mkdir -p build/ipxe

# pull down upstream iPXE
git clone --depth 1 https://github.com/ipxe/ipxe.git ipxe_build

# copy iPXE config overrides into source tree
cp ipxe/local/* ipxe_build/src/config/local/

# copy certs into source tree
# cp script/*.crt ipxe_build/src/  --check later

# build iPXE disks
cd ipxe_build/src

# get current iPXE hash
IPXE_HASH=`git log -n 1 --pretty=format:"%H"`

# generate netboot.xyz iPXE disks
make bin/ipxe.dsk bin/ipxe.iso bin/ipxe.lkrn bin/ipxe.usb bin/ipxe.kpxe bin/undionly.kpxe \
EMBED=../../ipxe/disks/netboot.xyz 
# TRUST=ca-ipxe-org.crt,ca-netboot-xyz.crt -- check later if can be appended in above line.
mv bin/ipxe.dsk ../../build/ipxe/netboot.xyz.dsk
mv bin/ipxe.iso ../../build/ipxe/netboot.xyz.iso
mv bin/ipxe.lkrn ../../build/ipxe/netboot.xyz.lkrn
mv bin/ipxe.usb ../../build/ipxe/netboot.xyz.usb
mv bin/ipxe.kpxe ../../build/ipxe/netboot.xyz.kpxe
mv bin/undionly.kpxe ../../build/ipxe/netboot.xyz-undionly.kpxe

# generate EFI iPXE disks
cp config/local/general.h.efi config/local/general.h
make clean
make bin-x86_64-efi/ipxe.efi \
EMBED=../../ipxe/disks/netboot.xyz 
# TRUST=ca-ipxe-org.crt,ca-netboot-xyz.crt -- check later if can be appended in above line.
mkdir -p efi_tmp
dd if=/dev/zero of=efi_tmp/ipxe.img count=2880
mformat -i efi_tmp/ipxe.img -m 0xf8 -f 2880
mmd -i efi_tmp/ipxe.img ::efi ::efi/boot
mcopy -i efi_tmp/ipxe.img bin-x86_64-efi/ipxe.efi ::efi/boot/bootx64.efi
genisoimage -o ipxe.eiso -eltorito-alt-boot -e ipxe.img -no-emul-boot efi_tmp
mv bin-x86_64-efi/ipxe.efi ../../build/ipxe/netboot.xyz.efi
mv ipxe.eiso ../../build/ipxe/netboot.xyz-efi.iso

# return to root
cd ../..

# generate header for sha256-checksums file
cd build/
CURRENT_TIME=`date`
cat > netboot.xyz-sha256-checksums.txt <<EOF
# netboot.xyz bootloaders generated at $CURRENT_TIME
# iPXE Commit: https://github.com/ipxe/ipxe/commit/$IPXE_HASH
# Travis-CI Job: https://travis-ci.org/antonym/netboot.xyz/builds/$TRAVIS_BUILD_ID

EOF

# generate sha256sums for iPXE disks
cd ipxe/
for ipxe_disk in `ls .`
do
  sha256sum $ipxe_disk >> ../netboot.xyz-sha256-checksums.txt
done
cat ../netboot.xyz-sha256-checksums.txt
mv ../netboot.xyz-sha256-checksums.txt .
cd ../..

# generate signatures for netboot.xyz source files
# commenting below section 
#mkdir sigs
#for src_file in `ls src`
#do
#  openssl cms -sign -binary -noattr -in src/$src_file \
#  -signer script/codesign.crt -inkey script/codesign.key -certfile script/ca-netboot-xyz.crt -outform DER \
#  -out sigs/$src_file.sig
#  echo Generated signature for $src_file...
#done
#mv sigs src/
# commenting ends

# delete index.html so that we don't overwrite existing content type
rm src/index.html

# copy iPXE src code into build directory
cp -R src/* build/
