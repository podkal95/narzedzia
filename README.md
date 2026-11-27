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
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-44/uslugi.ps1 | iex
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-43/uslugi.ps1 | iex
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-42/uslugi.ps1 | iex
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-41/uslugi.ps1 | iex
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-4/uslugi.ps1 | iex
irm https://raw.githubusercontent.com/podkal95/narzedzia/wersja-3/uslugi.ps1 | iex
```

## Wygląd i konto klienta

- Program otwiera się jako osobna aplikacja z logo (własna ikona na pasku zadań), bez okna PowerShella. Menu z sekcjami jest po lewej, a obraz jest ostry przy skalowaniu 125–150%.
- Jeśli uprawnienia potwierdzisz innym kontem administratora, program sam wykrywa konto osoby siedzącej przy komputerze. Ustawienia użytkownika, autostart, raport (na jej pulpicie) i kopia danych dotyczą tego konta. W zakładce „Przed reinstalacją” można też wybrać dowolne inne konto.

## Na górnym pasku

- **Serwis ekspresowy:** jednym kliknięciem wyłącza bezpieczne usługi, czyści dysk, ustawia zalecane opcje Windows, opcjonalnie usuwa zbędne aplikacje i naprawia pliki systemu (DISM + SFC), a na koniec robi raport.
- **Raport dla klienta:** strona HTML na pulpicie z wykonanymi pracami, zaleceniami (np. wymiana dysku na SSD, rozbudowa RAM, zużyta bateria), stanem zabezpieczeń i czasem uruchamiania przed i po serwisie. Przycisk na stronie zapisuje ją jako PDF.
- **Pomoc zdalna:** uruchamia Szybką pomoc Windows.

## Zakładki

- **Usługi:** ponad 70 usług w kategoriach, z opisem tego, co przestanie działać. Na starcie nic nie jest zaznaczone. Gotowe pakiety (np. „Bez Xbox”, „Bez drukarki i skanera”, „Słabszy komputer”, „Wszystkie zalecane”) zaznaczają pasujące usługi jednym kliknięciem. Przed zmianą robi punkt przywracania i kopię ustawień, a zmiany da się cofnąć.
- **Autostart:** włączanie i wyłączanie programów startujących z Windows, tak jak w Menedżerze zadań.
- **Programy w tle:** co działa, ile zajmuje pamięci, zamykanie programów, blokada aplikacji ze Sklepu w tle.
- **Aplikacje i Office:** usuwanie zbędnych aplikacji ze Sklepu (Candy Crush, Porady, Cortana, Skype, Xbox...) z pakietami. Do tego lista zainstalowanych pakietów Office (Microsoft 365, Office 2013–2024, wersje Click-to-Run i MSI): zaznaczasz kilka, a program usuwa je po kolei, po cichu.
- **Ustawienia:** bez reklam i sugestii, bez Binga w menu Start, Recall, Copilota i widżetów, rozszerzenia plików, klasyczne menu, hibernacja, szybkie uruchamianie, plan zasilania. Każde da się cofnąć.
- **Czyszczenie:** pliki tymczasowe, cache aktualizacji, kosz, przeglądarki, DISM. Pokazuje, ile miejsca zwolniono. Okno **Największe foldery** pokazuje, co zajmuje miejsce.
- **Naprawy:** DISM, SFC, reset Windows Update, reset sieci, kolejka drukarki, ikony i miniatury, Eksplorator, zegar, sprawdzenie dysku, plany zasilania, Sklep.
- **Instalacja:** ponad 30 programów przez winget (oficjalne repozytorium Microsoft), pakiety („Podstawowy zestaw”, „Biuro”, „Gracz”, „Diagnostyka”) i aktualizacja wszystkich programów. **„Wybierz wersję”** (albo dwuklik) pokazuje wszystkie wersje programu z repozytorium i instaluje wybraną, także starszą (z opcją odinstalowania obecnej).
- **Sprzęt:** dyski (zdrowie, zużycie SSD, temperatura, HDD jako systemowy), RAM i wolne sloty, bateria, karta graficzna, urządzenia bez sterowników, aktywacja, klucz Windows z BIOS, czas uruchamiania.
- **Sterowniki i BIOS:** zainstalowane sterowniki podzespołów (karta graficzna, sieć, dźwięk, chipset...) i wersja BIOS. „Sprawdź aktualizacje” pyta Windows Update o nowsze sterowniki i firmware, a to, czego tam nie ma, od razu sprawdza na stronie producenta. Przy każdym urządzeniu pisze, czy producent ma nowszy sterownik lub BIOS. Zaznaczone aktualizacje z Windows Update instaluje. **„Wybierz wersję”** (albo dwuklik) pokazuje wszystkie wersje sterownika z katalogu Microsoft Update i instaluje wybraną, także starszą.
  - **„Szukaj u producenta”** (albo dwuklik na wierszu BIOS) sam rozpoznaje płytę lub laptopa i pobiera listę BIOS-ów i sterowników prosto z serwera producenta: **MSI, Gigabyte, ASUS, Lenovo**. Pokazuje wersje, daty, rozmiary i to, co jest nowsze od zainstalowanego (także wersje beta i starsze). Gdy model nie zostanie rozpoznany, można go wpisać („Wpisz model...”).
  - MSI i Gigabyte nie wpuszczają zwykłych programów. Wtedy program otwiera ich stronę w przeglądarce Edge bez okna (a gdy to nie wystarczy, w oknie schowanym poza ekranem) i stamtąd pobiera listę i pliki, tak jak zrobiłby to człowiek. Dziennik na dole pokazuje każdą próbę.
  - Zaznaczone pliki pobiera, sprawdza sumę kontrolną podaną przez producenta i rozpakowuje (gdy trzeba, sam doinstaluje darmowego 7-Zip). Sterowniki instaluje po cichu (pnputil) albo instalatorem producenta. Pakiety Lenovo instaluje tak jak Lenovo System Update.
  - BIOS płyt głównych (MSI, Gigabyte, ASUS) kopiuje na pendrive i może od razu uruchomić komputer ponownie prosto do BIOS-u. Dalej zostaje M-Flash, Q-Flash albo EZ Flash, z instrukcją w okienku. Laptopy: uruchamia program producenta do aktualizacji BIOS-u.
  - „Tylko pobierz” zapisuje pliki w folderze Pobrane klienta. Dell i HP: „Narzędzie producenta” instaluje i uruchamia Dell Command Update albo HP Support Assistant (jest też Lenovo System Update i Intel DSA).
- **Bezpieczeństwo:** antywirus, zapora, aktualizacje, UAC, RDP, SMBv1, Secure Boot, TPM, BitLocker, konta. Do tego szybkie naprawy.
- **Przed reinstalacją:** kopia sterowników, listy programów, informacji o komputerze z kluczem Windows, zakładek przeglądarek i danych użytkownika (Pulpit, Dokumenty, Obrazy, Pobrane, Muzyka, Wideo, także z OneDrive) wybranego konta na pendrive.

We wszystkich zakładkach można sortować, klikając nagłówek kolumny. Pasek na dole pokazuje, ile pozycji jest zaznaczonych. Okno dopasowuje się do małych ekranów laptopów.

Programy, sterowniki i BIOS są pobierane tylko z oficjalnych źródeł (winget, Windows Update, katalog Microsoft, serwery producentów) i dopiero po kliknięciu. Kopie ustawień, log i lista wykonanych prac są w `C:\ProgramData\UslugiKopia`.

Domyślnie program i raport nie pokazują żadnej nazwy firmy. Nazwę, telefon i link do opinii Google można ustawić na początku pliku `uslugi.ps1` (`$NazwaSerwisu`, `$TelefonSerwisu`, `$LinkOpinii`).
