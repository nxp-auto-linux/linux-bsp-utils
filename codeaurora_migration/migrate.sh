#!/bin/bash
##
# Copyright 2023 NXP
#
# SPDX-License-Identifier: BSD-3-Clause
##

####### Declarations #######

SCRIPT_VERSION="0.2"

# determine the operating mode of the script
FULL_MODE="0"
SYNC_MODE="0"
POSTSYNC_MODE="0"
HELP_MODE="0"
VERSION_MODE="0"
#DEBUG_MODE="0"
DEBUG_MODE="${DEBUG_MODE:=0}"
MANIFEST="${MANIFEST:=default.xml}"

# to be filled by commandline arguments
WORK_PATH=""
RELEASE_BRANCH=""

REPO_CMD="$(which repo)"
PROJECT_URL="https://github.com/nxp-auto-linux/auto_yocto_bsp"
PROJECT_DIRNAME=${PROJECT_DIRNAME:=auto-bsp}

# presync translations
CAF_BSP="https://source.codeaurora.org/external/autobsps32"
CAF_QORIQ="https://source.codeaurora.org/external/qoriq"
CAF_QORIQ_YOCTO_SDK="https://source.codeaurora.org/external/qoriq/qoriq-yocto-sdk"
CAF_META_QORIQ="https://source.codeaurora.org/external/qoriq/qoriq-components/meta-qoriq"
CAF_META_ALB="https://source.codeaurora.org/external/autobsps32/meta-alb"

declare -A PRESYNC_DICT=(
	["$CAF_BSP"]="https://github.com/nxp-auto-linux" \
	["$CAF_QORIQ"]="https://github.com/nxp-qoriq" \
	["$CAF_QORIQ_YOCTO_SDK"]="https://github.com/nxp-qoriq-yocto-sdk" \
	["$CAF_META_QORIQ"]="https://github.com/nxp-qoriq/meta-qoriq" \
	["$CAF_META_ALB"]="https://github.com/nxp-auto-linux/meta-alb" \
)

# The patterns need to be substituted in a certain order for the 
# translations to be correct. Additionally, dictionaries do not keep 
# the order of the insert operations when looping through entries. 
# Thus, we require an array to keep the keys in order, and this array
# will be looped through in order to get the keys in the correct sequence
declare -a PRESYNC_KEYS_ORDER=(
	"$CAF_BSP"
	"$CAF_QORIQ_YOCTO_SDK"
	"$CAF_META_QORIQ"
	"$CAF_QORIQ"
	"$CAF_META_ALB"
)

# postsync translations
GIT_CAF_QORIQ="git://source.codeaurora.org/external/qoriq/qoriq-components/"
GITSM_CAF_QORIQ="gitsm://source.codeaurora.org/external/qoriq/qoriq-components/"
GIT_CAF_QORIQ_SDK="git://source.codeaurora.org/external/qoriq/qoriq-yocto-sdk/"
GIT_CAF_IMX="git://source.codeaurora.org/external/imx/"
GIT_CAF_SJA="git://source.codeaurora.org/external/autoivnsw/sja1110_linux"
GIT_CAF_IPC="git://source.codeaurora.org/external/autobsps32/ipcf/ipc-shm"
GIT_CAF_PFE="git://source.codeaurora.org/external/autobsps32/extra/pfeng"
GIT_CAF_SMDRV="git://source.codeaurora.org/external/autobsps32/extra/sm_drv"
GIT_CAF_BSP="git://source.codeaurora.org/external/autobsps32"
GIT_CAF_GCC63="https://source.codeaurora.org/external/s32ds/compiler/gnu_nxp/plain/"
URL_LXC='http://linuxcontainers.org/downloads/${BPN}-${PV}.tar.gz'
URL_LXC_NEW='http://linuxcontainers.org/downloads/${BPN}/${BPN}-${PV}.tar.gz'

declare -A POSTSYNC_DICT=(
	["$GIT_CAF_QORIQ"]="git://github.com/nxp-qoriq/" \
	["$GITSM_CAF_QORIQ"]="gitsm://github.com/nxp-qoriq/" \
	["$GIT_CAF_QORIQ_SDK"]="git://github.com/nxp-qoriq-yocto-sdk/" \
	["$GIT_CAF_IMX"]="git://github.com/nxp-imx/" \
	["$GIT_CAF_SJA"]="git://github.com/nxp-archive/autoivnsw_sja1110_linux" \
	["$GIT_CAF_IPC"]="git://github.com/nxp-auto-linux/ipc-shm" \
	["$GIT_CAF_PFE"]="git://github.com/nxp-auto-linux/pfeng" \
	["$GIT_CAF_SMDRV"]="git://github.com/nxp-archive/autobsps32_sm_drv" \
	["$GIT_CAF_BSP"]="git://github.com/nxp-auto-linux" \
	["$GIT_CAF_GCC63"]="https://raw.githubusercontent.com/nxp-auto-tools/gnu_nxp/master/" \
)

declare -a POSTSYNC_KEYS_ORDER=(
	"$GIT_CAF_QORIQ"
	"$GITSM_CAF_QORIQ"
	"$GIT_CAF_QORIQ_SDK"
	"$GIT_CAF_IMX"
	"$GIT_CAF_SJA"
	"$GIT_CAF_IPC"
	"$GIT_CAF_PFE"
	"$GIT_CAF_SMDRV"
	"$GIT_CAF_BSP"
	"$GIT_CAF_GCC63"
)

####### Migration steps #######


# check if the upstream branch actually exists
check_release_branch ()
{
    # check if the desired branch actually exists
    git ls-remote $PROJECT_URL | grep "$RELEASE_BRANCH" > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "ERROR! Release branch $RELEASE_BRANCH does not exist on remote $PROJECT_URL!"
        help_func
        exit 1
    fi
}

# check if the repo command exists on the system
check_repo_cmd ()
{
	if [ -z "$REPO_CMD" ]; then
		echo "No 'repo' command found on the system!
		Please add its installation path in the environment variable PATH!"
		exit 1
	fi
}

# Step 1: Prepare working directory (if it does not exist already)
prepare_workdir ()
{
    echo "[INFO] Preparing working directory $WORK_PATH/$PROJECT_DIRNAME ..."
    mkdir -p "$WORK_PATH/$PROJECT_DIRNAME"
    echo "[INFO] Finished preparing working directory!"
}

# Step 2: Perform "repo init"
repo_init ()
{
    echo "[INFO] Performing repo init..."
	cd "$WORK_PATH/$PROJECT_DIRNAME" || exit 1
    echo "[INFO] Using manifest \" "$MANIFEST" \"..."
    $REPO_CMD init -u $PROJECT_URL -b $RELEASE_BRANCH -m $MANIFEST
	cd - || exit 1
    echo "[INFO] Finished repo init!"
}

# Step 3: change URLs from the manifest files
migrate_presync ()
{
	echo "[INFO] Starting presync migration!"

	local filelist=($(find "$WORK_PATH/$PROJECT_DIRNAME" -type f -name "*.xml" ))

	for file in "${filelist[@]}"
	do
		if [ "$(basename "$file")" = "default.xml" ]; then
			sed -i "s#qoriq-components/meta-qoriq#meta-qoriq#g" "$file"
		fi
		
		for key in "${PRESYNC_KEYS_ORDER[@]}"
		do
			sed -i "s#${key}#${PRESYNC_DICT[${key}]}#g" "$file"
		done
	done
	
	echo "[INFO] Done presync migration!"
}

# Step 4: perform "repo sync"
repo_sync ()
{
    echo "[INFO] Performing repo sync..."
	cd "$WORK_PATH/$PROJECT_DIRNAME" || exit 1
    $REPO_CMD sync
	cd - || exit 1
    echo "[INFO] Finished repo sync!"
}

# Step 5: change the URLs from the Yocto recipes in the target meta-layers
migrate_postsync ()
{
	echo "[INFO] Starting postsync migration!"

	local filelist=($(find "$WORK_PATH/$PROJECT_DIRNAME" -type f \( -name "*.bb*" -or -name "*.inc" \) \( -path "*/meta-alb/*" -or -path "*/meta-qoriq/*" -or -path "*/meta-freescale/*" -or -path "*/meta-vnp/*" -or -path "*/meta-qoriq-demos/*" -or -path "*/meta-adas/*" \) ))
	local gcc63="$WORK_PATH/$PROJECT_DIRNAME/sources/meta-alb/recipes-devtools/gcc/gcc-linaro-6.3-fsl.inc"

	local lxc_path="dynamic-layers/virtualization-layer/recipes-containers/lxc"
	local lxc_files=($(find "$WORK_PATH/$PROJECT_DIRNAME/sources/meta-alb" -type f \( -name "*.bbappend*" \) \( -path "*/$lxc_path/*" \) ))
	local lxc_url=""

	for file in "${filelist[@]}"
	do
		for key in "${POSTSYNC_KEYS_ORDER[@]}"
		do
			sed -i "s#${key}#${POSTSYNC_DICT[${key}]}#g" "$file"
		done
	done

	if [ -f "$gcc63" ]
	then
		echo -e '\nBB_STRICT_CHECKSUM = "0"\n' >> "$gcc63"
	fi

	# Patch only the LXC recipe bbappend
	if [ -n "${lxc_files[0]}" ]
	then
		lxc_str="$(grep "$URL_LXC" ${lxc_files[0]})"
	else
		lxc_files=("$WORK_PATH/$PROJECT_DIRNAME/sources/meta-alb/$lxc_path/lxc_%.bbappend")
	fi

	if [ -z "$lxc_str" ]
	then
		echo 'SRC_URI_remove = "'$URL_LXC'"' >> "${lxc_files[0]}"
		echo 'SRC_URI += "'$URL_LXC_NEW'"' >> "${lxc_files[0]}"
	fi

	echo "[INFO] Done postsync migration!"
}

version_func ()
{
	echo "Script version: $SCRIPT_VERSION"
}

full_func ()
{
	# sanity checks
	check_repo_cmd
	check_release_branch

	prepare_workdir
	repo_init
	migrate_presync
	repo_sync
	migrate_postsync
}

sync_func ()
{
	# sanity checks
	check_repo_cmd

	migrate_presync
	repo_sync
	migrate_postsync
}

warning_func ()
{
	echo -n "
=====================================================================
WARNING: THIS SCRIPT WILL CHANGE MANIFEST AND YOCTO RECIPE FILES!
SINCE CODE AURORA HAS BEEN SHUT DOWN, THIS SCRIPT IS NEEDED IN ORDER
TO CHANGE THE CAF LINKS TO NXP/GITHUB CORRESPONDING LINKS.

IT IS STRONGLY RECOMMENDED THAT USERS PROPERLY SAVE ALL THEIR LOCAL
CHANGES IN REPOSITORES CLONED BY THE 'repo' TOOL BEFORE ATTEMPTING
TO RUN THIS SCRIPT (VIA 'git commit' OR OTHER MEANS)!!!

PROCEEDING FURTHER MEANS ACKNOWLEDGING THE RISKS INVOLVED AND 
PROPERLY SAVING ALL YOUR CHANGES!
=====================================================================
	"
	read -p "Proceed further?(y/n) " resp
	
	if [[ $resp = "y" ]]; then
		return
	elif [[ $resp = "n" ]]; then
		exit 0
	else
		echo "[ERROR] Invalid response!"
		exit 1
	fi
}

# help in order to show how to use this script
help_func ()
{
	echo "	
	Usage:

		$0 OPERATING_MODE [<ARGUMENTS>]

	OPERATING_MODE can be one of the following:

	-> -h | --help
			
			shows this help

			Example usage:

				$0 -h
			or
				$0 --help

	============================================================================

	-> -v | --version
			
			shows the version of $0
			
			Example usage:

				$0 -v
			or
				$0 --version

	============================================================================

	-> -f | --full	
			
			performs fully-automated handling from scratch
			(clone $PROJECT_URL,
			'repo init' and 'repo sync' with URLs adjusted
			to GitHub)

			Mandatory arguments:

			-p | --work_path	<desired path for the
						$PROJECT_DIRNAME directory>

			-b | --release_branch	<desired upstream release branch>

			Optional arguments:

			-m | --manifest		<desired manifest file>
				use a manifest file for the repo tool
				different from the default one (default.xml)

			Example usage:

				$0 -f -p ./my_folder -b release/bsp33.0 [-m adas.xml]
			or
				$0 --full --work_path ./my_folder
					--release_branch release/bsp33.0
					[--manifest adas.xml]

	============================================================================

	-> -s | --sync	
			
			In this mode, we suppose that 'repo init' has been already 
			performed, but no 'repo sync' has been performed yet.

			Mandatory arguments:

			-p | --work_path	path for the existing 
						$PROJECT_DIRNAME directory
	
			Example usage:

				$0 -s -p ./path/to/$PROJECT_DIRNAME

			or

				$0 --sync --work_path ./path/to/$PROJECT_DIRNAME

	============================================================================

	-> -ps | --postsync	
			
			In this mode, we suppose that 'repo sync' has been already 
			performed before CAF shutdown.
			
			WARNING: 
			Here, we have to be careful to firstly save what we have worked on!
			The script will prompt you to save all your meta-layers repositories
			changes before continuing.

			Mandatory arguments:

			-p | --work_path	path for the existing 
						$PROJECT_DIRNAME directory

			Example usage:

				$0 -ps -p /path/to/$PROJECT_DIRNAME
			
			or

				$0 --postsync --work_path /path/to/$PROJECT_DIRNAME

	
	EXTRA / OPTIONAL features:

	-> running in debug mode
	
			Run in debug mode. Useful for feedback and bug reports.
			Can be used with ANY of the above operationg modes.

			Example usage:

				DEBUG_MODE=1 $0 -ps -p /path/to/$PROJECT_DIRNAME
			
			or
				DEBUG_MODE=1 $0 --postsync --workpath /path/to/$PROJECT_DIRNAME
	"
}



while [ ! -z "$1" ]; do
	case "$1" in
		-h | --help )
			HELP_MODE="1"
			break
			;;
		-v | --version )
			VERSION_MODE="1"
			break
			;;
		-f | --full )
			FULL_MODE="1"
			shift
			;;
		-s | --sync )
			SYNC_MODE="1"
			shift
			;;
		-ps | --postsync )
			POSTSYNC_MODE="1"
			shift
			;;
		-p | --work_path )
			WORK_PATH="$2"
			shift 2
			;;
		-b | --release_branch )
			RELEASE_BRANCH="$2"
			shift 2
			;;
		-m | --manifest )
			MANIFEST="$2"
			shift 2
			;;

		* )
			if [ -z "$1" ]; then
				break
			else
				echo "[ERROR] wrong argument: $1"
				help_func
				exit 1
			fi
			;;
	esac
done


# activate debug if flag has been provided
if [[ "$DEBUG_MODE" = "1" ]]; then
	set -x
fi

# check which operating mode was selected
if [[ "$HELP_MODE" = "1" ]]; then
    help_func
    exit 0
elif [[ "$VERSION_MODE" = "1" ]]; then
    version_func
    exit 0
elif [[ "$FULL_MODE" = "1" ]]; then
	if [ -z "$WORK_PATH" ]; then
		echo "[ERROR] No --work_path argument provided!"
		echo "Exiting..."
		exit 1
	fi
	if [ -z "$RELEASE_BRANCH" ]; then
		echo "[ERROR] No --release_branch argument provided!"
		echo "Exiting..."
		exit 1
	fi
	warning_func
    full_func
	exit 0
elif [[ "$SYNC_MODE" = "1" ]]; then
	warning_func
    sync_func
	exit 0
elif [[ "$POSTSYNC_MODE" = "1" ]]; then
	warning_func
    migrate_postsync
	exit 0
else
	help_func
	exit 0
fi

