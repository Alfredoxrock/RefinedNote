# Signing and publishing Notes Desktop App (Appx / MSIX)

This document explains how to obtain a code signing certificate (PFX), prepare it, and produce a signed Appx/MSIX package suitable for Microsoft Store / Partner Center uploads.

Prerequisites
- Windows machine with Windows 10/11 SDK installed (MakeAppx, SignTool available).
- electron-builder installed (devDependency) and working (you already built NSIS and Appx locally).
- A code signing certificate in PFX format that includes the private key and a password.

Overview (high level)
1. Obtain a code-signing certificate from a CA (EV recommended). The certificate's subject Common Name (CN) must match the `publisher` field used in your Appx manifest (e.g. `CN=YourPublisherName`).
2. Convert or export the certificate to a PFX file that contains the private key and certificate chain.
3. Keep the PFX secure (do NOT commit to the repo). Use local secure storage or CI secrets.
4. Provide the PFX and password to electron-builder via environment variables or by setting `build.win.cscLink` / `build.win.cscKeyPassword` in CI.
5. Run the Appx build: `npm run build:appx` — electron-builder will sign the Appx during the build.

Environment variables electron-builder supports
- CSC_LINK: file path (file://C:/path/to/cert.pfx) or HTTP(s) URL where the PFX can be fetched in CI.
- CSC_KEY_PASSWORD: password for the PFX file.

Local developer flow (recommended for testing)
1. Put your PFX somewhere safe on your development machine (for example: `C:\keystore\notesapp.pfx`).
2. Update the `appx.publisher` field in `package.json` to exactly match the certificate subject (for example `CN=Contoso, O=Contoso Ltd, L=City, S=State, C=US`).
3. From PowerShell run:

```powershell
# Set environment variables for the current session (replace with your paths/password)
$env:CSC_LINK = 'file://C:/keystore/notesapp.pfx'
$env:CSC_KEY_PASSWORD = 'YOUR_PFX_PASSWORD'

# Build signed Appx
npm run build:appx
```

CI flow (recommended for automated builds)
- Upload the PFX to your CI secret store (GitHub Actions `secrets` / Azure Pipelines secure files). Provide a download step that places the file on the runner and expose the path as the `CSC_LINK` environment variable (use `file://` path or set `CSC_LINK` to an HTTP(s) url that the builder can fetch).
- Set `CSC_KEY_PASSWORD` as a secured secret variable.

Notes and troubleshooting
- If electron-builder reports `AppX is not signed — Windows Store only build`, it means no valid certificate was found. Verify `CSC_LINK` and `CSC_KEY_PASSWORD` are set and that the subject CN matches the `appx.publisher` value.
- For Partner Center uploads, use the same publisher identity as the Partner Center account publisher name.
- Keep PFX private. Do not commit it or store it in the repository.

Further reading
- electron-builder signing docs: https://www.electron.build/code-signing
- Microsoft Store / Partner Center docs: https://learn.microsoft.com/windows/apps
