#!/bin/sh

FORCE_RECOMPILE=0

SCRIPT_DIR=`pwd`

complain_to_darklight() {
        echo "\n\n======\n\nThis script ran into an issue building $1 ($2). Please ping Christopher VK4DL in openwebrx-chat or godarklight on discord\n"
        cd $SCRIPT_DIR
        exit 1
}

if [ ! -d build ]; then
        #INSTALL DEPENDANCIES TOO
        sudo apt update
        sudo apt install git build-essential cmake debhelper libfftw3-dev libsamplerate0-dev dh-python python3-all libpython3-dev python3-setuptools librtlsdr-dev libsoapysdr-dev python3-distutils-extra

        mkdir build
        mkdir build/compiled
        echo "https://github.com/luarvique/csdr.git master
https://github.com/luarvique/pycsdr.git master
https://github.com/luarvique/owrx_connector.git master
https://github.com/luarvique/openwebrx.git master" > build/owrx-config.txt
        echo "A config file has been placed at build/owrx-config.txt."
        echo "If you have been told to change this, please do this now."
        echo "OWRX+ will compile on the next run."
        exit
fi

cd build

while read -r line; do
        repo=`echo $line | cut -f 1 -d ' '`
        reponame=`echo $repo | sed 's|.*/\(.*\).git|\1|'`
        branch=`echo $line | cut -f 2 -d ' '`
        if [ ! -d $reponame ]; then
                git clone $repo $reponame
                cd $reponame
                git checkout $branch
                current_hash=`git log -1 --format=%H`
        else
                cd $reponame
                git fetch --all
                git reset --hard origin/$branch
                current_hash=`git log -1 --format=%H`
                if [ -f "../$reponame-tag.txt" ]; then
                        old_hash=`cat ../$reponame-tag.txt`
                        if [ "$current_hash" = "$old_hash" ] && [ $FORCE_RECOMPILE -eq 0 ]; then
                                echo "Skipping $reponame - Already up to date"
                                cd ..
                                continue
                        else
                                #Rebuild all projects that depend on this project
                                echo Updating $reponame
                                FORCE_RECOMPILE=1
                        fi
                else
                        echo First compile of $reponame
                        FORCE_RECOMPILE=1
                fi
        fi
        dpkg-buildpackage
        if [ $? -ne 0 ]; then
                complain_to_darklight $reponame $branch
        fi
        cd ..
        sudo dpkg -i *.deb
        if [ $? -ne 0 ]; then
                complain_to_darklight $reponame $branch
        fi
        mv *.deb compiled/
        mv *.buildinfo compiled/
        mv *.tar.xz compiled/
        mv *.changes compiled/
        mv *.dsc compiled/
        echo $current_hash > $reponame-tag.txt
done < owrx-config.txt

cd $SCRIPT_DIR
