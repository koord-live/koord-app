#!/usr/bin/python

##FIXME - not working atm. Secrets values end up empty in Github - don't know why

## Util to add secrets to a Github repo from a text file

## Requirements:
# - Github Personal Access token with repo admin rights (in env GITHUB_AUTH_TOKEN)
# - secrets.txt file formatted, one line per secret:
    # MAC_ADHOC_CERT_PWD: UXPGuxxxxCYE
    # MAC_ADHOC_CERT_ID: Developer ID Application: Koord, Inc (TXZZZZZZZHG)
    # ...

## Ref: https://docs.github.com/en/rest/actions/secrets#create-or-update-an-environment-secret 

from base64 import b64encode
from nacl import encoding, public
import re
import requests
import os
import json

def encrypt(public_key: str, secret_value: str) -> str:
    """Encrypt a Unicode string using the public key."""
    public_key = public.PublicKey(public_key.encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return b64encode(encrypted).decode("utf-8")


github_auth_token = os.getenv("GITHUB_AUTH_TOKEN")

public_gh_resp =  requests.get(
                'https://api.github.com/orgs/koord-live/actions/secrets/public-key',
                 headers={
                    "Accept": "application/vnd.github+json",
                    "Authorization": "Bearer {0}".format(github_auth_token)
                }
            )

public_gh_key = public_gh_resp.json() 

print ("public gh key: {0}".format(public_gh_key["key_id"]))

f = open("secrets.txt", "r")
for line in f:
    m = re.match(r"(\w+)?: (.+)", line)
    # print (m.group(1) + ": " + m.group(2))
    secret_name = m.group(1)
    secret_val = encrypt(public_gh_key["key"], m.group(2))

    print("Creating secret : {0}".format(secret_name))
    # print("Creating secret with val: {0}".format(secret_val))

    payload = {
        "encrypted_value": secret_val,
        "key_id": public_gh_key["key_id"]
    }

    put_secret = requests.put(
                    "https://api.github.com/repos/koord-live/koord-app-nx1/actions/secrets/{0}".format(secret_name),
                    data=json.dumps(payload),
                    headers={
                        "Accept": "application/vnd.github+json",
                        "Authorization": "Bearer {0}".format(github_auth_token)
                    }
                )

    print ("RESPONSE: {0}".format(put_secret.content))
