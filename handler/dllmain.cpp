// dllmain.cpp : Git Bash Here - Windows 11 Modern Context Menu Extension
//
// Implements IExplorerCommand via WRL to add "Git Bash Here" to the
// Windows 11 top-level right-click context menu (not "Show more options").
//
// Based on Microsoft's SparsePackages sample and the VS Code context menu PR.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shlwapi.h>
#include <shobjidl_core.h>
#include <wrl/client.h>
#include <wrl/implements.h>
#include <wrl/module.h>
#include <string>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "runtimeobject.lib")

using namespace Microsoft::WRL;

// ============================================================================
// CONFIGURATION - Change these if your Git installation path differs
// ============================================================================
static const wchar_t* GIT_BASH_EXE   = L"C:\\Program Files\\Git\\git-bash.exe";
static const wchar_t* GIT_BASH_ICON  = L"C:\\Program Files\\Git\\git-bash.exe";
static const wchar_t* MENU_TITLE     = L"Git Bash Here";

// ============================================================================
// DLL Entry Point
// ============================================================================
HINSTANCE g_hModule = nullptr;

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved)
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        g_hModule = hModule;
        DisableThreadLibraryCalls(hModule);
        break;
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

// ============================================================================
// Helper: Get the folder path from a shell item (works for both directory
// background clicks and direct folder right-clicks)
// ============================================================================
static std::wstring GetFolderFromItem(IShellItem* psi)
{
    SFGAOF attrs = 0;
    psi->GetAttributes(SFGAO_FOLDER, &attrs);

    LPWSTR filePath = nullptr;
    if (SUCCEEDED(psi->GetDisplayName(SIGDN_FILESYSPATH, &filePath)) && filePath)
    {
        std::wstring result(filePath);
        CoTaskMemFree(filePath);

        if (attrs & SFGAO_FOLDER)
        {
            return result; // It's already a folder
        }

        // It's a file - get the parent directory
        size_t pos = result.find_last_of(L"\\");
        if (pos != std::wstring::npos)
        {
            return result.substr(0, pos);
        }
        return result;
    }
    return L"";
}

// ============================================================================
// ExplorerCommand Implementation - "Git Bash Here"
// ============================================================================

// {7B4F26A1-3C9D-4E8B-A5F2-1D6E8C0B9A3F}
// You can generate a new GUID with Visual Studio (Tools > Create GUID) or
// PowerShell: [guid]::NewGuid()
static const CLSID CLSID_GitBashHere =
    { 0x7b4f26a1, 0x3c9d, 0x4e8b, { 0xa5, 0xf2, 0x1d, 0x6e, 0x8c, 0x0b, 0x9a, 0x3f } };

class __declspec(uuid("7B4F26A1-3C9D-4E8B-A5F2-1D6E8C0B9A3F"))
    GitBashHereCommand final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, IExplorerCommand, IObjectWithSite>
{
public:
    // IExplorerCommand
    IFACEMETHODIMP GetTitle(_In_opt_ IShellItemArray* items, _Outptr_result_nullonfailure_ PWSTR* name)
    {
        *name = nullptr;
        return SHStrDupW(MENU_TITLE, name);
    }

    IFACEMETHODIMP GetIcon(_In_opt_ IShellItemArray*, _Outptr_result_nullonfailure_ PWSTR* icon)
    {
        *icon = nullptr;
        return SHStrDupW(GIT_BASH_ICON, icon);
    }

    IFACEMETHODIMP GetToolTip(_In_opt_ IShellItemArray*, _Outptr_result_nullonfailure_ PWSTR* infoTip)
    {
        *infoTip = nullptr;
        return E_NOTIMPL;
    }

    IFACEMETHODIMP GetCanonicalName(_Out_ GUID* guidCommandName)
    {
        *guidCommandName = CLSID_GitBashHere;
        return S_OK;
    }

    IFACEMETHODIMP GetState(_In_opt_ IShellItemArray* selection, _In_ BOOL okToBeSlow, _Out_ EXPCMDSTATE* cmdState)
    {
        *cmdState = ECS_ENABLED;
        return S_OK;
    }

    IFACEMETHODIMP Invoke(_In_opt_ IShellItemArray* selection, _In_opt_ IBindCtx*) noexcept
    {
        // Check if git-bash.exe exists before doing anything
        DWORD attrs = GetFileAttributesW(GIT_BASH_EXE);
        if (attrs == INVALID_FILE_ATTRIBUTES)
        {
            std::wstring msg = L"Git for Windows was not found at:\n";
            msg += GIT_BASH_EXE;
            msg += L"\n\nIf Git has been uninstalled, you can remove this context menu entry by running uninstall.ps1 as Administrator from:\n";
            msg += L"C:\\Program Files\\GitBashHere";
            MessageBoxW(nullptr, msg.c_str(), L"Git Bash Here", MB_OK | MB_ICONWARNING);
            return S_OK;
        }

        std::wstring workingDir;

        if (selection)
        {
            DWORD count = 0;
            selection->GetCount(&count);

            if (count > 0)
            {
                IShellItem* psi = nullptr;
                if (SUCCEEDED(selection->GetItemAt(0, &psi)) && psi)
                {
                    workingDir = GetFolderFromItem(psi);
                    psi->Release();
                }
            }
        }

        // If we couldn't determine a folder, fall back to the user's profile
        if (workingDir.empty())
        {
            wchar_t userProfile[MAX_PATH];
            if (GetEnvironmentVariableW(L"USERPROFILE", userProfile, MAX_PATH))
            {
                workingDir = userProfile;
            }
        }

        // Build the command line: git-bash.exe --cd="<path>"
        std::wstring cmdLine = L"\"";
        cmdLine += GIT_BASH_EXE;
        cmdLine += L"\" --cd=\"";
        cmdLine += workingDir;
        cmdLine += L"\"";

        STARTUPINFOW si = { sizeof(si) };
        PROCESS_INFORMATION pi = {};

        CreateProcessW(
            nullptr,
            const_cast<LPWSTR>(cmdLine.c_str()),
            nullptr, nullptr, FALSE, 0, nullptr,
            workingDir.c_str(),
            &si, &pi
        );

        if (pi.hProcess) CloseHandle(pi.hProcess);
        if (pi.hThread)  CloseHandle(pi.hThread);

        return S_OK;
    }

    IFACEMETHODIMP GetFlags(_Out_ EXPCMDFLAGS* flags)
    {
        *flags = ECF_DEFAULT;
        return S_OK;
    }

    IFACEMETHODIMP EnumSubCommands(_COM_Outptr_ IEnumExplorerCommand** enumCommands)
    {
        *enumCommands = nullptr;
        return E_NOTIMPL;
    }

    // IObjectWithSite
    IFACEMETHODIMP SetSite(_In_ IUnknown* site) noexcept
    {
        m_site = site;
        return S_OK;
    }

    IFACEMETHODIMP GetSite(_In_ REFIID riid, _COM_Outptr_ void** site) noexcept
    {
        return m_site.CopyTo(riid, site);
    }

protected:
    ComPtr<IUnknown> m_site;
};

// Register the class with WRL
CoCreatableClass(GitBashHereCommand)
CoCreatableClassWrlCreatorMapInclude(GitBashHereCommand)

// ============================================================================
// DLL Exports
// ============================================================================

STDAPI DllGetActivationFactory(_In_ HSTRING activatableClassId, _COM_Outptr_ IActivationFactory** factory)
{
    return Module<ModuleType::InProc>::GetModule().GetActivationFactory(activatableClassId, factory);
}

STDAPI DllCanUnloadNow()
{
    return Module<InProc>::GetModule().GetObjectCount() == 0 ? S_OK : S_FALSE;
}

STDAPI DllGetClassObject(_In_ REFCLSID rclsid, _In_ REFIID riid, _COM_Outptr_ void** ppv)
{
    return Module<InProc>::GetModule().GetClassObject(rclsid, riid, ppv);
}
