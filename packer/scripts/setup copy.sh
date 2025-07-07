#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

set -x

# Setup sudo to allow no-password sudo for "rhel" user
sudo useradd -m -s /bin/bash rhel
sudo cp /etc/sudoers /etc/sudoers.orig
echo "rhel  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/rhel
# Installing SSH key ( only for Packer to use once)
sudo mkdir -p /home/rhel/.ssh
sudo chmod 700 /home/rhel/.ssh
sudo cp /tmp/tf-packer.pub /home/rhel/.ssh/authorized_keys
sudo chmod 600 /home/rhel/.ssh/authorized_keys
sudo chown -R rhel /home/rhel/.ssh

sudo echo ‘ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7GNS20k0WsH+B6sEqElKQCh5gSvCUyjW695dbQbJn3/j3S2r3CZadmTqJDA0feBEhq1aqWCRUyFiv93/1Ns/Gw0DgeZu9UTBJhHE3nmhp1b+xK3ci9/KebFWqPHBB0IF6ZdXz04x7b2msDytusaBrCChusdekgZWboiZG/1Xa0nLHg/QVysz1GkytquKVkMy0lvKb6tc6ZQRJRAbyL6nOU8PkqEITHalC43GN8qtzWT8h5VxiVksn22UEnWuHICrkLBFk7u83QLO4BzV4l7bv5GdaU3VowDvJOuRgBO0EQblJ1BIQ0UsMKrG8HepFAUBzffTCNM/TxUAjeu0YxTbRf3mBrENQV7ewV63Qqbx7m00FS9Wc8E34peYKMUd0llH1RnNiYTD3UTGnN6rNxaLCY9flSdws7gE7H7HnpT14jC/jI/FzIUgRyvzPwcs0iJBEXufKMFUo26rPFQ0a7WSYjBji9gQFqeEDuy80WExXIjGwtsI08aY4ILz1Jzatp2da6WQKmMoMOlN+sEFUcB+kUYjqdeZJ8nDzy2eNioyqIG8J9Wvb5H7p0IHn8D5jqhg/rtVNNMIBNYdRI2aD50FNvYdRvMlSel6ZnnpfPy7Mb3t2wbKiNm4nlsGH7hRab/Uw4fS1Dy3EK2SF9ZyxiSj7Qdcqz9CzcM/dkulmOLW5Kw==’ > /etc/ssh/trusted-user-ca-keys.pem

## SSH CA integration ( to ssh into the VM with Vault SIGNED SSH CA)

    echo "PermitRootLogin no" >> /etc/ssh/sshd_config && \
    echo "AllowUsers rhel" >> /etc/ssh/sshd_config && \
    echo "AuthorizedKeysCommand none" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >>/etc/ssh/sshd_config

    sudo systemctl restart sshd


