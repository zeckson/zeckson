#!/bin/bash
set -eo pipefail
IFS=$'\n\t'

# This script adds user $1 to system with ssh-key $2 if present
USERNAME="$1"

if [ -z "$USERNAME" ]
then
  echo "Username is not provided!"
  exit 1
fi

# Create User + Set Home Directory
adduser $USERNAME

# Require to change password on login
passwd --expire $USERNAME

# Add User to sudo Group
usermod -aG sudo $USERNAME

# Create Home Directory + .ssh Directory
mkdir -p /home/$USERNAME/.ssh

# Create Authorized Keys File
touch /home/$USERNAME/.ssh/authorized_keys

# Set Permissions
chown -R $USERNAME:$USERNAME /home/$USERNAME/
chmod 700 /home/$USERNAME/.ssh
chmod 644 /home/$USERNAME/.ssh/authorized_keys

SSH_KEY=$2
if [ -n "$SSH_KEY" ]
then
  echo "$SSH_KEY" >> /home/$USERNAME/.ssh/authorized_keys
  echo "SSH key is written"
fi