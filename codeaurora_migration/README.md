> Copyright 2023 NXP

#        How to Build Automotive Linux BSPs that were initially published on CodeAurora Forum (CAF)

## Introduction

Automotive Linux BSP (ALB) has been published on CodeAurora Forum (CAF) until BSP 34.0.
Starting with BSP 34.0.1, the Automotive Linux BSP releases are published on GitHub.
All releases published on CAF have been migrated to GitHub (without changing the Yocto files pointing to CAF links).
In order to be able to build Auto Linux BSPs initially published on CAF, a Bash script has been implemented that is able to update the repo manifests and Yocto files, by adapting the CAF git repository links to corresponding NXP GitHub repository links. By using this script, Yocto builds can be performed without the need to pull sources from CAF.

## Script Usage

There are two operating modes:

- ### Fully Automated Mode (recommended)
	In this mode, the user starts from scratch and the script will handle everything: cloning all Yocto layers from upstream and adjusting source URLs to NXP GitHub

	#### How to use

	```shell
	$ ./migrate.sh --full --work_path ./testfolder --release_branch release/bsp32.0
	```
	Inside the given work path (e.g. `./testfolder`) it will create the directory `auto-bsp`, and inside this directory it will start performing `repo init` and `repo sync` with adjusted URLs.
	After the script has finished, you can go inside the project (e.g. `./testfolder/auto-bsp`) and perform the documented steps for the Yocto build:

	- Initialize Yocto build envionment for the chosen machine and open the `bitbake` shell:
	```shell
	$ source nxp-setup-alb.sh -m <target_machine>
	```

	- Start a build
	```shell
	$ bitbake <target_image>
	```

	<a name="how-to-customize-the-script"></a>
	#### Customize the script

	- Use a custom manifest: use command line option `-m | --manifest`.

		:bulb: *Examples*

		- Fetching `meta-adas` requires using manifest `adas.xml`:

		```shell
		$ ./migrate.sh --full --work_path ./bsp_23.1_adas
		               --release_branch release/s32v_bsp23.1 -m "adas.xml"
		```

		- Fetching `meta-vnp` requires using manifest `vnp.xml`:
		```shell
		$ ./migrate.sh --full --work_path ./bsp_22.0_vnp
		               --release_branch release/bsp22.0 -m "vnp.xml"
		```

	- Use a custom name for the inner subdirectory `auto-bsp`: the environment variable `PROJECT_DIRNAME` can be used for a custom subdirectory name.
	```shell
	$ PROJECT_DIRNAME="release" ./migrate.sh --full --work_path <path>
	                                         --release_branch <branch>
	```

- ### Postsync Mode (experimental)
	In this mode, the hypothesis is that the user already has all the repos cloned, and encountered the issue a while after they performed `$ repo sync`.

	> **Warning**
	> 
	> ALL LOCAL REPO CHANGES SHOULD BE SAVED BEFORE STARTING IN THIS MODE
	> (e.g. via `git add` + `git commit` or other desired methods)
	
	#### How to use

	```shell
	$ ./migrate.sh --postsync --work_path ./testfolder
	```
	:bulb: *Attention*

	`work_path` expects a directory that contains by default the `auto-bsp` subdirectory inside. For example, if `auto-bsp` is inside `testfolder`, we should launch the script from outside `testfolder` with the path relative to it. Also, if your subdirectory `auto-bsp` directory is named otherwise, you should run the script `migrate.sh` with variable PROJECT_DIRNAME overridden (see above section [How to customize the script](#how-to-customize-the-script)).
	After running in postsync mode, you can continue using the BSP normally by opening a bitbake shell and launching a build, as described in the previous sections.

> **Note**
> 
> The help section of the script can be accessed via:
> ```shell
> $ ./migrate.sh --help
> ```

## Workarounds

There are some cases when additional manual steps have to be performed after running the script `migrate.sh` and before running `bitbake` commands. These manual steps are required due to some issues in some of the layers used by the Auto Linux BSP.

- Building images (via `bitbake`) for QorIQ machines in some BSPs throw error:
	```shell
	ERROR: No recipes in default available for:
	<recipe-full-path>.bbappend
	```
	This means that some .bbappend files were left in some layers after their base recipes have been removed from the product. This usually happens when the recipe and .bbappend are in different layers, and they remain out of sync after being updated independently by their corresponding maintainers. Workaround in this case is to add to `conf/local.conf`:
	```shell
	BB_DANGLINGAPPENDS_WARNONLY = "1"
	```
- Building images from layer `meta-vnp`:
	There are issues in some recipes (with SRC_URI path or with installation file list) and there are two patches, which need to be applied manually in this layer's root directory: `0001-meta-vnp-fix-azure-recipes.patch` and `0001-meta-vnp-fix-cmm-recipe-install.patch` (provided in the same location with the script `migrate.sh`).
	Copy the two patches inside `meta-vnp` directory, open a shell in it, then run commands:
	```shell
	$ git am 0001-meta-vnp-fix-azure-recipes.patch
	$ git am 0001-meta-vnp-fix-cmm-recipe-install.patch
	```
	Then run `nxp-setup-alb.sh` and/or `bitbake` commands as usual.

- Building images from `meta-adas`:
	Running `migrate.sh` with manifest `adas.xml` normally does not require any workaround. However, there are other SDKs that download the layer `meta-adas`, and which are not handled by the migration script. In this case, one can manually apply the patch `0001-sm-drv-Update-SRC_URI-to-github.patch` (provided in the same location with the script `migrate.sh`) to fix the fetch for the recipes in that layer.

> **Note**
> 
> If `git am <patch>` fails, the alternative is to use command `patch`:
> ```shell
> $ patch --backup-if-mismatch -F 10 -u -p 1 -i <patch>
> ```

## Known Limitations

Currently, the script creates and uses an intermediate subdirectory, which by default is named `auto-bsp`.
The user can change this default name as mentioned in section [How to customize the script](#how-to-customize-the-script).
