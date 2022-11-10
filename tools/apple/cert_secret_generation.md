## How to generate macOS pkg installer file for upload to macOS Store
# or: dmg installer file for adhoc distribution

# Generate certificate signing request in macOS - use Certificate Signing Assistant in KeyChain Access tool

- Log in to account in developer.apple.com
- Generate Mac Installer certificate (or "Developer ID Application" certificate for dmg/adhoc)
- Download as .cer file (x509)
- In macOS, double-click to import to keychain
  - use login rather than Local
  - MUST appear in "My Certificates" section!! So that you can export an identity (including private key)
  - if NOT appearing in "My Certificates" - import an existing valid p12 with password
- Export this certificate now as .p12 
  - Set password
  - copy password val as `MAC_CERT_PWD` to GITHUB secrets
- Encode p12 file as base64 
  - cat <cert.p12> | base64 > cert.p12.base64
  - copy value as `MAC_CERT` in GITHUB secrets
- Set CN of .cer cert as value for `MAC_CERT_ID` in GITHUB secrets
  - eg "3rd Party Mac Developer Installer: Koord, Inc (TXZ4FR95HG)"

# GITHUB secrets generated:

- Name: MAC_CERT
- Value: <base64-encoded value of certificate in p12 format>
- Example: <lots of b64 data>

- Name: MAC_CERT_PWD
- Value: <password generated during export of certificate to p12 format>
- Example: 98sydf987sdf98s7df

- Name: MAC_CERT_ID
- Value: CN of certificate
- Example: "3rd Party Mac Developer Installer: Koord, Inc (TXZ4FR95HG)"


Use this for pkg Installer signing
eg
% productbuild --sign "3rd Party Mac Developer Installer: Koord, Inc (TXZ4FR95HG)" --component file.app /Applications file.pkg

# Useful refs:

https://developer.apple.com/forums/thread/701581#701581021 

https://support.magplus.com/hc/en-us/articles/203808748-iOS-Creating-a-Distribution-Certificate-and-p12-File
