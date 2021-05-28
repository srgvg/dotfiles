#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#Adapted from https://gist.github.com/filipenf/2cc72af47e3570afaa9d3bf2e71658c3

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


class VaultHelper():
    def __init__(self, vault_id):
        loader = DataLoader()
        vaults = [v for v in C.DEFAULT_VAULT_IDENTITY_LIST if v.startswith('{0}@'.format(vault_id))]
        if len(vaults) != 1:
            raise ValueError("'{0}' does not exist in ansible.cfg '{1}'".format(vault_id, C.DEFAULT_VAULT_IDENTITY_LIST))

        self.vault_id = vault_id
        vault_secret = CLI.setup_vault_secrets(
            loader=loader,
            vault_ids=vaults
        )
        self.vault = VaultLib(vault_secret)


    def convert_vault_to_strings(self, vault_data):
        decrypted = self.vault.decrypt(vault_data)
        d = yaml.load(decrypted, Loader=AnsibleLoader)
        self._encrypt_dict(d)
        return d


    def _encrypt_dict(self, d):
        for key in d:
            value = d[key]
            if isinstance(value, str):
                d[key] = AnsibleVaultEncryptedUnicode(
                    self.vault.encrypt(plaintext=value, vault_id=self.vault_id))
            elif isinstance(value, list):
                for item in value:
                    self._encrypt_dict(item)
            elif isinstance(value, dict):
                self._encrypt_dict(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-file',
                        help='File to read from',
                        required=True)
    parser.add_argument('--output-file',
                        help='File to to write to',
                        required=True)
    parser.add_argument('--vault-id',
                        help='Vault id used for the encryption',
                        required=True)
    args = parser.parse_args()
    original_secrets = open(args.input_file).read()
    vault = VaultHelper(args.vault_id)
    converted_secrets = vault.convert_vault_to_strings(original_secrets)

    with open(args.output_file, 'w+') as f:
        yaml.dump(converted_secrets, Dumper=AnsibleDumper, stream=f)


if __name__ == "__main__":
    main()
