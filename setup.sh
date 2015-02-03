#!/bin/bash

# Copyright (C) 2014 Swift Navigation Inc.
# Contact: Bhaskar Mookerji <mookerji@swiftnav.com>

# This source is subject to the license found in the file 'LICENSE' which must
# be be distributed together with this source. All other rights reserved.

# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#
# Script for setting up piksi_firmware development environment across
# different development environments. It's not guaranteed to be
# idempotent, or have any other guarantees for that matter, but if
# you're having issues with your particular development platform,
# please let us know: we are trying to account for as many hacks as
# possible

####################################################################
## Utilities.

function color () {
    # Print with color.
    printf '\033[%sm%s\033[m\n' "$@"
}

purple='35;1'
red='31;1'
red_flashing='31;5'
splash_color=$red
message_color=$purple
error_color=$red_flashing

function log_info () {
    color $message_color "$@"
}

function log_error () {
    color $error_color "$@"
}

function build () {
    # Pulls down git submodules and builds the project, assuming that
    # all other system, ARM GCC, and python dependencies have been
    # installed.
    log_info "Initializing Git submodules for ChibiOS, libopencm3, and libswiftnav..."
    git submodule init
    git submodule update
    log_info "Building piksi_firmware..."
    make clean
    make
}

#########################
## Linux dependency management and build

function piksi_splash_linux () {
    # Splash screen. Generated by http://patorjk.com/software/taag/.
    log_info "
          _/\/\/\/\/\____/\/\____/\/\____________________/\/\___
          _/\/\____/\/\__________/\/\__/\/\____/\/\/\/\_________
          _/\/\/\/\/\____/\/\____/\/\/\/\____/\/\/\/\____/\/\___
          _/\/\__________/\/\____/\/\/\/\__________/\/\__/\/\___
         _/\/\__________/\/\/\__/\/\__/\/\__/\/\/\/\____/\/\/\__

         Welcome to piksi_firmware development installer!

    "
}

####################################################################
## Mac OS X dependency management and build

function piksi_splash_osx () {
    # Splash screen. Generated by http://patorjk.com/software/taag/.
    log_info "
         '7MM\"\"\"Mq.    db   '7MM                    db
           MM   'MM.          MM
           MM   ,M9  '7MM     MM  ,MP'  ,pP\"Ybd   '7MM
           MMmmdM9     MM     MM ;Y     8I    '\"    MM
           MM          MM     MM;Mm     'YMMMa.     MM
           MM          MM     MM  Mb.  L.    I8     MM
         .JMML.      .JMML. .JMML. YA.  M9mmmP'   .JMML.

         Welcome to piksi_firmware development installer!

    "
}

function homebrew_install () {
    # Provides homebrew for OS X and fixes permissions for brew
    # access. Run this if you need to install brew by:
    #    source ./setup.sh
    #    homebrew_install
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew doctor
    brew update
    # Homebrew apparently requires the contents of /usr/local to be
    # chown'd to your username.  See:
    # http://superuser.com/questions/254843/cant-install-brew-formulae-correctly-permission-denied-in-usr-local-lib
    sudo chown -R `whoami` /usr/local
}

function bootstrap_osx () {
    log_info "Checking base OS X development tools..."
    # Download and install Command Line Tools
    if [[ ! -x /usr/bin/gcc ]]; then
        log_info "Installing Xcode developer tools..."
        xcode-select --install
    fi
    # Download and install Homebrew
    if [[ ! -x /usr/local/bin/brew ]]; then
        log_info "Installing homebrew..."
        homebrew_install
    fi
    # Download and install Homebrew Python
    if [[ ! -x /usr/local/bin/python ]]; then
        log_info "Installing homebrew python..."
        brew install python --framework --with-brewed-openssl 2> /dev/null
        # Check for bash profile and add Homebrew Python to path.
        touch ~/.bash_profile
        echo '' >> ~/.bash_profile
        echo 'export PATH=/usr/local/bin:/usr/local/sbin:$PATH' >> ~/.bash_profile
        source ~/.bash_profile
    fi
    # Download and install Ansible
    if [[ ! -x /usr/local/bin/ansible ]]; then
        log_info "Installing Ansible..."
        brew install ansible 2> /dev/null
    fi
}

####################################################################
## Entry points

function setup_ansible_plugins () {
    log_info "Checking ansible plugins..."
    mkdir -p ~/.ansible/callback_plugins/
    # Allows more easiliy readable terminal output from the Ansible provisioner
    curl -fsSL -o ~/.ansible/callback_plugins/human_log.py \
        https://raw.githubusercontent.com/ginsys/ansible-plugins/devel/callback_plugins/human_log.py
}

function install_ansible () {
    # Required if Ansible's not already available via apt-get.
    if [[ ! -x /usr/bin/ansible ]]; then
        log_info "Installing ansible from custom repo..."
        sudo add-apt-repository ppa:rquillo/ansible
        sudo apt-get update && sudo apt-get install ansible
    fi
}

function run_all_platforms () {
    if [ ! -e ./setup.sh ] ; then
        log_error "Error: setup.sh should be run from piksi_firmware toplevel." >&2
        exit 1
    elif [[ "$OSTYPE" == "linux-"* ]]; then
        piksi_splash_linux
        log_info "Checking system dependencies for Linux..."
        log_info "Please enter your password for apt-get..."
        log_info "Updating..."
        sudo apt-get update
        sudo apt-get install -y curl
        sudo apt-get install python python-dev python-pip
        sudo pip install ansible
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        piksi_splash_osx
        log_info "Checking system dependencies for OSX..."
        log_info "Please enter your password..."
        bootstrap_osx
    else
        log_error "This script does not support this platform. Please contact mookerji@swiftnav.com."
        exit 1
    fi
    # setup_ansible_plugins
    ansible-playbook --ask-sudo-pass -i setup/ansible/inventory.ini \
        setup/ansible/provision.yml --connection=local
    log_info "Done!"
    log_info ""
    log_info "If you'd like to build the firmware, run: bash setup.sh -x build."
}

function show_help() {
    log_info "piksi_firmware development setup script."
    log_info ""
    log_info "Usage: bash setup.sh -x <command>, where:"
    log_info "   install, Install dependencies."
    log_info "   build,   Build firmware."
    log_info "   help,    This help message."
    log_info ""
}

set -e -u

while getopts ":x:" opt; do
    case $opt in
        x)
            if [[ "$OPTARG" == "install" ]]; then
                run_all_platforms
                exit 0
            elif [[ "$OPTARG" == "build" ]]; then
                log_info "build piksi_firmware."
                build
                exit 0
            elif [[ "$OPTARG" == "info" ]]; then
                log_info "piksi_firmware development setup script.."
                exit 0
            elif [[ "$OPTARG" == "help" ]]; then
                show_help
                exit 0
            else
                echo "Invalid option: -x $OPTARG" >&2
            fi
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            ;;
    esac
    exit 1
done
show_help
