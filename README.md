# Narzędzia serwisowe Windows

Narzędzie z okienkiem (PowerShell + WinForms) do szybkiego serwisu komputera klienta. Wymaga Windows 10 lub 11.

## Uruchomienie

W PowerShellu (najlepiej jako administrator):

```powershell
irm https://raw.githubusercontent.com/podkal95/narzedzia/main/uslugi.ps1 | iex
```

Na starszym Windows 10, jeśli pojawi się błąd połączenia:

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/podkal95/narzedzia/main/uslugi.ps1 | iex
```

## Zakładki

- **Usługi:** ponad 70 usług w kategoriach, z opisem tego, co przestanie działać. Do wyboru Wyłączony albo Ręczny. Przed zmianą robi punkt przywracania i kopię ustawień, a zmiany da się cofnąć.
- **Autostart:** włączanie i wyłączanie programów startujących z Windows, tak jak w Menedżerze zadań.
- **Programy w tle:** co działa, ile zajmuje pamięci, zamykanie programów, blokada aplikacji ze Sklepu w tle.
- **Czyszczenie:** pliki tymczasowe, cache aktualizacji, kosz, przeglądarki, DISM. Pokazuje, ile miejsca zwolniono.
- **Bezpieczeństwo:** antywirus, zapora, aktualizacje, UAC, RDP, SMBv1, Secure Boot, TPM, BitLocker, konta. Do tego szybkie naprawy i raport dla klienta na pulpicie.

Skrypt nic nie pobiera i nie instaluje. Kopie ustawień i log zapisuje w `C:\ProgramData\UslugiKopia`.
