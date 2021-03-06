# build-yocto-genivi

build-yocto-genivi is a subproject of [easy-build](https://github.com/gmacario/easy-build) and has the objective of providing a simplified environment where to rebuild from sources the [GENIVI Yocto Baseline](http://projects.genivi.org/GENIVI_Baselines/meta-ivi/home), as well as running it on virtual targets such as QEMU, VirtualBox or VMware.

build-yocto-genivi relies on [Docker](http://www.docker.com/) and creates a clean, stand-alone development environment complete with all the tools needed to perform a full build of the target image.

## Getting the Docker image locally

Several options are possible here.

### Pulling image from index.docker.io

The most recent builds of the build-yocto-genivi project are published on [Docker Hub](https://hub.docker.com/):

    docker pull gmacario/build-yocto-genivi

### Creating the image using the build.sh script

Alternatively you may do a local rebuild of your Docker image following to the instructions inside the `Dockerfile`.
You may do so through the following command

    ./build.sh
    
**NOTE**: If the script appears to hang, please either delete or move the contents of the `shared/` subdirectory before launching the script.

### Creating the image from the Dockerfile

This is basically what the `build.sh` script does, but you may customize the Docker image or add other configuration options (please consult `man docker` for details)

    docker build -t my-build-yocto-genivi .
    
## Running the Docker image

Prerequisite: the Docker image is already available locally.

As before, several options are possible.

### Using the run.sh script (quick)

This command will execute faster in case the container has already run previously.

    ./run.sh

### Invoking Docker manually

This command will create and start a new container

    docker run -t -i -v <shareddir>:/home/build/shared gmacario/build-yocto-genivi

The `-v <shareddir>:/home/build/shared` options instructs Docker to have the `/home/build/shared` directory 
of the container mapped to a directory of the host filesystem. 
This may be used to prevent the Yocto build directory to fill in the partition where containers are created,
as well as for preserving the build directory after the container is destroyed.

## Using build-yocto-genivi

Adapted from [meta-ivi README.md](http://git.yoctoproject.org/cgit/cgit.cgi/meta-ivi/tree/README.md)

Prerequisite: the container is already running.

### Preparation

    # Make sure that /dev/shm is writable (TODO: why???)
    chmod a+w /dev/shm
    
    # Make sure that ~build/shared directory is owned by user "build"
    chown build.build ~build/shared
    
    # Switch to user 'build'
    su - build

### Initialize build environment

After logging in as user "build" execute the following commands:

    export GENIVI=~/genivi-baseline
    source $GENIVI/poky/oe-init-build-env ~/shared/my-genivi-build
    export TOPDIR=$PWD

### Building the GENIVI image

#### Configure the build

Review script `configure_build.sh` and make any modifications if needed, then invoke the script

    sh ~/configure_build.sh

For help about syntax of `conf/bblayers.conf` and `conf/local.conf` please refer to the
[Yocto Project Documentation](http://www.yoctoproject.org/docs/current/mega-manual/mega-manual.html).

#### Perform the build

    cd $TOPDIR
    bitbake -k intrepid-image

**NOTE**: This command may take a few hours to complete.

Sample output:

```
build@3c3fd562548b:~/shared/my-genivi-build$ bitbake -k intrepid-image
Loading cache: 100% |#############################################################################################################################| ETA:  00:00:00
Loaded 1884 entries from dependency cache.
NOTE: Resolving any missing task queue dependencies

Build Configuration:
BB_VERSION        = "1.24.0"
BUILD_SYS         = "x86_64-linux"
NATIVELSBSTRING   = "Ubuntu-14.04"
TARGET_SYS        = "i586-poky-linux"
MACHINE           = "qemux86"
DISTRO            = "poky-ivi-systemd"
DISTRO_VERSION    = "7.0.2"
TUNE_FEATURES     = "m32 i586"
TARGET_FPU        = ""
meta              
meta-yocto        
meta-yocto-bsp    = "(detachedfromdf87cb2):df87cb27efeaea1455f20692f9f1397c6fcab254"
meta-ivi          
meta-ivi-bsp      = "(detachedfrom7.0.2):54000a206e4df4d5a94db253d3cb8a9f79e4a0ae"
meta-oe           = "(detachedfrom9efaed9):9efaed99125b1c4324663d9a1b2d3319c74e7278"

NOTE: Preparing runqueue
NOTE: Executing SetScene Tasks
NOTE: Executing RunQueue Tasks
WARNING: QA Issue: coreutils rdepends on libacl, but it isn't a build dependency? [build-deps]
WARNING: QA Issue: ELF binary '/home/build/shared/my-genivi-build/tmp/work/i586-poky-linux/wayland-ivi-extension/1.2.0-r0/packages-split/wayland-ivi-extension/usr/lib/weston/ivi-controller.so' has relocations in .text [textrel]
WARNING: QA Issue: pulseaudio-module-console-kit rdepends on consolekit, but it isn't a build dependency? [build-deps]
NOTE: Tasks Summary: Attempted 3194 tasks of which 2319 didn't need to be rerun and all succeeded.

Summary: There were 3 WARNING messages shown.
build@3c3fd562548b:~/shared/my-genivi-build$
```

As a result of the build the following files will be created:

```
build@3c3fd562548b:~/shared/my-genivi-build$ ls -la tmp/deploy/images/qemux86/
total 317376
drwxrwxr-x 2 build build      4096 Nov 23 22:50 .
drwxrwxr-x 3 build build      4096 Nov 23 20:45 ..
-rw-r--r-- 2 build build       294 Nov 23 22:47 README_-_DO_NOT_DELETE_FILES_IN_THIS_DIRECTORY.txt
lrwxrwxrwx 1 build build        73 Nov 23 20:45 bzImage -> bzImage--3.14.19+git0+fb6271a942_e19a1b40de-r0-qemux86-20141123195331.bin
-rw-r--r-- 2 build build   6636528 Nov 23 20:45 bzImage--3.14.19+git0+fb6271a942_e19a1b40de-r0-qemux86-20141123195331.bin
lrwxrwxrwx 1 build build        73 Nov 23 20:45 bzImage-qemux86.bin -> bzImage--3.14.19+git0+fb6271a942_e19a1b40de-r0-qemux86-20141123195331.bin
-rw-r--r-- 1 build build 281065472 Nov 23 22:50 intrepid-image-qemux86-20141123222452.rootfs.ext3
-rw-r--r-- 1 build build     33525 Nov 23 22:50 intrepid-image-qemux86-20141123222452.rootfs.manifest
-rw-r--r-- 1 build build  55285512 Nov 23 22:50 intrepid-image-qemux86-20141123222452.rootfs.tar.bz2
lrwxrwxrwx 1 build build        49 Nov 23 22:50 intrepid-image-qemux86.ext3 -> intrepid-image-qemux86-20141123222452.rootfs.ext3
lrwxrwxrwx 1 build build        53 Nov 23 22:50 intrepid-image-qemux86.manifest -> intrepid-image-qemux86-20141123222452.rootfs.manifest
lrwxrwxrwx 1 build build        52 Nov 23 22:50 intrepid-image-qemux86.tar.bz2 -> intrepid-image-qemux86-20141123222452.rootfs.tar.bz2
-rw-rw-r-- 2 build build  76113794 Nov 23 20:45 modules--3.14.19+git0+fb6271a942_e19a1b40de-r0-qemux86-20141123195331.tgz
lrwxrwxrwx 1 build build        73 Nov 23 20:45 modules-qemux86.tgz -> modules--3.14.19+git0+fb6271a942_e19a1b40de-r0-qemux86-20141123195331.tgz
build@3c3fd562548b:~/shared/my-genivi-build$
```

In case the build fails, you may try to clean the offending tasks, as in the following example:

    bitbake -c cleansstate cairo
    
then invoke `bitbake intrepid-image` again.

### Running the created images with QEMU inside the container

FIXME: The commands in this section still do not work inside the container.

#### For QEMU vexpressa9

    $GENIVI/meta-ivi/scripts/runqemu horizon-image vexpressa9

#### For QEMU x86

    $GENIVI/poky/scripts/runqemu horizon-image qemux86

#### For QEMU x86-64

    $GENIVI/poky/scripts/runqemu horizon-image qemux86-x64
    
## (Optional) Committing the image after building the Yocto GENIVI Baseline

If the previous commands were successful, exit the container, then execute the following commands to persist the container into a Docker image:

    CONTAINER_ID=$(docker ps -lq)
    docker commit -m "John Doe <john.doe@me.com>" $CONTAINER_ID <repository:tag>

You may optionally push the image to a public Docker repository, like

    docker push <repository>

## Creating standalone images for execution under QEMU, VirtualBox and VMware Player

This works only for `MACHINE=qemux86`

Review the `create_standalone_images.sh` script to adjust the configurable parameters, then run

    ./create_standalone_images.sh

Follow the instructions displayed by the script for loading and running the images under:

* [qemu-system-i386](http://www.qemu.org/) (tested with qemu-kvm 1.0 on Ubuntu 12.04.4 LTS)
* [Oracle VM VirtualBox](https://www.virtualbox.org/) (tested with VirtualBox 4.3.10 on MS Windows 7 and Ubuntu 12.04.4 LTS)
* [VMware Player](http://www.vmware.com/products/player) (tested with VMware Player 6.0.1 on MS Windows 7)
