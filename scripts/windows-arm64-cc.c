// Tiny wrapper used by CI: c3c invokes the C compiler without --target for
// windows-aarch64, so we forward every argument to clang with the right target.
#include <windows.h>
#include <string.h>

int main(void)
{
	const wchar_t* prefix = L"\"C:\\Program Files\\LLVM\\bin\\clang.exe\" --target=aarch64-windows-msvc ";
	const wchar_t* original = GetCommandLineW();
	const wchar_t* args = original;

	// Skip the executable name (quoted or not).
	if (*args == L'"')
	{
		args++;
		while (*args && *args != L'"') args++;
		if (*args) args++;
	}
	else
	{
		while (*args && *args != L' ' && *args != L'\t') args++;
	}
	while (*args == L' ' || *args == L'\t') args++;

	wchar_t cmdline[32768];
	int n = 0;
	while (prefix[n] && n < 32760)
	{
		cmdline[n] = prefix[n];
		n++;
	}
	int i = 0;
	while (args[i] && n < 32760)
	{
		cmdline[n++] = args[i++];
	}
	cmdline[n] = 0;

	STARTUPINFOW si;
	PROCESS_INFORMATION pi;
	memset(&si, 0, sizeof(si));
	memset(&pi, 0, sizeof(pi));
	si.cb = sizeof(si);

	if (!CreateProcessW(NULL, cmdline, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi))
	{
		return 1;
	}
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD code = 0;
	GetExitCodeProcess(pi.hProcess, &code);
	CloseHandle(pi.hThread);
	CloseHandle(pi.hProcess);
	return (int)code;
}
