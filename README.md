# Git Bash Here — Windows 11 Modern Context Menu

Adds **"Git Bash Here"** to the Windows 11 top-level right-click context menu (not buried under "Show more options").

This works by implementing a COM DLL with the `IExplorerCommand` interface and registering it via a Sparse MSIX package to give it app identity — the same mechanism apps like Terminal, WinMerge, and VS Code use.

---

## Prerequisites

- **Windows 10 (2004+) or Windows 11**
- **Git for Windows** installed at `C:\Program Files\Git` (default location)
- **Visual Studio 2019 or 2022** with the **"Desktop development with C++"** workload
  - This includes the compiler (`cl.exe`), linker, and Windows SDK tools (`MakeAppx`, `MakeCert`, `SignTool`)

If Git is installed somewhere else, edit the paths at the top of `handler\dllmain.cpp` before building.

---

## Quick Start

### 1. Build

Double-click **`build.cmd`**. It automatically finds your Visual Studio installation and sets up the compiler environment — no need to open a special command prompt.

The certificate tools will prompt you for a password — you can use anything (even just press Enter for blank) but use the **same input each time** it asks. This creates a self-signed certificate for local/personal use only.

Output lands in `Release\`:
- `GitBashHere.dll` — the context menu handler
- `GitBashHere.appx` — the sparse MSIX package
- `Key.cer` — the self-signed certificate

### 2. Install

Double-click **`install.cmd`**. It will prompt for Administrator privileges via UAC automatically.

This:
1. Copies the DLL and package to `C:\Program Files\GitBashHere\`
2. Installs the self-signed cert to Trusted Root (required for the sparse package)
3. Registers the COM class
4. Registers the sparse MSIX package
5. Restarts Explorer

### 3. Use It

Right-click on a folder, on a file, or on the empty background inside any folder. **"Git Bash Here"** should appear in the main context menu with the Git icon.

---

## Uninstall

Double-click **`uninstall.cmd`**. It will prompt for Administrator privileges via UAC automatically.

This removes the package, COM registration, certificate, and installed files.

---

## Customization

### Different Git install path

Edit the constants at the top of `handler\dllmain.cpp`:

```cpp
static const wchar_t* GIT_BASH_EXE   = L"C:\\Program Files\\Git\\git-bash.exe";
static const wchar_t* GIT_BASH_ICON  = L"C:\\Program Files\\Git\\git-bash.exe";
static const wchar_t* MENU_TITLE     = L"Git Bash Here";
```

### Different CLSID

If you want to run multiple similar extensions, generate a new GUID:

```powershell
[guid]::NewGuid()
```

Then replace the GUID `7B4F26A1-3C9D-4E8B-A5F2-1D6E8C0B9A3F` in:
- `handler\dllmain.cpp` (two places: the static CLSID and the `__declspec(uuid(...))`)
- `sparse-pkg\AppxManifest.xml` (two places: the `Clsid` attributes and the `com:Class Id`)
- `install.ps1` (the `$clsid` variable)
- `uninstall.ps1` (the `$clsid` variable)

### Adding Git GUI Here too

You could add a second command class in `dllmain.cpp` with a different GUID, title "Git GUI Here", and launch `git-gui.exe` instead. Register the second CLSID in the manifest the same way.

---

## How It Works

1. **`dllmain.cpp`** implements `IExplorerCommand` using WRL (Windows Runtime C++ Template Library). When Windows calls `Invoke`, it runs `CreateProcess` to launch `git-bash.exe --cd="<folder>"`.

2. **`AppxManifest.xml`** is a Sparse Package manifest that:
   - Gives the DLL an "app identity" (required by Windows 11's modern menu)
   - Declares `windows.fileExplorerContextMenus` with the COM class ID
   - Registers the COM server pointing to the DLL

3. **`install.ps1`** uses `Add-AppxPackage -ExternalLocation` to register the sparse package without bundling everything into a full MSIX installer.

---

## Troubleshooting

**Menu item doesn't appear:**
- Make sure Explorer was restarted (the install script does this, but you can manually run `taskkill /f /im explorer.exe && start explorer.exe`)
- Check that the sparse package is registered: `Get-AppxPackage -Name "GitBashHere"`
- Verify the COM class is registered: check `HKLM\SOFTWARE\Classes\CLSID\{7B4F26A1-3C9D-4E8B-A5F2-1D6E8C0B9A3F}` in regedit

**"Git Bash Here" appears but clicking it does nothing:**
- Verify `C:\Program Files\Git\git-bash.exe` exists
- If Git is installed elsewhere, edit `dllmain.cpp` and rebuild

**Build errors about missing headers:**
- Make sure you're using the x64 Native Tools Command Prompt, not a regular cmd/PowerShell
- Ensure the "Desktop development with C++" workload is installed in VS

**MakeAppx/MakeCert/SignTool not found:**
- These come with the Windows SDK. Add the SDK bin path to your PATH, e.g.:
  `set PATH=%PATH%;C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64`

---

## Credits

Based on:
- [Microsoft AppModelSamples - SparsePackages](https://github.com/microsoft/AppModelSamples/tree/master/Samples/SparsePackages)
- [VS Code Windows 11 context menu PR](https://github.com/microsoft/vscode/pull/139640)
- [cjee21/IExplorerCommand-Examples](https://github.com/cjee21/IExplorerCommand-Examples)

## License

WTFPL — Do What The Fuck You Want To Public License.
