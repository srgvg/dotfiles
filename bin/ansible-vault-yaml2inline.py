#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import yaml
import argparse
from ansible.parsing.vault import VaultLib
from ansible.cli import CLI
from ansible import constants as C
from ansible.parsing.dataloader import DataLoader
from ansible.parsing.yaml.dumper import AnsibleDumper
from ansible.parsing.yaml.loader import AnsibleLoader
from ansible.parsing.yaml.objects import AnsibleVaultEncryptedUnicode

"""
This script reads a yaml file and dumps it back while encrypting
the values but keeping the keys plaintext. To convert an ansible
vault file format into yaml you can do:
    ansible-vault decrypt --output - vault | \
        python ./convert_vault.py > new-vault
"""


def encrypt_string(decrypted_secret, vault_id=None):
    """
    Encrypts string
    """
    loader = DataLoader()
    vault_secret = CLI.setup_vault_secrets(
        loader=loader,
        vault_ids=C.DEFAULT_VAULT_IDENTITY_LIST
    )
    vault = VaultLib(vault_secret)
    return AnsibleVaultEncryptedUnicode(
            vault.encrypt(decrypted_secret,
                          vault_id=vault_id))


def encrypt_dict(d, vault_id=None):
    for key in d:
        value = d[key]
        if isinstance(value, str):
            d[key] = encrypt_string(value, vault_id)
        elif isinstance(value, list):
            for item in value:
                encrypt_dict(item)
        elif isinstance(value, dict):
            encrypt_dict(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-file',
                        help='File to read from',
                        default='-')
    parser.add_argument('--vault-id',
                        help='Vault id used for the encryption')
    args = parser.parse_args()
    in_file = sys.stdin if args.input_file == '-' else open(args.input_file)
    data = yaml.load(in_file, Loader=AnsibleLoader)

    encrypt_dict(data, vault_id=args.vault_id)

    print(yaml.dump(data, Dumper=AnsibleDumper))


if __name__ == "__main__":
    main()
