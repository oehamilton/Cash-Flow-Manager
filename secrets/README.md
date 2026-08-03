# Local signing secrets (not committed)

Private code-signing material for MSIX builds lives here and is gitignored.

## Create a Project8X signing cert (once per machine / team)

```powershell
.\tool\new_code_signing_cert.ps1
```

Writes:

- `secrets/Project8X-CodeSigning.pfx` — private key (never commit)
- `secrets/Project8X-CodeSigning.password.txt` — PFX password (never commit)
- `packaging/Project8X-CodeSigning.cer` — public cert (safe to commit / ship to users)

Optional env overrides when building:

- `CFM_MSIX_CERT_PATH` — path to `.pfx`
- `CFM_MSIX_CERT_PASSWORD` — PFX password (else read from `.password.txt`)

Then:

```powershell
.\tool\build_release.ps1 -Msix -Architecture arm64
```
