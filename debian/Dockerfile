ARG USER=zeckson

FROM debian:9

# This is short description of:
# https://www.digitalocean.com/community/tutorials/initial-server-setup-with-debian-9

# Remove LDAP utils
RUN apt remove unscd

# Create new user and add it to sudoers
RUN adduser $USER
RUN usermod -aG sudo $USER

# Install Firewall UFW
RUN apt update
RUN apt install ufw

# List available rules (by default all is blocked)
RUN ufw app list
# Allow OpenSSH
RUN ufw allow OpenSSH
# Enable Firewall
RUN ufw enable
# Check status
RUN ufw status

# Copy root ssh public keys to our new user
RUN cp -r ~/.ssh /home/$USER
RUN chown -R $USER:$USER /home/$USER/.ssh

# Switch to user
USER $USER

# Install man
RUN sudo apt install man-db

# Change default editor
RUN sudo update-alternatives --config editor

# We are all set to go!
