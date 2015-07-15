#! /bin/bash
#==========================================================================
#	File:		build-product.sh
#	Author:		Hardik Patel
#	Date:		07/14/2015
#	Version:	0.1
#	Usage:		This shell script build the android and create images
#			for specific product given as input.
#	copyright:
#===========================================================================

#Color code for echo stements
if tty -s; then
  R='\e[0;31m'
  B='\e[0;34m'
  G='\e[0;32m'
  NC='\e[0m' # No Color
else
  R=''
  B=''
  G=''
  NC=''
fi

# Changeable variables -- STARTS HERE

# Product is
PRODUCT=$1
TARGET_PRODUCT=
# Build options
BUILD_OPTIONS=$2

# Android sourcecode base folder
ANDROID_SRC=$(pwd)
echo -e "${B}Android source path is:${ANDROID_SRC}${NC}"

# Change this path to correct toolchain path for your need
TOOLCHAIN_PATH=${ANDROID_SRC}/prebuilts/gcc/linux-x86/arm/arm-eabi-4.7/bin
echo -e "${B}Toolchain path is:${TOOLCHAIN_PATH}${NC}"

# Export arm-eabi- toolchain path that required to build kernel and may be bootloader
export PATH=${TOOLCHAIN_PATH}:$PATH

# Bootloader source path
BOOTLOADER_DIR=
echo -e "${B}Bootlaoder is:${BOOTLOADER_DIR}${NC}"

# Kernel source path
KERNEL_DIR=${ANDROID_SRC}/kernel/samsung/exynos5422
echo -e "${B}Kernel is:${KERNEL_DIR}${NC}"
# Kernel Image type
KERNEL_IMG_TYPE=zImage-dtb

# Changeable variables -- ENDS  HERE

# Find total cpu available
TOTAL_CPU=$(grep --count processor /proc/cpuinfo)
echo -e "${B}Total available cpus:${TOTAL_CPU}${NC}"

# Find current user on system
CUR_USER=$(whoami)
echo -e "${B}Current user of system is:${CUR_USER}${NC}"

# Function that exit on errors
function ExitOnError()
{
	if [ $? != 0 ]
	then 
		echo -e "${R} $? ${NC}"
		exit $?
	fi
}

# Bootloader build
function BuildBootloader()
{
	echo -e "${R} NOT IMPLEMENTED YET${NC}"
	echo -e "${R} Instead USING PREBUILT from device tree ${NC}"
}

# Kernel build
function BuildKernel()
{
	echo -e "${B} Kernel build started here${NC}"
	START_TIME=`date +%s`
	
	pushd ${KERNEL_DIR}
	
	echo -e "${R} Cleaning previous build and configurations ${NC}"
	make ARCH=arm CROSS_COMPILE=arm-eabi- distclean
	
	echo -e "${B} Restarting clean build${NC}"
	echo -e "${R} Set defconfig for ${PRODUCT}${NC}"
	make ARCH=arm ${PRODUCT}"_defconfig"
	ExitOnError
	
	echo -e "${B} make -j${TOTAL_CPU} ARCH=arm CROSS_COMPILE=arm-eabi- ${KERNEL_IMG_TYPE} ${NC}"
	make -j${TOTAL_CPU} ARCH=arm CROSS_COMPILE=arm-eabi- ${KERNEL_IMG_TYPE}
	
	echo -e "${B} Building kernel modules here ${NC}"
	make ARCH=arm CROSS_COMPILE=arm-eabi- modules
	make ARCH=arm CROSS_COMPILE=arm-eabi- -C ${PWD} M=${ANDROID_SRC}/hardware/wifi/realtek/drivers/8192cu/rtl8xxx_CU
	make -C ../../../hardware/backports ARCH=arm CROSS_COMPILE=arm-eabi- KLIB_BUILD=${PWD} defconfig-odroidxu3
	ExitOnError
	BUILD_END_TIME=`date +%s`
	
	let "TOTAL_BUILD_TIME=${START_TIME}-${BUILD_END_TIME}"
	echo -e "${G} Kernel build sucessful - total time spent ${TOTAL_BUILD_TIME} seconds ${NC}"
	
	popd
}

# Full Android
function BuildAndroid()
{
	echo -e "${B} Android platform build started here${NC}"
	START_TIME=`date +%s`
	
	echo -e "${B}source build/envsetup.sh${NC}"
        source build/envsetup.sh
        
	echo -e "${B}lunch ${PRODUCT}-eng${NC}"
        lunch ${PRODUCT}-eng
	
	#echo -e "${R}DOING MAKE CLEAN FOR ANDROID. REMOVE ME AFTER TEST${NC}"
	#make -j${TOTAL_CPU} clean
        
	echo -e "${B}make -j${TOTAL_CPU}${NC}"
        make -j${TOTAL_CPU} TARGET_PRODUCT=${PRODUCT}
	ExitOnError

	BUILD_END_TIME=`date +%s`
	
	let "TOTAL_BUILD_TIME=${START_TIME}-${BUILD_END_TIME}"
	echo -e "${G} Android platfrom build sucessful - total time spent ${TOTAL_BUILD_TIME} seconds ${NC}"	
}

# Create android rootfs
function CreateAndroidFs()
{
	echo -e "${B} Android rootfs tarball here${NC}"
	START_TIME=`date +%s`
	
	cd ${ANDROID_SRC}/out/target/product/${PRODUCT}/
	
	if [ -d "android_rootfs" ]; then
		echo -e "${R} Removing previous android_rootfs dir${NC}"
		rm -rf android_rootfs
	fi

	echo -e "${B} Creating android_rootfs dir${NC}"
	mkdir -p android_rootfs

	echo -e "${B} cp -dprf root/* android_rootfs/.${NC}"
	cp -dprf root/* android_rootfs/.

	sleep 3

	echo -e "${B} cp -dprf system/* android_rootfs/system/. ${NC}"
	cp -dprf system/* android_rootfs/system/.

	sleep 5
	
	echo -e "${B} cp -dprf data/* android_rootfs/data/. ${NC}"
	cp -dprf data/* android_rootfs/data/.

	sleep 2

	echo -e "${B} mkdir -p android_rootfs/system/lib/modules/backports ${NC}"
	mkdir -p android_rootfs/system/lib/modules/backports

	echo -e "${B} Copying all kernel modules to android_rootfs/system/lib/modules/ ${NC}"
	find ${KERNEL_DIR} -name *.ko | xargs -i cp {} android_rootfs/system/lib/modules/
	
	echo -e "${B} Copying all moduers under hardware to android_rootfs/system/lib/modules/ ${NC}"
	find ${ANDROID_SRC}/hardware/wifi/realtek/drivers/8192cu/rtl8xxx_CU -name *.ko | xargs -i cp {} android_rootfs/system/lib/modules
	echo -e "${B} Copying all modules from hardware/backport to android_rootfs/system/lib/modules/backports ${NC}"
	find ${ANDROID_SRC}/hardware/backports -name *.ko | xargs -i cp {} android_rootfs/system/lib/modules/backports

	sleep 2

	echo -e "${B} Executing build/tools/mktarball.sh  ${NC}"
	../../../../build/tools/mktarball.sh ../../../host/linux-x86/bin/fs_get_stats android_rootfs . rootfs rootfs.tar.bz2

	BUILD_END_TIME=`date +%s`

        let "TOTAL_BUILD_TIME=${START_TIME}-${BUILD_END_TIME}"
        echo -e "${G} Android rootfs tarball sucessful - total time spent ${TOTAL_BUILD_TIME} seconds ${NC}"
	cd -
}

case "${BUILD_OPTIONS}" in 
	bootloader)
		BuildBootloader;;
	kernel)
		BuildKernel;;
	android)
		BuildAndroid;;
	rootfs)
		CreateAndroidFs;;
	all)
		BuildBootloader
		BuildKernel
		BuildAndroid
		CreateAndroidFs
		;;
	*)
		BuildBootloader
                BuildKernel
                BuildAndroid
                CreateAndroidFs
                ;;
esac

echo -e "${G} Ok. sucess !!!!${NC}"

exit 0
