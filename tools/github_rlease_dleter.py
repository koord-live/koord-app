#!/usr/bin/python

## Util to delete pre-releases from github repo

# requires: GITHUB_AUTH_TOKEN set as env var

import requests
import json
import os
import pprint

github_auth_token = os.getenv("GITHUB_AUTH_TOKEN")


release_list_resp =  requests.get(
                'https://api.github.com/repos/koord-live/koord-app/releases',
                 headers={
                    "Accept": "application/vnd.github+json",
                    "Authorization": "Bearer {0}".format(github_auth_token)
                }
            )

release_list = release_list_resp.json() 

pp = pprint.PrettyPrinter(indent=4)

for release in release_list:
    # pp.pprint (release)
    if release['prerelease'] == True:
        print ("PRE-RELEASE FOUND to delete: {0}".format(release['name']))
        release_list_resp =  requests.delete(
                "https://api.github.com/repos/koord-live/koord-app/releases/{0}".format(release['id']),
                 headers={
                    "Accept": "application/vnd.github+json",
                    "Authorization": "Bearer {0}".format(github_auth_token)
                }
            )
        print (release_list_resp.status_code)
    else:
        print ("NOT A PRE_RELEASE: {0}".format(release['name']) )
    print()

# curl \
#   -X DELETE \
#   -H "Accept: application/vnd.github+json" \
#   -H "Authorization: Bearer <YOUR-TOKEN>" \
#   https://api.github.com/repos/OWNER/REPO/releases/RELEASE_ID


