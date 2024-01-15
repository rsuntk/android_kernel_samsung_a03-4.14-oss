#! /bin/bash
# Rissu Project (C) 2024

# SPRD/Unisoc Required Proprietary library unpacker
# 
# This script is for unpack compressed libs.
# The reason why this is compressed is because when you try to push it to GitHub,
# libart.so exceeds GitHub maximum uploaded file. (GitHub: 100MB max; libart.so: >100MB)
# Anyway i decided to compressed it more to decrease the size.

cd ..
# SET VARIABLE

KERNEL_TREE="$(pwd)";
X="tar.xz"

# SPLIT IT.
SPLIT1="SPLIT1.$X"
SPLIT2="SPLIT2.$X"
SPLIT3="SPLIT3.$X"
SPLIT4="SPLIT4.$X"
SPLIT5="SPLIT5.$X"
SPLIT6="SPLIT6.$X"
SPLIT7="SPLIT7.$X"
SPLIT8="SPLIT8.$X"

# Alright, functions start here, edit if necessary.
check_dir() {
	cd $KERNEL_TREE/tools/lib64;
	if [ ! -f $SPLIT1 ] || [ ! -f $SPLIT2 ] || [ ! -f $SPLIT3 ] || [ ! -f $SPLIT4 ] || [ ! -f $SPLIT5 ] || [ ! -f $SPLIT6 ] || [ ! -f $SPLIT7 ] || [ ! -f $SPLIT8 ]; then
		printf "[LIB_UNPACKER] Compressed file not found!, Aborting ... \n";
		cd ../..;
		exit;
	else
		printf "[LIB_UNPACKER] All files ok, deflating ...\n";
		unpack;
	fi
};

unpack() {
	tar -xvf $SPLIT1;
	tar -xvf $SPLIT2;
	tar -xvf $SPLIT3;
	tar -xvf $SPLIT4;
	tar -xvf $SPLIT5;
	tar -xvf $SPLIT6;
	tar -xvf $SPLIT7;
	tar -xvf $SPLIT8;
	cd ../..;
};

main() {
	check_dir;
	printf "[LIB_UNPACKER] All files are extracted to $KERNEL_TREE/tools/lib64.\n";
};

# execute main function
main;
