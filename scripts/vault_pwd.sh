#!/usr/bin/env bash
# Ansible Vault password helper script
# Reads password from ANSIBLE_VAULT_PASS environment variable
# This allows vault decryption without --ask-vault-pass
echo "${ANSIBLE_VAULT_PASS}"
