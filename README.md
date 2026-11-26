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

Tryb podglądu (bez uprawnień administratora, niczego nie zmienia, można spokojnie pooglądać):

```powershell
$TrybPodgladu=1; irm https://raw.githubusercontent.com/podkal95/narzedzia/main/uslugi.ps1 | iex
```

Poprzednie wersje, gdyby nowa sprawiała kłopoty (uruchom z PowerShella jako administrator):

```powershell
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-4/uslugi.ps1 | iex
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-3/uslugi.ps1 | iex
```

## Wygląd i konto klienta

- Program otwiera się jako osobna aplikacja z logo serwisu (własna ikona na pasku zadań), bez okna PowerShella. Menu z sekcjami jest po lewej, a obraz jest ostry przy skalowaniu 125–150%.
- Jeśli uprawnienia potwierdzisz innym kontem administratora, program sam wykrywa konto osoby siedzącej przy komputerze. Ustawienia użytkownika, autostart, raport (na jej pulpicie) i kopia danych dotyczą tego konta. W zakładce „Przed reinstalacją” można też wybrać dowolne inne konto.

## Na górnym pasku

- **Serwis ekspresowy:** jednym kliknięciem wyłącza bezpieczne usługi, czyści dysk, ustawia zalecane opcje Windows, opcjonalnie usuwa zbędne aplikacje i naprawia pliki systemu (DISM + SFC), a na koniec robi raport.
- **Raport dla klienta:** strona HTML na pulpicie z logo serwisu, wykonanymi pracami, zaleceniami (np. wymiana dysku na SSD, rozbudowa RAM, zużyta bateria), stanem zabezpieczeń i czasem uruchamiania przed i po serwisie. Przycisk na stronie zapisuje ją jako PDF.
- **Pomoc zdalna:** uruchamia Szybką pomoc Windows.

## Zakładki

- **Usługi:** ponad 70 usług w kategoriach, z opisem tego, co przestanie działać. Na starcie nic nie jest zaznaczone. Gotowe pakiety (np. „Bez Xbox”, „Bez drukarki i skanera”, „Słabszy komputer”, „Wszystkie zalecane”) zaznaczają pasujące usługi jednym kliknięciem. Przed zmianą robi punkt przywracania i kopię ustawień, a zmiany da się cofnąć.
- **Autostart:** włączanie i wyłączanie programów startujących z Windows, tak jak w Menedżerze zadań.
- **Programy w tle:** co działa, ile zajmuje pamięci, zamykanie programów, blokada aplikacji ze Sklepu w tle.
- **Aplikacje i Office:** usuwanie zbędnych aplikacji ze Sklepu (Candy Crush, Porady, Cortana, Skype, Xbox...) z pakietami. Do tego lista zainstalowanych pakietów Office (Microsoft 365, Office 2013–2024, wersje Click-to-Run i MSI): zaznaczasz kilka, a program usuwa je po kolei, po cichu.
- **Ustawienia:** bez reklam i sugestii, bez Binga w menu Start, Recall, Copilota i widżetów, rozszerzenia plików, klasyczne menu, hibernacja, szybkie uruchamianie, plan zasilania. Każde da się cofnąć.
- **Czyszczenie:** pliki tymczasowe, cache aktualizacji, kosz, przeglądarki, DISM. Pokazuje, ile miejsca zwolniono. Okno **Największe foldery** pokazuje, co zajmuje miejsce.
- **Naprawy:** DISM, SFC, reset Windows Update, reset sieci, kolejka drukarki, ikony i miniatury, Eksplorator, zegar, sprawdzenie dysku, plany zasilania, Sklep.
- **Instalacja:** ponad 30 programów przez winget (oficjalne repozytorium Microsoft), pakiety („Podstawowy zestaw”, „Biuro”, „Gracz”, „Diagnostyka”) i aktualizacja wszystkich programów.
- **Sprzęt:** dyski (zdrowie, zużycie SSD, temperatura, HDD jako systemowy), RAM i wolne sloty, bateria, karta graficzna, urządzenia bez sterowników, aktywacja, klucz Windows z BIOS, czas uruchamiania.
- **Bezpieczeństwo:** antywirus, zapora, aktualizacje, UAC, RDP, SMBv1, Secure Boot, TPM, BitLocker, konta. Do tego szybkie naprawy.
- **Przed reinstalacją:** kopia sterowników, listy programów, informacji o komputerze z kluczem Windows, zakładek przeglądarek i danych użytkownika (Pulpit, Dokumenty, Obrazy, Pobrane, Muzyka, Wideo, także z OneDrive) wybranego konta na pendrive.

We wszystkich zakładkach można sortować, klikając nagłówek kolumny. Pasek na dole pokazuje, ile pozycji jest zaznaczonych. Okno dopasowuje się do małych ekranów laptopów.

Programy pobiera tylko zakładka Instalacja, i to dopiero po kliknięciu. Kopie ustawień, log i lista wykonanych prac są w `C:\ProgramData\UslugiKopia`.

Nazwę serwisu, telefon i link do opinii Google ustawia się na początku pliku `uslugi.ps1` (`$NazwaSerwisu`, `$TelefonSerwisu`, `$LinkOpinii`).
