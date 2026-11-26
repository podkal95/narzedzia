<#
    Narzedzia serwisowe Windows 10/11 (okienko, po polsku)
    Uruchomienie:  irm https://raw.githubusercontent.com/podkal95/narzedzia/main/uslugi.ps1 | iex

    Zakladki:
      Uslugi         - wylaczanie zbednych uslug (Wylaczony / Reczny), kopia + punkt przywracania, cofanie
      Autostart      - programy uruchamiane z systemem: wlacz / wylacz (tak jak Menedzer zadan, odwracalne)
      Programy w tle - co teraz dziala i ile zajmuje pamieci, zamykanie, blokada aplikacji w tle
      Czyszczenie    - pliki tymczasowe, cache aktualizacji, kosz, przegladarki, DISM; ile miejsca zwolniono
      Bezpieczenstwo - antywirus, zapora, aktualizacje, UAC, RDP, SMBv1, Secure Boot, TPM, BitLocker, konta
                       + szybkie naprawy i raport dla klienta na pulpicie

    Nic nie pobiera i nie instaluje. Kopie i log: C:\ProgramData\UslugiKopia
#>

$AdresSkryptu = 'https://raw.githubusercontent.com/podkal95/narzedzia/main/uslugi.ps1'

# ---------- uruchomienie jako administrator ----------
$czyAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $czyAdmin) {
    if ($PSCommandPath) {
        $polecenie = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } else {
        $polecenie = "-NoProfile -ExecutionPolicy Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm '$AdresSkryptu' | iex`""
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Minimized -ArgumentList $polecenie
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$folderKopii = Join-Path $env:ProgramData 'UslugiKopia'
New-Item -ItemType Directory -Force -Path $folderKopii | Out-Null
$plikLogu = Join-Path $folderKopii ('log_{0:yyyyMMdd}.txt' -f (Get-Date))
$NL = [Environment]::NewLine
$stan = @{ Zaladowane = @{}; Bezpieczenstwo = @() }

# =====================================================================
#  DANE: USLUGI
# =====================================================================
function Nowa-Usluga($nazwa, $kategoria, $etykieta, $opis, $rodzaj, $domyslnie) {
    [pscustomobject]@{ Nazwa = $nazwa; Kategoria = $kategoria; Etykieta = $etykieta; Opis = $opis; Rodzaj = $rodzaj; Domyslnie = $domyslnie }
}
# Rodzaj: Zalecane = bezpieczne prawie zawsze; Opcjonalne = tylko gdy klient z tego nie korzysta.
# Domyslnie = typ uruchamiania w czystym Windows (do przycisku "Przywróć domyślne"); usług, których dany Windows nie ma, nie widać.
$listaUslug = @(
    # --- Telemetria ---
    Nowa-Usluga 'DiagTrack'        'Telemetria' 'Telemetria Microsoft'            'Wysyła dane diagnostyczne i o użytkowaniu do Microsoft. Bez wpływu na działanie komputera.' 'Zalecane' 'auto'
    Nowa-Usluga 'dmwappushservice' 'Telemetria' 'WAP Push (telemetria)'           'Przekazuje komunikaty telemetrii i zarządzania. NIE wyłączaj na komputerach firmowych zarządzanych przez Intune.' 'Zalecane' 'demand'
    Nowa-Usluga 'InventorySvc'     'Telemetria' 'Inwentaryzacja zgodności'        'Zbiera dla Microsoft listę programów i ocenę zgodności z nowszym Windows.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'PcaSvc'           'Telemetria' 'Asystent zgodności programów'    'Podpowiada ustawienia zgodności dla starych programów. Bez niego tych podpowiedzi nie będzie.' 'Opcjonalne' 'auto'

    # --- Diagnostyka ---
    Nowa-Usluga 'diagnosticshub.standardcollector.service' 'Diagnostyka' 'Diagnostics Hub' 'Zbiera diagnostykę dla Visual Studio. Potrzebne tylko programistom.' 'Zalecane' 'demand'
    Nowa-Usluga 'WerSvc'           'Diagnostyka' 'Raportowanie błędów Windows'   'Wysyła raporty o awariach programów do Microsoft.' 'Zalecane' 'demand'
    Nowa-Usluga 'wercplsupport'    'Diagnostyka' 'Panel raportów problemów'      'Pokazuje historię raportów o problemach w Panelu sterowania.' 'Zalecane' 'demand'
    Nowa-Usluga 'DPS'              'Diagnostyka' 'Zasady diagnostyki'            'Wykrywa problemy i uruchamia narzędzia do rozwiązywania problemów (np. z siecią). Bez niej te narzędzia nie zadziałają.' 'Opcjonalne' 'auto'
    Nowa-Usluga 'WdiServiceHost'   'Diagnostyka' 'Host usługi diagnostyki'       'Pomocnicza usługa diagnostyki Windows (współpracuje z Zasadami diagnostyki).' 'Opcjonalne' 'demand'
    Nowa-Usluga 'WdiSystemHost'    'Diagnostyka' 'Host systemu diagnostyki'      'Pomocnicza usługa diagnostyki Windows (współpracuje z Zasadami diagnostyki).' 'Opcjonalne' 'demand'
    Nowa-Usluga 'TroubleshootingSvc' 'Diagnostyka' 'Zalecane rozwiązywanie problemów' 'Automatycznie proponuje poprawki znanych problemów Windows.' 'Opcjonalne' 'demand'

    # --- Gry (Xbox) ---
    Nowa-Usluga 'XblAuthManager'   'Gry (Xbox)' 'Xbox - logowanie'              'Przestanie działać logowanie do Xbox / Game Pass i część gier ze Sklepu.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'XblGameSave'      'Gry (Xbox)' 'Xbox - zapisy w chmurze'       'Zapisy gier Xbox nie będą synchronizowane.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'XboxNetApiSvc'    'Gry (Xbox)' 'Xbox - sieć'                   'Gry sieciowe przez Xbox Live mogą nie działać.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'XboxGipSvc'       'Gry (Xbox)' 'Xbox - akcesoria'              'Brak aktualizacji i konfiguracji padów Xbox.' 'Opcjonalne' 'demand'

    # --- Drukarki i skanery ---
    Nowa-Usluga 'Fax'              'Drukarki i skanery' 'Faks'                  'Wysyłanie i odbieranie faksów.' 'Zalecane' 'demand'
    Nowa-Usluga 'Spooler'          'Drukarki i skanery' 'Bufor wydruku'         'Przestaną działać WSZYSTKIE drukarki oraz "Microsoft Print to PDF".' 'Opcjonalne' 'auto'
    Nowa-Usluga 'PrintNotify'      'Drukarki i skanery' 'Powiadomienia drukarek' 'Brak powiadomień i rozszerzeń sterowników drukarek.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'StiSvc'           'Drukarki i skanery' 'Pozyskiwanie obrazów (WIA)' 'Obsługa skanerów i aparatów. Przestaną działać skanery!' 'Opcjonalne' 'demand'
    Nowa-Usluga 'WiaRpc'           'Drukarki i skanery' 'Zdarzenia skanerów i aparatów' 'Uruchamia programy po podłączeniu aparatu lub skanera.' 'Opcjonalne' 'demand'

    # --- Siec i udostepnianie ---
    Nowa-Usluga 'lltdsvc'          'Sieć' 'Mapa sieci (LLTD)'                    'Rysuje mapę sieci w Panelu sterowania. Rzadko używane.' 'Zalecane' 'demand'
    Nowa-Usluga 'SNMPTRAP'         'Sieć' 'Pułapka SNMP'                         'Odbiera komunikaty SNMP z urządzeń sieciowych. W domu nieużywane.' 'Zalecane' 'demand'
    Nowa-Usluga 'MSiSCSI'          'Sieć' 'Inicjator iSCSI'                      'Podłączanie dysków sieciowych iSCSI (serwerownie). W domu nieużywane.' 'Zalecane' 'demand'
    Nowa-Usluga 'LanmanServer'     'Sieć' 'Serwer (udostępnianie plików)'        'Udostępnianie folderów i drukarek z TEGO komputera innym. Jeśli nic nie udostępnia, wyłączenie podnosi bezpieczeństwo.' 'Opcjonalne' 'auto'
    Nowa-Usluga 'FDResPub'         'Sieć' 'Widoczność w sieci lokalnej'          'Sprawia, że komputer jest widoczny dla innych w sieci (Eksplorator > Sieć).' 'Opcjonalne' 'demand'
    Nowa-Usluga 'fdPHost'          'Sieć' 'Wyszukiwanie urządzeń w sieci'        'Wyszukuje komputery i urządzenia w sieci lokalnej.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SSDPSRV'          'Sieć' 'Odnajdowanie SSDP (UPnP)'             'Wykrywa telewizory, drukarki sieciowe i serwery DLNA.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'upnphost'         'Sieć' 'Host urządzeń UPnP'                   'Udostępnia urządzenia UPnP z tego komputera.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'lmhosts'          'Sieć' 'Pomocnik NetBIOS'                     'Stary mechanizm nazw w sieci Windows. Może być potrzebny do starszych NAS-ów i dysków sieciowych.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SharedAccess'     'Sieć' 'Udostępnianie internetu (ICS)'        'Udostępnianie internetu z tego komputera innym urządzeniom.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'icssvc'           'Sieć' 'Mobilny hotspot'                      'Nie da się udostępnić internetu z tego komputera jako hotspot Wi-Fi.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'iphlpsvc'         'Sieć' 'Pomocnik IP (IPv6)'                   'Tunelowanie IPv6 (Teredo i inne). Wyłączenie może zepsuć niektóre VPN-y i gry sieciowe Xbox.' 'Opcjonalne' 'auto'
    Nowa-Usluga 'WebClient'        'Sieć' 'Klient WebDAV'                        'Dyski internetowe przez WebDAV (np. SharePoint). Często wykorzystywany w atakach - wyłącz, jeśli nieużywany.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'QWAVE'            'Sieć' 'Jakość audio-wideo w sieci (qWave)'   'Priorytet dla strumieni audio i wideo w sieci domowej. Rzadko używane.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'WFDSConMgrSvc'    'Sieć' 'Wi-Fi Direct'                         'Połączenia Wi-Fi Direct: niektóre drukarki i bezprzewodowe wyświetlacze.' 'Opcjonalne' 'demand'

    # --- Zdalny dostep ---
    Nowa-Usluga 'RemoteRegistry'   'Zdalny dostęp' 'Zdalny rejestr'              'Pozwala zmieniać rejestr przez sieć. Ryzyko bezpieczeństwa.' 'Zalecane' 'disabled'
    Nowa-Usluga 'TermService'      'Zdalny dostęp' 'Pulpit zdalny (RDP)'         'Nikt nie połączy się z tym komputerem przez Pulpit zdalny.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SessionEnv'       'Zdalny dostęp' 'Konfiguracja Pulpitu zdalnego' 'Pomocnicza usługa Pulpitu zdalnego.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'UmRdpService'     'Zdalny dostęp' 'Przekierowania Pulpitu zdalnego' 'Drukarki i dyski w sesjach Pulpitu zdalnego.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'WinRM'            'Zdalny dostęp' 'Zdalne zarządzanie (WinRM)'  'Zdalne polecenia PowerShell. W domu zbędne; w firmie może być używane przez dział IT.' 'Opcjonalne' 'demand'

    # --- Urzadzenia ---
    Nowa-Usluga 'bthserv'          'Urządzenia' 'Bluetooth'                     'Przestaną działać słuchawki, myszki i inne urządzenia Bluetooth.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'BthAvctpSvc'      'Urządzenia' 'Bluetooth - sterowanie audio'  'Przyciski i sterowanie odtwarzaniem w słuchawkach Bluetooth.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'WbioSrvc'         'Urządzenia' 'Biometria (Windows Hello)'     'Logowanie odciskiem palca i twarzą przestanie działać.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SCardSvr'         'Urządzenia' 'Karty inteligentne'            'Czytniki kart: e-dowód, podpis kwalifikowany i karty firmowe przestaną działać!' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SensorService'    'Urządzenia' 'Czujniki'                      'Obracanie ekranu i automatyczna jasność w laptopach i tabletach. Na komputerze stacjonarnym zbędne.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SensrSvc'         'Urządzenia' 'Monitorowanie czujników'       'Jak wyżej - czujniki w laptopach i tabletach.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SensorDataService' 'Urządzenia' 'Dane czujników'               'Jak wyżej - czujniki w laptopach i tabletach.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'WwanSvc'          'Urządzenia' 'Modem komórkowy (LTE/5G)'      'Wbudowany modem komórkowy w laptopie przestanie działać.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'wlpasvc'          'Urządzenia' 'Profile eSIM'                  'Obsługa kart eSIM w laptopach z modemem.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SEMgrSvc'         'Urządzenia' 'Płatności i NFC'               'Płatności zbliżeniowe NFC w urządzeniu. W komputerach praktycznie nieużywane.' 'Zalecane' 'demand'
    Nowa-Usluga 'NaturalAuthentication' 'Urządzenia' 'Blokada dynamiczna'       'Automatyczne blokowanie komputera, gdy sparowany telefon się oddali.' 'Opcjonalne' 'demand'

    # --- Telefon ---
    Nowa-Usluga 'PhoneSvc'         'Telefon' 'Usługa telefonu'                  'Stan telefonii: Łącze z telefonem, połączenia VoIP.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'SmsRouter'        'Telefon' 'Router SMS'                       'SMS-y w aplikacji Łącze z telefonem.' 'Opcjonalne' 'demand'
    Nowa-Usluga 'autotimesvc'      'Telefon' 'Czas z sieci komórkowej'          'Ustawia czas na podstawie sieci komórkowej (laptopy z modemem).' 'Opcjonalne' 'demand'

    # --- Mixed Reality / VR ---
    Nowa-Usluga 'spectrum'         'Mixed Reality' 'Windows Perception'         'Obsługa gogli Windows Mixed Reality.' 'Zalecane' 'demand'
    Nowa-Usluga 'perceptionsimulation' 'Mixed Reality' 'Symulacja Perception'   'Symulator Mixed Reality dla programistów.' 'Zalecane' 'demand'
    Nowa-Usluga 'MixedRealityOpenXRSvc' 'Mixed Reality' 'Mixed Reality OpenXR'  'Gogle Windows Mixed Reality w OpenXR (nie dotyczy gogli Meta/Valve na SteamVR).' 'Zalecane' 'demand'
    Nowa-Usluga 'SharedRealitySvc' 'Mixed Reality' 'Dane przestrzenne'          'Dane przestrzenne dla Mixed Reality.' 'Zalecane' 'demand'

    # --- Lokalizacja i mapy ---
    Nowa-Usluga 'MapsBroker'       'Lokalizacja i mapy' 'Mapy offline'          'Pobiera i aktualizuje mapy dla aplikacji Mapy.' 'Zalecane' 'delayed-auto'
    Nowa-Usluga 'lfsvc'            'Lokalizacja i mapy' 'Lokalizacja'           'Pogoda, mapy i "Znajdź moje urządzenie" nie ustalą położenia.' 'Opcjonalne' 'demand'

    # --- Wydajnosc ---
    Nowa-Usluga 'WSearch'          'Wydajność' 'Indeksowanie wyszukiwania'       'Wyszukiwanie w menu Start, Eksploratorze i Outlooku będzie wolniejsze.' 'Opcjonalne' 'delayed-auto'
    Nowa-Usluga 'SysMain'          'Wydajność' 'SysMain (Superfetch)'            'Wstępne ładowanie programów. Na SSD zwykle zbędne, na HDD lepiej zostawić.' 'Opcjonalne' 'auto'
    Nowa-Usluga 'TrkWks'           'Wydajność' 'Śledzenie łączy rozproszonych'   'Naprawia skróty do plików przeniesionych w sieci firmowej. W domu zbędne.' 'Opcjonalne' 'auto'

    # --- Firmowe ---
    Nowa-Usluga 'workfolderssvc'   'Firmowe' 'Foldery robocze'                  'Synchronizacja z firmowym serwerem plików. W domu nieużywane.' 'Zalecane' 'demand'
    Nowa-Usluga 'Wecsvc'           'Firmowe' 'Zbieranie zdarzeń'                'Zbiera dzienniki zdarzeń z innych komputerów (firmowe serwery).' 'Zalecane' 'demand'
    Nowa-Usluga 'CscService'       'Firmowe' 'Pliki trybu offline'              'Kopie offline plików z firmowych udziałów sieciowych.' 'Opcjonalne' 'demand'

    # --- Inne ---
    Nowa-Usluga 'RetailDemo'       'Inne' 'Tryb demo sklepu'                    'Tryb pokazowy dla komputerów wystawionych w sklepie.' 'Zalecane' 'demand'
    Nowa-Usluga 'wisvc'            'Inne' 'Windows Insider'                     'Obsługa testowych wersji Windows.' 'Zalecane' 'demand'
    Nowa-Usluga 'AJRouter'         'Inne' 'AllJoyn Router'                      'Komunikacja z urządzeniami IoT (praktycznie nieużywana).' 'Zalecane' 'demand'
    Nowa-Usluga 'WMPNetworkSvc'    'Inne' 'Udostępnianie Windows Media Player'  'Udostępnia bibliotekę multimediów innym urządzeniom w sieci.' 'Zalecane' 'demand'
    Nowa-Usluga 'AxInstSV'         'Inne' 'Instalator ActiveX'                  'Instalowanie kontrolek ActiveX ze stron (przestarzałe).' 'Zalecane' 'demand'
    Nowa-Usluga 'WalletService'    'Inne' 'Portfel Windows'                     'Usługa portfela, nieużywana przez zwykłe programy.' 'Zalecane' 'demand'
    Nowa-Usluga 'WpcMonSvc'        'Inne' 'Kontrola rodzicielska'               'Nie wyłączaj, jeśli dzieci mają konta w Microsoft Family.' 'Opcjonalne' 'demand'
)

# =====================================================================
#  DANE: CZYSZCZENIE
# =====================================================================
function Nowa-Pozycja($etykieta, $opis, $zaznacz, $sciezki, $akcja) {
    [pscustomobject]@{ Etykieta = $etykieta; Opis = $opis; Zaznacz = $zaznacz; Sciezki = $sciezki; Akcja = $akcja }
}
$listaCzyszczenia = @(
    Nowa-Pozycja 'Pliki tymczasowe (użytkownicy)' 'Folder Temp wszystkich kont. Pliki w użyciu zostaną pominięte.' $true @('C:\Users\*\AppData\Local\Temp\*') $null
    Nowa-Pozycja 'Pliki tymczasowe Windows' 'Folder C:\Windows\Temp.' $true @('C:\Windows\Temp\*') $null
    Nowa-Pozycja 'Pamięć podręczna Windows Update' 'Pobrane już pliki aktualizacji. Windows pobierze je ponownie, jeśli będą potrzebne.' $true @('C:\Windows\SoftwareDistribution\Download\*') {
        param($sciezki)
        Stop-Service -Name 'wuauserv', 'bits' -Force -ErrorAction SilentlyContinue
        Usun-Sciezki $sciezki
        Start-Service -Name 'bits', 'wuauserv' -ErrorAction SilentlyContinue
    }
    Nowa-Pozycja 'Optymalizacja dostarczania' 'Kopie aktualizacji udostępniane innym komputerom.' $true @('C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*') {
        param($sciezki)
        if (Get-Command -Name 'Delete-DeliveryOptimizationCache' -ErrorAction SilentlyContinue) {
            Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue
        } else {
            Usun-Sciezki $sciezki
        }
    }
    Nowa-Pozycja 'Raporty błędów Windows' 'Zapisane raporty o awariach programów.' $true @(
        'C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*',
        'C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*',
        'C:\ProgramData\Microsoft\Windows\WER\Temp\*') $null
    Nowa-Pozycja 'Kosz' 'Opróżnia kosz na wszystkich dyskach. Zapytaj klienta, czy niczego tam nie potrzebuje!' $false @('C:\$Recycle.Bin\*') {
        param($sciezki)
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
    Nowa-Pozycja 'Pamięć podręczna przeglądarek' 'Cache Chrome, Edge i Firefoksa. Nie usuwa haseł, historii ani zakładek. Zamknij przeglądarki.' $false @(
        'C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Cache\*',
        'C:\Users\*\AppData\Local\Google\Chrome\User Data\*\Code Cache\*',
        'C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Cache\*',
        'C:\Users\*\AppData\Local\Microsoft\Edge\User Data\*\Code Cache\*',
        'C:\Users\*\AppData\Local\Mozilla\Firefox\Profiles\*\cache2\*') $null
    Nowa-Pozycja 'Zrzuty pamięci (BSOD)' 'Pliki po niebieskich ekranach. Najpierw je sprawdź, jeśli diagnozujesz awarie.' $false @(
        'C:\Windows\Minidump\*',
        'C:\Windows\MEMORY.DMP') $null
    Nowa-Pozycja 'Stare składniki aktualizacji (DISM)' 'Usuwa stare wersje składników Windows. Trwa kilka do kilkunastu minut; rozmiaru nie da się policzyć wcześniej.' $false @() {
        param($sciezki)
        $proc = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup' -WindowStyle Hidden -PassThru
        while (-not $proc.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 300
        }
        Log ('  DISM zakończony, kod: ' + $proc.ExitCode)
    }
)

# =====================================================================
#  FUNKCJE OGOLNE
# =====================================================================
function Log([string]$tekst) {
    $linia = '{0:HH:mm:ss}  {1}' -f (Get-Date), $tekst
    $logBox.AppendText($linia + $NL)
    Add-Content -LiteralPath $plikLogu -Value $linia -Encoding UTF8
    [System.Windows.Forms.Application]::DoEvents()
}

function Pytanie([string]$tekst) {
    [System.Windows.Forms.MessageBox]::Show($tekst, 'Potwierdź', 'YesNo', 'Question') -eq 'Yes'
}

function Info([string]$tekst) {
    [void][System.Windows.Forms.MessageBox]::Show($tekst, 'Informacja', 'OK', 'Information')
}

function Zajety([bool]$tak) {
    $zakladki.Enabled = -not $tak
    if ($tak) { $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor }
    else { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
    [System.Windows.Forms.Application]::DoEvents()
}

function Tekst-Rozmiaru([long]$bajty) {
    if ($bajty -ge 1GB) { return ('{0:N2} GB' -f ($bajty / 1GB)) }
    if ($bajty -ge 1MB) { return ('{0:N0} MB' -f ($bajty / 1MB)) }
    if ($bajty -gt 0)   { return ('{0:N0} KB' -f [math]::Ceiling($bajty / 1KB)) }
    '0 MB'
}

function Nowa-Siatka {
    $g = New-Object System.Windows.Forms.DataGridView
    $g.Dock = 'Fill'
    $g.AllowUserToAddRows = $false
    $g.AllowUserToDeleteRows = $false
    $g.AllowUserToResizeRows = $false
    $g.RowHeadersVisible = $false
    $g.SelectionMode = 'FullRowSelect'
    $g.MultiSelect = $false
    $g.AutoSizeRowsMode = 'AllCells'
    $g.BackgroundColor = [System.Drawing.Color]::White
    $g.BorderStyle = 'None'
    $g.DefaultCellStyle.WrapMode = 'True'
    $g.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(4)
    $g.ColumnHeadersHeightSizeMode = 'AutoSize'
    $g.Add_CurrentCellDirtyStateChanged({
        param($nadawca, $zdarzenie)
        if ($nadawca.IsCurrentCellDirty) {
            [void]$nadawca.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })
    $g
}

function Dodaj-Kolumne($siatka, [string]$typ, [string]$tytul, [int]$szerokosc) {
    if ($typ -eq 'Check') { $c = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn }
    else { $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c.ReadOnly = $true }
    $c.HeaderText = $tytul
    $c.SortMode = 'NotSortable'
    if ($szerokosc -gt 0) { $c.Width = $szerokosc } else { $c.AutoSizeMode = 'Fill' }
    [void]$siatka.Columns.Add($c)
}

function Nowy-PanelPrzyciskow {
    $p = New-Object System.Windows.Forms.FlowLayoutPanel
    $p.Dock = 'Bottom'
    $p.AutoSize = $true
    $p.AutoSizeMode = 'GrowAndShrink'
    $p.WrapContents = $true
    $p.Padding = New-Object System.Windows.Forms.Padding(6, 8, 6, 4)
    $p
}

function Nowy-Przycisk($panel, [string]$tekst, [bool]$glowny) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $tekst
    $b.AutoSize = $true
    $b.Height = 34
    $b.Padding = New-Object System.Windows.Forms.Padding(8, 0, 8, 0)
    if ($glowny) {
        $b.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
        $b.BackColor = [System.Drawing.Color]::FromArgb(255, 122, 26)
        $b.ForeColor = [System.Drawing.Color]::Black
        $b.FlatStyle = 'Flat'
    }
    [void]$panel.Controls.Add($b)
    $b
}

function Nowy-Naglowek([string]$tekst) {
    $l = New-Object System.Windows.Forms.Label
    $l.Dock = 'Top'
    $l.Height = 56
    $l.Padding = New-Object System.Windows.Forms.Padding(8, 8, 8, 4)
    $l.Text = $tekst
    $l
}

function Nowa-Zakladka([string]$tytul, $siatka, [string]$naglowek, $panel) {
    $t = New-Object System.Windows.Forms.TabPage
    $t.Text = $tytul
    $t.Controls.Add($siatka)
    $t.Controls.Add((Nowy-Naglowek $naglowek))
    $t.Controls.Add($panel)
    [void]$zakladki.TabPages.Add($t)
    $t
}

function Zaznaczone($siatka) {
    [void]$siatka.EndEdit()
    @(foreach ($r in $siatka.Rows) { if ($r.Cells[0].Value -eq $true) { $r.Tag } })
}

function Odznacz-Wszystko($siatka) {
    foreach ($r in $siatka.Rows) { $r.Cells[0].Value = $false }
}

function Kolor([string]$nazwa) {
    switch ($nazwa) {
        'OK'    { [System.Drawing.Color]::ForestGreen }
        'UWAGA' { [System.Drawing.Color]::DarkOrange }
        'ŹLE'   { [System.Drawing.Color]::Firebrick }
        'INFO'  { [System.Drawing.Color]::SteelBlue }
        'Wyłączony' { [System.Drawing.Color]::Gray }
        default { [System.Drawing.Color]::Black }
    }
}

# =====================================================================
#  FUNKCJE: USLUGI
# =====================================================================
function Get-StartInfo([string]$nazwa) {
    $klucz = "HKLM:\SYSTEM\CurrentControlSet\Services\$nazwa"
    if (-not (Test-Path -LiteralPath $klucz)) { return $null }
    $p = Get-ItemProperty -LiteralPath $klucz -ErrorAction SilentlyContinue
    if (-not $p) { return $null }
    $opozniony = 0
    if ($p.PSObject.Properties['DelayedAutostart']) { $opozniony = [int]$p.DelayedAutostart }
    [pscustomobject]@{ Start = [int]$p.Start; Delayed = $opozniony }
}

function Opis-Startu([int]$start, [int]$opozniony) {
    switch ($start) {
        2       { if ($opozniony -eq 1) { 'Automatyczny (opóźniony)' } else { 'Automatyczny' } }
        3       { 'Ręczny' }
        4       { 'Wyłączony' }
        default { "Inny ($start)" }
    }
}

function Stan-PL($status) {
    switch ([string]$status) {
        'Running' { 'Działa' }
        'Stopped' { 'Zatrzymana' }
        default   { [string]$status }
    }
}

function Typ-Z-Kopii($start, $opozniony) {
    switch ([int]$start) {
        2       { if ([int]$opozniony -eq 1) { 'delayed-auto' } else { 'auto' } }
        3       { 'demand' }
        4       { 'disabled' }
        default { $null }
    }
}

function Ustaw-Start([string]$nazwa, [string]$typ) {
    $wynik = & sc.exe config $nazwa start= $typ 2>&1
    $kodWyjscia = $LASTEXITCODE
    [pscustomobject]@{ Ok = ($kodWyjscia -eq 0); Komunikat = ($wynik -join ' ') }
}

# =====================================================================
#  FUNKCJE: CZYSZCZENIE
# =====================================================================
function Rozmiar-Sciezek([string[]]$wzorce) {
    $suma = [long]0
    foreach ($w in $wzorce) {
        foreach ($el in @(Get-ChildItem -Path $w -Force -ErrorAction SilentlyContinue)) {
            if ($el.PSIsContainer) {
                $s = (Get-ChildItem -LiteralPath $el.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            } else {
                $s = $el.Length
            }
            if ($s) { $suma += [long]$s }
        }
    }
    $suma
}

function Usun-Sciezki([string[]]$wzorce) {
    foreach ($w in $wzorce) {
        foreach ($el in @(Get-ChildItem -Path $w -Force -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $el.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# =====================================================================
#  FUNKCJE: AUTOSTART
# =====================================================================
$kluczZatw = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'

function Czy-Wylaczony([string]$klucz, [string]$wartosc) {
    if (-not (Test-Path -LiteralPath $klucz)) { return $false }
    $v = (Get-Item -LiteralPath $klucz).GetValue($wartosc)
    if ($v -is [byte[]] -and $v.Length -gt 0) { return (($v[0] -band 1) -eq 1) }
    $false
}

function Pobierz-Autostart {
    $wynik = New-Object System.Collections.ArrayList
    $rejestr = @(
        @{ Klucz = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Zatw = "HKCU:\$kluczZatw\Run";   Miejsce = 'Rejestr (to konto)' }
        @{ Klucz = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Zatw = "HKLM:\$kluczZatw\Run";   Miejsce = 'Rejestr (wszyscy)' }
        @{ Klucz = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Zatw = "HKLM:\$kluczZatw\Run32"; Miejsce = 'Rejestr 32-bit (wszyscy)' }
    )
    foreach ($z in $rejestr) {
        if (-not (Test-Path -LiteralPath $z.Klucz)) { continue }
        $k = Get-Item -LiteralPath $z.Klucz
        foreach ($nazwa in $k.GetValueNames()) {
            if (-not $nazwa) { continue }
            [void]$wynik.Add([pscustomobject]@{
                Nazwa = $nazwa; Wartosc = $nazwa; Polecenie = [string]$k.GetValue($nazwa)
                Miejsce = $z.Miejsce; Zatw = $z.Zatw; Wylaczony = (Czy-Wylaczony $z.Zatw $nazwa)
            })
        }
    }
    $foldery = @(
        @{ Sciezka = [Environment]::GetFolderPath('Startup');       Zatw = "HKCU:\$kluczZatw\StartupFolder"; Miejsce = 'Folder Autostart (to konto)' }
        @{ Sciezka = [Environment]::GetFolderPath('CommonStartup'); Zatw = "HKLM:\$kluczZatw\StartupFolder"; Miejsce = 'Folder Autostart (wszyscy)' }
    )
    foreach ($f in $foldery) {
        if (-not $f.Sciezka -or -not (Test-Path -LiteralPath $f.Sciezka)) { continue }
        foreach ($plik in @(Get-ChildItem -LiteralPath $f.Sciezka -File -Force -ErrorAction SilentlyContinue)) {
            if ($plik.Name -eq 'desktop.ini') { continue }
            [void]$wynik.Add([pscustomobject]@{
                Nazwa = $plik.BaseName; Wartosc = $plik.Name; Polecenie = $plik.FullName
                Miejsce = $f.Miejsce; Zatw = $f.Zatw; Wylaczony = (Czy-Wylaczony $f.Zatw $plik.Name)
            })
        }
    }
    $wynik
}

function Ustaw-Autostart($el, [bool]$wlacz) {
    if (-not (Test-Path -LiteralPath $el.Zatw)) { New-Item -Path $el.Zatw -Force | Out-Null }
    $bajty = New-Object byte[] 12
    if ($wlacz) {
        $bajty[0] = 2
    } else {
        $bajty[0] = 3
        $czas = [BitConverter]::GetBytes((Get-Date).ToFileTime())
        [Array]::Copy($czas, 0, $bajty, 4, 8)
    }
    Set-ItemProperty -LiteralPath $el.Zatw -Name $el.Wartosc -Value $bajty -Type Binary
}

# =====================================================================
#  FUNKCJE: PROGRAMY W TLE
# =====================================================================
$chronione = @('powershell', 'pwsh', 'MsMpEng', 'NisSrv', 'SecurityHealthService', 'MpDefenderCoreService', 'smartscreen')
$kluczPolityki = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'

function Pobierz-Procesy {
    $windows = $env:windir
    $lista = @(Get-Process | Where-Object {
        $_.Id -ne $PID -and $_.Path -and
        (-not $_.Path.StartsWith($windows, [StringComparison]::OrdinalIgnoreCase)) -and
        ($chronione -notcontains $_.ProcessName)
    })
    $wynik = foreach ($g in ($lista | Group-Object -Property ProcessName)) {
        $pierwszy = $g.Group[0]
        $opis = ''
        try { $opis = [string]$pierwszy.Description } catch { }
        if (-not $opis) { try { $opis = [string]$pierwszy.Company } catch { } }
        $pamiec = ($g.Group | Measure-Object -Property WorkingSet64 -Sum).Sum
        $okna = @($g.Group | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero }).Count
        [pscustomobject]@{
            Nazwa = $g.Name; Opis = $opis; Liczba = $g.Count; Pamiec = [long]$pamiec
            Sciezka = $pierwszy.Path; Okno = ($okna -gt 0)
        }
    }
    @($wynik | Sort-Object -Property Pamiec -Descending)
}

function Czy-TloZablokowane {
    if (-not (Test-Path -LiteralPath $kluczPolityki)) { return $false }
    $v = (Get-Item -LiteralPath $kluczPolityki).GetValue('LetAppsRunInBackground')
    return ($v -eq 2)
}

# =====================================================================
#  FUNKCJE: BEZPIECZENSTWO
# =====================================================================
function Wynik-Sprawdzenia($nazwa, $wynik, $ocena, $rada) {
    [pscustomobject]@{ Nazwa = $nazwa; Wynik = $wynik; Ocena = $ocena; Rada = $rada }
}

function Sprawdz-Bezpieczenstwo {
    $wyniki = New-Object System.Collections.ArrayList
    $os = $null
    try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch { }

    # System
    try {
        $build = [int]$os.BuildNumber
        if ($build -lt 22000) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Wersja Windows' "$($os.Caption) (kompilacja $build)" 'ŹLE' 'Windows 10 nie ma już wsparcia Microsoft (od 14.10.2025). Zaproponuj Windows 11 lub nowszy sprzęt.'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Wersja Windows' "$($os.Caption) (kompilacja $build)" 'OK' ''))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Wersja Windows' 'nie udało się sprawdzić' 'UWAGA' '')) }

    # Antywirus (Centrum zabezpieczen)
    try {
        $av = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop)
        $aktywne = @($av | Where-Object { ([int]$_.productState -band 0x1000) -ne 0 })
        $stare = @($aktywne | Where-Object { ([int]$_.productState -band 0x10) -ne 0 })
        if ($aktywne.Count -eq 0) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Antywirus' 'brak aktywnego antywirusa' 'ŹLE' 'Włącz Microsoft Defender albo zainstalowany antywirus.'))
        } elseif ($stare.Count -gt 0) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Antywirus' (($aktywne.displayName) -join ', ') 'UWAGA' 'Bazy wirusów są nieaktualne - zaktualizuj.'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Antywirus' ((($aktywne.displayName) -join ', ') + ' - aktywny, aktualny') 'OK' ''))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Antywirus' 'nie udało się sprawdzić' 'UWAGA' '')) }

    # Defender
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $txt = 'ochrona w czasie rzeczywistym: ' + $(if ($mp.RealTimeProtectionEnabled) { 'włączona' } else { 'wyłączona' }) +
            "; bazy sprzed $($mp.AntivirusSignatureAge) dni; szybkie skanowanie: $($mp.QuickScanAge) dni temu"
        if (-not $mp.RealTimeProtectionEnabled) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Microsoft Defender' $txt 'INFO' 'Wyłączony - w porządku, jeśli działa inny antywirus (patrz wyżej).'))
        } elseif ($mp.AntivirusSignatureAge -gt 3) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Microsoft Defender' $txt 'UWAGA' 'Kliknij "Aktualizuj Defendera".'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Microsoft Defender' $txt 'OK' ''))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Microsoft Defender' 'niedostępny (prawdopodobnie inny antywirus)' 'INFO' '')) }

    # Zapora
    try {
        $profile = @(Get-NetFirewallProfile -ErrorAction Stop)
        $wylaczone = @($profile | Where-Object { -not $_.Enabled })
        $txt = ($profile | ForEach-Object { $_.Name + ': ' + $(if ($_.Enabled) { 'wł.' } else { 'WYŁ.' }) }) -join ', '
        if ($wylaczone.Count -gt 0) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Zapora Windows' $txt 'ŹLE' 'Kliknij "Włącz zaporę" (chyba że działa zapora z innego programu).'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Zapora Windows' $txt 'OK' ''))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Zapora Windows' 'nie udało się sprawdzić' 'UWAGA' '')) }

    # Aktualizacje
    try {
        $ostatnia = Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object -Property InstalledOn -Descending | Select-Object -First 1
        if ($ostatnia) {
            $dni = [int]((Get-Date) - $ostatnia.InstalledOn).TotalDays
            $txt = "ostatnia: $($ostatnia.HotFixID), $dni dni temu"
            if ($dni -gt 90) { $ocena = 'ŹLE' } elseif ($dni -gt 45) { $ocena = 'UWAGA' } else { $ocena = 'OK' }
            $rada = ''
            if ($ocena -ne 'OK') { $rada = 'Kliknij "Windows Update" i zainstaluj aktualizacje.' }
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Aktualizacje Windows' $txt $ocena $rada))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Aktualizacje Windows' 'brak danych' 'UWAGA' 'Sprawdź Windows Update ręcznie.'))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Aktualizacje Windows' 'nie udało się sprawdzić' 'UWAGA' '')) }

    # Restart
    try {
        $dniOdStartu = [int]((Get-Date) - $os.LastBootUpTime).TotalDays
        if ($dniOdStartu -gt 14) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Ostatni restart' "$dniOdStartu dni temu" 'UWAGA' 'Uruchom ponownie, żeby dokończyć aktualizacje.'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Ostatni restart' "$dniOdStartu dni temu" 'OK' ''))
        }
    } catch { }

    # UAC
    try {
        $sys = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop
        if ($sys.EnableLUA -ne 1) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Kontrola konta (UAC)' 'wyłączona' 'ŹLE' 'Włącz UAC: Panel sterowania > Konta użytkowników > Zmień ustawienia kontroli konta.'))
        } elseif ($sys.ConsentPromptBehaviorAdmin -eq 0) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Kontrola konta (UAC)' 'włączona, ale bez powiadomień' 'UWAGA' 'Ustaw poziom UAC na domyślny.'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Kontrola konta (UAC)' 'włączona' 'OK' ''))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Kontrola konta (UAC)' 'nie udało się sprawdzić' 'UWAGA' '')) }

    # Pulpit zdalny
    try {
        $ts = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction Stop
        if ($ts.fDenyTSConnections -eq 0) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Pulpit zdalny (RDP)' 'włączony' 'UWAGA' 'Wyłącz, jeśli klient go nie używa (Ustawienia > System > Pulpit zdalny).'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Pulpit zdalny (RDP)' 'wyłączony' 'OK' ''))
        }
    } catch { }

    # SMBv1
    try {
        $smb = Get-SmbServerConfiguration -ErrorAction Stop
        if ($smb.EnableSMB1Protocol) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Protokół SMBv1' 'włączony' 'ŹLE' 'Przestarzały i niebezpieczny (WannaCry). Kliknij "Wyłącz SMBv1".'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Protokół SMBv1' 'wyłączony' 'OK' ''))
        }
    } catch { }

    # Secure Boot
    try {
        if (Confirm-SecureBootUEFI -ErrorAction Stop) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Secure Boot' 'włączony' 'OK' ''))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Secure Boot' 'wyłączony' 'UWAGA' 'Włącz w ustawieniach UEFI/BIOS.'))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Secure Boot' 'nieobsługiwany (tryb BIOS/Legacy)' 'INFO' '')) }

    # TPM
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent -and $tpm.TpmReady) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Moduł TPM' 'obecny i gotowy' 'OK' ''))
        } elseif ($tpm.TpmPresent) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Moduł TPM' 'obecny, niegotowy' 'UWAGA' 'Sprawdź ustawienia TPM w UEFI.'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Moduł TPM' 'brak lub wyłączony w UEFI' 'INFO' 'Potrzebny do Windows 11 i BitLockera.'))
        }
    } catch { }

    # BitLocker
    try {
        $bl = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        if ([string]$bl.ProtectionStatus -eq 'On') {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Szyfrowanie dysku C:' 'BitLocker włączony' 'OK' 'Upewnij się, że klient ma zapisany klucz odzyskiwania!'))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Szyfrowanie dysku C:' 'dysk niezaszyfrowany' 'INFO' 'Na laptopach warto włączyć szyfrowanie.'))
        }
    } catch { [void]$wyniki.Add((Wynik-Sprawdzenia 'Szyfrowanie dysku C:' 'BitLocker niedostępny (np. Windows Home)' 'INFO' '')) }

    # Konta
    try {
        $gosc = Get-LocalUser -ErrorAction Stop | Where-Object { $_.SID.Value -like '*-501' }
        if ($gosc -and $gosc.Enabled) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Konto Gość' 'włączone' 'ŹLE' ('Wyłącz poleceniem: Disable-LocalUser -SID ' + $gosc.SID.Value)))
        } else {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Konto Gość' 'wyłączone' 'OK' ''))
        }
        $adm = Get-LocalUser | Where-Object { $_.SID.Value -like '*-500' }
        if ($adm -and $adm.Enabled) {
            [void]$wyniki.Add((Wynik-Sprawdzenia 'Wbudowane konto Administrator' 'włączone' 'UWAGA' 'Zwykle powinno być wyłączone; sprawdź, czy ma silne hasło.'))
        }
    } catch { }

    $wyniki
}

# =====================================================================
#  OKNO
# =====================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Narzędzia serwisowe Windows - ' + $env:COMPUTERNAME
$form.Size = New-Object System.Drawing.Size(1160, 800)
$form.MinimumSize = New-Object System.Drawing.Size(940, 620)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$zakladki = New-Object System.Windows.Forms.TabControl
$zakladki.Dock = 'Fill'

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Dock = 'Bottom'
$logBox.Height = 140
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)

# ---------- Uslugi ----------
$siatkaU = Nowa-Siatka
Dodaj-Kolumne $siatkaU 'Check' 'Wybierz' 70
Dodaj-Kolumne $siatkaU 'Text' 'Usługa' 230
Dodaj-Kolumne $siatkaU 'Text' 'Kategoria' 120
Dodaj-Kolumne $siatkaU 'Text' 'Co robi / co przestanie działać' 0
Dodaj-Kolumne $siatkaU 'Text' 'Rodzaj' 95
Dodaj-Kolumne $siatkaU 'Text' 'Stan' 85
Dodaj-Kolumne $siatkaU 'Text' 'Uruchamianie' 160

$panelU = Nowy-PanelPrzyciskow
$lblTryb = New-Object System.Windows.Forms.Label
$lblTryb.Text = 'Ustaw na:'
$lblTryb.AutoSize = $true
$lblTryb.Margin = New-Object System.Windows.Forms.Padding(4, 9, 2, 0)
[void]$panelU.Controls.Add($lblTryb)
$cmbTryb = New-Object System.Windows.Forms.ComboBox
$cmbTryb.DropDownStyle = 'DropDownList'
$cmbTryb.Width = 250
$cmbTryb.Margin = New-Object System.Windows.Forms.Padding(2, 5, 8, 0)
[void]$cmbTryb.Items.Add('Wyłączony (nie uruchomi się wcale)')
[void]$cmbTryb.Items.Add('Ręczny (tylko gdy coś jej potrzebuje)')
$cmbTryb.SelectedIndex = 0
[void]$panelU.Controls.Add($cmbTryb)
$btnZastosuj = Nowy-Przycisk $panelU 'Zastosuj do zaznaczonych' $true
$btnZalecane = Nowy-Przycisk $panelU 'Zaznacz zalecane' $false
$btnOdznaczU = Nowy-Przycisk $panelU 'Odznacz wszystko' $false
$btnDomyslne = Nowy-Przycisk $panelU 'Przywróć domyślne zaznaczonych' $false
$btnKopia    = Nowy-Przycisk $panelU 'Przywróć z kopii...' $false
$btnFolder   = Nowy-Przycisk $panelU 'Folder kopii' $false
$lblSzukaj = New-Object System.Windows.Forms.Label
$lblSzukaj.Text = 'Szukaj:'
$lblSzukaj.AutoSize = $true
$lblSzukaj.Margin = New-Object System.Windows.Forms.Padding(14, 9, 2, 0)
[void]$panelU.Controls.Add($lblSzukaj)
$txtSzukaj = New-Object System.Windows.Forms.TextBox
$txtSzukaj.Width = 200
$txtSzukaj.Margin = New-Object System.Windows.Forms.Padding(2, 6, 8, 0)
[void]$panelU.Controls.Add($txtSzukaj)

$tabUslugi = Nowa-Zakladka 'Usługi' $siatkaU ('Zaznacz usługi, wybierz Wyłączony albo Ręczny i kliknij "Zastosuj do zaznaczonych". ' +
    'Zalecane (zielone) są bezpieczne i zaznaczone od razu. Opcjonalne (pomarańczowe) zaznacz tylko, jeśli klient z nich nie korzysta. ' +
    'Przed zmianą tworzony jest punkt przywracania i kopia ustawień. Pole "Szukaj" filtruje po nazwie, kategorii i opisie (np. drukark, bluetooth, sieć).') $panelU

# ---------- Autostart ----------
$siatkaA = Nowa-Siatka
Dodaj-Kolumne $siatkaA 'Check' 'Wybierz' 70
Dodaj-Kolumne $siatkaA 'Text' 'Program' 220
Dodaj-Kolumne $siatkaA 'Text' 'Polecenie' 0
Dodaj-Kolumne $siatkaA 'Text' 'Skąd' 190
Dodaj-Kolumne $siatkaA 'Text' 'Stan' 100

$panelA = Nowy-PanelPrzyciskow
$btnAWylacz = Nowy-Przycisk $panelA 'Wyłącz zaznaczone' $true
$btnAWlacz  = Nowy-Przycisk $panelA 'Włącz zaznaczone' $false
$btnAOdswiez = Nowy-Przycisk $panelA 'Odśwież' $false
$btnAMenedzer = Nowy-Przycisk $panelA 'Menedżer zadań' $false

$tabAutostart = Nowa-Zakladka 'Autostart' $siatkaA ('Programy uruchamiane razem z Windows. Wyłączenie działa tak samo jak w Menedżerze zadań: ' +
    'nic nie jest usuwane i w każdej chwili można włączyć z powrotem. Nie wyłączaj sterowników (audio, touchpad, karta graficzna) ani antywirusa.') $panelA

# ---------- Programy w tle ----------
$siatkaP = Nowa-Siatka
Dodaj-Kolumne $siatkaP 'Check' 'Wybierz' 70
Dodaj-Kolumne $siatkaP 'Text' 'Program' 220
Dodaj-Kolumne $siatkaP 'Text' 'Opis / ścieżka' 0
Dodaj-Kolumne $siatkaP 'Text' 'Procesy' 70
Dodaj-Kolumne $siatkaP 'Text' 'Pamięć' 90
Dodaj-Kolumne $siatkaP 'Text' 'Okno' 70

$panelP = Nowy-PanelPrzyciskow
$btnPZakoncz = Nowy-Przycisk $panelP 'Zamknij zaznaczone' $true
$btnPOdswiez = Nowy-Przycisk $panelP 'Odśwież' $false
$btnPBlokuj = Nowy-Przycisk $panelP 'Zablokuj aplikacje ze Sklepu w tle' $false
$btnPOdblokuj = Nowy-Przycisk $panelP 'Przywróć aplikacje w tle' $false

$tabProgramy = Nowa-Zakladka 'Programy w tle' $siatkaP ('Programy działające teraz (bez procesów systemowych), od zajmujących najwięcej pamięci. "Okno: nie" = działa w tle. ' +
    'Zamknięcie jest jednorazowe; żeby program nie wracał, wyłącz go w zakładce Autostart.') $panelP

# ---------- Czyszczenie ----------
$siatkaC = Nowa-Siatka
Dodaj-Kolumne $siatkaC 'Check' 'Wybierz' 70
Dodaj-Kolumne $siatkaC 'Text' 'Co wyczyścić' 260
Dodaj-Kolumne $siatkaC 'Text' 'Opis' 0
Dodaj-Kolumne $siatkaC 'Text' 'Rozmiar' 110

$panelC = Nowy-PanelPrzyciskow
$btnWyczysc  = Nowy-Przycisk $panelC 'Wyczyść zaznaczone' $true
$btnPrzelicz = Nowy-Przycisk $panelC 'Przelicz rozmiar' $false
$btnOdznaczC = Nowy-Przycisk $panelC 'Odznacz wszystko' $false

$tabCzyszczenie = Nowa-Zakladka 'Czyszczenie' $siatkaC ('Zaznacz, co usunąć, i kliknij "Wyczyść zaznaczone". Pliki w użyciu są pomijane, więc nic się nie zepsuje. ' +
    'Kosz, przeglądarki, zrzuty pamięci i DISM są domyślnie odznaczone.') $panelC

# ---------- Bezpieczenstwo ----------
$siatkaB = Nowa-Siatka
Dodaj-Kolumne $siatkaB 'Text' 'Sprawdzenie' 200
Dodaj-Kolumne $siatkaB 'Text' 'Wynik' 0
Dodaj-Kolumne $siatkaB 'Text' 'Ocena' 80
Dodaj-Kolumne $siatkaB 'Text' 'Co zrobić' 330

$panelB = Nowy-PanelPrzyciskow
$btnBRaport   = Nowy-Przycisk $panelB 'Zapisz raport na pulpit' $true
$btnBOdswiez  = Nowy-Przycisk $panelB 'Sprawdź ponownie' $false
$btnBAktualizuj = Nowy-Przycisk $panelB 'Aktualizuj Defendera' $false
$btnBSkan     = Nowy-Przycisk $panelB 'Szybkie skanowanie' $false
$btnBZapora   = Nowy-Przycisk $panelB 'Włącz zaporę' $false
$btnBSmb      = Nowy-Przycisk $panelB 'Wyłącz SMBv1' $false
$btnBUpdate   = Nowy-Przycisk $panelB 'Windows Update' $false

$tabBezp = Nowa-Zakladka 'Bezpieczeństwo' $siatkaB ('Przegląd zabezpieczeń komputera. Zielone = OK, pomarańczowe = warto poprawić, czerwone = do naprawy. ' +
    '"Zapisz raport na pulpit" tworzy plik z wynikami i listą wykonanych prac - możesz go dać klientowi.') $panelB

$form.Controls.Add($zakladki)
$form.Controls.Add($logBox)

# =====================================================================
#  LOGIKA: USLUGI
# =====================================================================
function Wypelnij-Uslugi {
    $siatkaU.Rows.Clear()
    foreach ($u in $listaUslug) {
        $svc = Get-Service -Name $u.Nazwa -ErrorAction SilentlyContinue
        if (-not $svc) { continue }
        $si = Get-StartInfo $u.Nazwa
        if (-not $si) { continue }
        $wylaczona = ($si.Start -eq 4)
        $zaznacz = (($u.Rodzaj -eq 'Zalecane') -and (-not $wylaczona))
        $idx = $siatkaU.Rows.Add($zaznacz, ($u.Etykieta + $NL + $u.Nazwa), $u.Kategoria, $u.Opis, $u.Rodzaj,
            (Stan-PL $svc.Status), (Opis-Startu $si.Start $si.Delayed))
        $wiersz = $siatkaU.Rows[$idx]
        $wiersz.Tag = $u
        if ($u.Rodzaj -eq 'Zalecane') { $wiersz.Cells[4].Style.ForeColor = Kolor 'OK' }
        else { $wiersz.Cells[4].Style.ForeColor = Kolor 'UWAGA' }
        if ($wylaczona) {
            $wiersz.Cells[5].Style.ForeColor = Kolor 'Wyłączony'
            $wiersz.Cells[6].Style.ForeColor = Kolor 'Wyłączony'
        }
    }
    Filtruj-Uslugi
}

function Filtruj-Uslugi {
    $fraza = $txtSzukaj.Text.Trim()
    $siatkaU.CurrentCell = $null
    foreach ($r in $siatkaU.Rows) {
        $u = $r.Tag
        if (-not $fraza) { $r.Visible = $true; continue }
        $tekst = $u.Etykieta + ' ' + $u.Nazwa + ' ' + $u.Kategoria + ' ' + $u.Opis
        $r.Visible = ($tekst.IndexOf($fraza, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    }
}

$txtSzukaj.Add_TextChanged({ Filtruj-Uslugi })

$btnZalecane.Add_Click({
    foreach ($r in $siatkaU.Rows) {
        $si = Get-StartInfo $r.Tag.Nazwa
        $r.Cells[0].Value = (($r.Tag.Rodzaj -eq 'Zalecane') -and ($si.Start -ne 4))
    }
})

$btnOdznaczU.Add_Click({ Odznacz-Wszystko $siatkaU })

$btnFolder.Add_Click({ Start-Process -FilePath 'explorer.exe' -ArgumentList "`"$folderKopii`"" })

$btnZastosuj.Add_Click({
    if ($cmbTryb.SelectedIndex -eq 1) { $typ = 'demand'; $kod = 3; $nazwaTrybu = 'Ręczny' }
    else { $typ = 'disabled'; $kod = 4; $nazwaTrybu = 'Wyłączony' }

    $wybrane = @(Zaznaczone $siatkaU | Where-Object { (Get-StartInfo $_.Nazwa).Start -ne $kod })
    if ($wybrane.Count -eq 0) { Info "Brak zaznaczonych usług do zmiany na: $nazwaTrybu."; return }

    $nazwy = ($wybrane | ForEach-Object { '- ' + $_.Etykieta }) -join $NL
    if (-not (Pytanie ("Ustawić $($wybrane.Count) usług(i) na: ${nazwaTrybu}?" + $NL + $NL + $nazwy))) { return }

    Zajety $true
    try {
        Log 'Tworzę punkt przywracania (może potrwać do minuty)...'
        try {
            Checkpoint-Computer -Description 'Przed zmiana uslug' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop -WarningAction SilentlyContinue
            Log 'Punkt przywracania gotowy (albo Windows użył tego sprzed mniej niż 24 h).'
        } catch {
            Log ('UWAGA: nie udało się utworzyć punktu przywracania: ' + $_.Exception.Message)
        }

        $dane = @(foreach ($u in $wybrane) {
            $si = Get-StartInfo $u.Nazwa
            $svc = Get-Service -Name $u.Nazwa -ErrorAction SilentlyContinue
            [pscustomobject]@{ Nazwa = $u.Nazwa; Start = $si.Start; Delayed = $si.Delayed; Stan = [string]$svc.Status }
        })
        $plikKopii = Join-Path $folderKopii ('uslugi_{0:yyyyMMdd_HHmmss}.csv' -f (Get-Date))
        $dane | Export-Csv -LiteralPath $plikKopii -NoTypeInformation -Encoding UTF8
        Log "Kopia ustawień: $plikKopii"

        $ok = 0; $bledy = 0
        foreach ($d in $dane) {
            $w = Ustaw-Start $d.Nazwa $typ
            if ($w.Ok) {
                if ($typ -eq 'disabled' -and $d.Stan -eq 'Running') {
                    Stop-Service -Name $d.Nazwa -Force -ErrorAction SilentlyContinue
                }
                Log "Usługa ustawiona na $($nazwaTrybu): $($d.Nazwa)"
                $ok++
            } else {
                Log "BŁĄD: $($d.Nazwa): $($w.Komunikat)"
                $bledy++
            }
        }
        Log "Gotowe. Zmieniono: $ok, błędy: $bledy. Zalecany restart komputera."
    } finally {
        Zajety $false
        Wypelnij-Uslugi
    }
})

$btnDomyslne.Add_Click({
    $wybrane = @(Zaznaczone $siatkaU)
    if ($wybrane.Count -eq 0) { Info 'Zaznacz usługi, którym przywrócić domyślne ustawienia Windows.'; return }
    if (-not (Pytanie "Przywrócić domyślne ustawienia Windows dla $($wybrane.Count) usług(i)?")) { return }
    Zajety $true
    try {
        foreach ($u in $wybrane) {
            $w = Ustaw-Start $u.Nazwa $u.Domyslnie
            if ($w.Ok) {
                if ($u.Domyslnie -eq 'auto' -or $u.Domyslnie -eq 'delayed-auto') {
                    Start-Service -Name $u.Nazwa -ErrorAction SilentlyContinue
                }
                Log "Przywrócono domyślne ($($u.Domyslnie)): $($u.Nazwa)"
            } else {
                Log "BŁĄD: $($u.Nazwa): $($w.Komunikat)"
            }
        }
        Log 'Gotowe.'
    } finally {
        Zajety $false
        Wypelnij-Uslugi
    }
})

$btnKopia.Add_Click({
    $okno = New-Object System.Windows.Forms.OpenFileDialog
    $okno.InitialDirectory = $folderKopii
    $okno.Filter = 'Kopie usług (uslugi_*.csv)|uslugi_*.csv|Wszystkie pliki (*.*)|*.*'
    $okno.Title = 'Wybierz kopię ustawień do przywrócenia'
    if ($okno.ShowDialog() -ne 'OK') { return }
    if (-not (Pytanie ('Przywrócić ustawienia z pliku:' + $NL + $okno.FileName + ' ?'))) { return }
    Zajety $true
    try {
        foreach ($r in @(Import-Csv -LiteralPath $okno.FileName)) {
            $typ = Typ-Z-Kopii $r.Start $r.Delayed
            if (-not $typ) { continue }
            $w = Ustaw-Start $r.Nazwa $typ
            if ($w.Ok) {
                if ($r.Stan -eq 'Running') { Start-Service -Name $r.Nazwa -ErrorAction SilentlyContinue }
                Log "Przywrócono ($typ): $($r.Nazwa)"
            } else {
                Log "BŁĄD: $($r.Nazwa): $($w.Komunikat)"
            }
        }
        Log 'Przywracanie z kopii zakończone. Zalecany restart komputera.'
    } finally {
        Zajety $false
        Wypelnij-Uslugi
    }
})

# =====================================================================
#  LOGIKA: AUTOSTART
# =====================================================================
function Wypelnij-Autostart {
    $siatkaA.Rows.Clear()
    foreach ($el in (Pobierz-Autostart)) {
        if ($el.Wylaczony) { $stanTxt = 'Wyłączony' } else { $stanTxt = 'Włączony' }
        $idx = $siatkaA.Rows.Add($false, $el.Nazwa, $el.Polecenie, $el.Miejsce, $stanTxt)
        $wiersz = $siatkaA.Rows[$idx]
        $wiersz.Tag = $el
        if ($el.Wylaczony) {
            $wiersz.Cells[4].Style.ForeColor = Kolor 'Wyłączony'
            $wiersz.Cells[1].Style.ForeColor = Kolor 'Wyłączony'
        } else {
            $wiersz.Cells[4].Style.ForeColor = Kolor 'OK'
        }
    }
}

function Zmien-Autostart([bool]$wlacz) {
    $wybrane = @(Zaznaczone $siatkaA | Where-Object { $_.Wylaczony -eq $wlacz })
    if ($wlacz) { $slowo = 'Włączyć' } else { $slowo = 'Wyłączyć' }
    if ($wybrane.Count -eq 0) { Info 'Brak zaznaczonych pozycji do zmiany.'; return }
    $nazwy = ($wybrane | ForEach-Object { '- ' + $_.Nazwa }) -join $NL
    if (-not (Pytanie ("$slowo w autostarcie?" + $NL + $NL + $nazwy))) { return }
    foreach ($el in $wybrane) {
        try {
            Ustaw-Autostart $el $wlacz
            if ($wlacz) { Log "Autostart włączony: $($el.Nazwa)" } else { Log "Autostart wyłączony: $($el.Nazwa)" }
        } catch {
            Log "BŁĄD autostart $($el.Nazwa): $($_.Exception.Message)"
        }
    }
    Wypelnij-Autostart
}

$btnAWylacz.Add_Click({ Zmien-Autostart $false })
$btnAWlacz.Add_Click({ Zmien-Autostart $true })
$btnAOdswiez.Add_Click({ Wypelnij-Autostart })
$btnAMenedzer.Add_Click({ Start-Process -FilePath 'taskmgr.exe' -ArgumentList '/7 /startup' })

# =====================================================================
#  LOGIKA: PROGRAMY W TLE
# =====================================================================
function Wypelnij-Programy {
    $siatkaP.Rows.Clear()
    foreach ($p in (Pobierz-Procesy)) {
        if ($p.Okno) { $oknoTxt = 'tak' } else { $oknoTxt = 'nie' }
        $opis = $p.Opis
        if ($opis) { $opis = $opis + $NL + $p.Sciezka } else { $opis = $p.Sciezka }
        $idx = $siatkaP.Rows.Add($false, $p.Nazwa, $opis, [string]$p.Liczba, (Tekst-Rozmiaru $p.Pamiec), $oknoTxt)
        $wiersz = $siatkaP.Rows[$idx]
        $wiersz.Tag = $p
        if (-not $p.Okno) { $wiersz.Cells[5].Style.ForeColor = Kolor 'UWAGA' }
    }
    if (Czy-TloZablokowane) { Log 'Aplikacje ze Sklepu: działanie w tle ZABLOKOWANE.' }
}

$btnPOdswiez.Add_Click({ Wypelnij-Programy })

$btnPZakoncz.Add_Click({
    $wybrane = @(Zaznaczone $siatkaP)
    if ($wybrane.Count -eq 0) { Info 'Zaznacz programy do zamknięcia.'; return }
    $nazwy = ($wybrane | ForEach-Object { '- ' + $_.Nazwa }) -join $NL
    if (-not (Pytanie ('Zamknąć? Niezapisana praca w tych programach przepadnie.' + $NL + $NL + $nazwy))) { return }
    foreach ($p in $wybrane) {
        Stop-Process -Name $p.Nazwa -Force -ErrorAction SilentlyContinue
        Log "Zamknięto: $($p.Nazwa)"
    }
    Start-Sleep -Milliseconds 500
    Wypelnij-Programy
})

$btnPBlokuj.Add_Click({
    if (-not (Pytanie ('Zablokować działanie w tle aplikacjom ze Sklepu Microsoft (Poczta, Pogoda, Xbox itp.)?' + $NL +
        'Mogą przestać przychodzić od nich powiadomienia. Zwykłych programów to nie dotyczy.'))) { return }
    try {
        if (-not (Test-Path -LiteralPath $kluczPolityki)) { New-Item -Path $kluczPolityki -Force | Out-Null }
        Set-ItemProperty -LiteralPath $kluczPolityki -Name 'LetAppsRunInBackground' -Value 2 -Type DWord
        Log 'Aplikacje ze Sklepu: działanie w tle zablokowane (zadziała po ponownym zalogowaniu).'
    } catch { Log ('BŁĄD: ' + $_.Exception.Message) }
})

$btnPOdblokuj.Add_Click({
    try {
        if (Test-Path -LiteralPath $kluczPolityki) {
            Remove-ItemProperty -LiteralPath $kluczPolityki -Name 'LetAppsRunInBackground' -ErrorAction SilentlyContinue
        }
        Log 'Aplikacje ze Sklepu: działanie w tle przywrócone (ustawienie domyślne Windows).'
    } catch { Log ('BŁĄD: ' + $_.Exception.Message) }
})

# =====================================================================
#  LOGIKA: CZYSZCZENIE
# =====================================================================
function Wypelnij-Czyszczenie {
    $siatkaC.Rows.Clear()
    foreach ($p in $listaCzyszczenia) {
        $idx = $siatkaC.Rows.Add([bool]$p.Zaznacz, $p.Etykieta, $p.Opis, '...')
        $siatkaC.Rows[$idx].Tag = $p
    }
}

function Przelicz-Rozmiary {
    $suma = [long]0
    foreach ($r in $siatkaC.Rows) {
        $p = $r.Tag
        if (@($p.Sciezki).Count -eq 0) { $r.Cells[3].Value = 'nieznany'; continue }
        $r.Cells[3].Value = 'liczę...'
        [System.Windows.Forms.Application]::DoEvents()
        $b = Rozmiar-Sciezek $p.Sciezki
        $r.Cells[3].Value = Tekst-Rozmiaru $b
        $suma += $b
    }
    Log ('Czyszczenie - do odzyskania łącznie: ' + (Tekst-Rozmiaru $suma))
}

$btnPrzelicz.Add_Click({
    Zajety $true
    try { Przelicz-Rozmiary } finally { Zajety $false }
})

$btnOdznaczC.Add_Click({ Odznacz-Wszystko $siatkaC })

$btnWyczysc.Add_Click({
    $wybrane = @(Zaznaczone $siatkaC)
    if ($wybrane.Count -eq 0) { Info 'Zaznacz, co wyczyścić.'; return }
    $nazwy = ($wybrane | ForEach-Object { '- ' + $_.Etykieta }) -join $NL
    if (-not (Pytanie ('Wyczyścić?' + $NL + $NL + $nazwy))) { return }

    Zajety $true
    try {
        $zwolniono = [long]0
        foreach ($p in $wybrane) {
            Log ('Czyszczę: ' + $p.Etykieta)
            $maSciezki = (@($p.Sciezki).Count -gt 0)
            $przed = [long]0
            if ($maSciezki) { $przed = Rozmiar-Sciezek $p.Sciezki }
            try {
                if ($p.Akcja) { & $p.Akcja $p.Sciezki } else { Usun-Sciezki $p.Sciezki }
            } catch {
                Log ('  błąd: ' + $_.Exception.Message)
            }
            if ($maSciezki) {
                $po = Rozmiar-Sciezek $p.Sciezki
                $roznica = [math]::Max([long]0, $przed - $po)
                $zwolniono += $roznica
                Log ('  zwolniono: ' + (Tekst-Rozmiaru $roznica))
            }
        }
        Log ('Czyszczenie gotowe. Zwolniono łącznie: ' + (Tekst-Rozmiaru $zwolniono))
        Przelicz-Rozmiary
    } finally {
        Zajety $false
    }
})

# =====================================================================
#  LOGIKA: BEZPIECZENSTWO
# =====================================================================
function Wypelnij-Bezpieczenstwo {
    $siatkaB.Rows.Clear()
    Log 'Sprawdzam zabezpieczenia...'
    $wyniki = @(Sprawdz-Bezpieczenstwo)
    $stan.Bezpieczenstwo = $wyniki
    foreach ($w in $wyniki) {
        $idx = $siatkaB.Rows.Add($w.Nazwa, $w.Wynik, $w.Ocena, $w.Rada)
        $siatkaB.Rows[$idx].Cells[2].Style.ForeColor = Kolor $w.Ocena
        $siatkaB.Rows[$idx].Cells[2].Style.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    }
    $zle = @($wyniki | Where-Object { $_.Ocena -eq 'ŹLE' }).Count
    $uwagi = @($wyniki | Where-Object { $_.Ocena -eq 'UWAGA' }).Count
    Log "Bezpieczeństwo: do naprawy $zle, do poprawy $uwagi."
}

$btnBOdswiez.Add_Click({
    Zajety $true
    try { Wypelnij-Bezpieczenstwo } finally { Zajety $false }
})

$btnBAktualizuj.Add_Click({
    Zajety $true
    try {
        Log 'Aktualizuję bazy Microsoft Defender...'
        Update-MpSignature -ErrorAction Stop
        Log 'Bazy Defendera zaktualizowane.'
    } catch {
        Log ('BŁĄD aktualizacji Defendera: ' + $_.Exception.Message)
    } finally {
        Zajety $false
        Wypelnij-Bezpieczenstwo
    }
})

$btnBSkan.Add_Click({
    $mpcmd = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (-not (Test-Path -LiteralPath $mpcmd)) { Info 'Nie znaleziono Microsoft Defendera na tym komputerze.'; return }
    Zajety $true
    try {
        Log 'Szybkie skanowanie Defenderem (kilka minut)...'
        $proc = Start-Process -FilePath $mpcmd -ArgumentList '-Scan -ScanType 1' -WindowStyle Hidden -PassThru
        while (-not $proc.HasExited) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 300
        }
        if ($proc.ExitCode -eq 0) { Log 'Skanowanie zakończone: nic nie znaleziono.' }
        else { Log ('Skanowanie zakończone, kod: ' + $proc.ExitCode + ' (sprawdź Zabezpieczenia Windows > Historia ochrony).') }
    } finally {
        Zajety $false
    }
})

$btnBZapora.Add_Click({
    try {
        Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -ErrorAction Stop
        Log 'Zapora Windows włączona dla wszystkich profili.'
    } catch { Log ('BŁĄD zapory: ' + $_.Exception.Message) }
    Wypelnij-Bezpieczenstwo
})

$btnBSmb.Add_Click({
    try {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
        Log 'SMBv1 wyłączony.'
    } catch { Log ('BŁĄD SMBv1: ' + $_.Exception.Message) }
    Wypelnij-Bezpieczenstwo
})

$btnBUpdate.Add_Click({ Start-Process 'ms-settings:windowsupdate' })

$btnBRaport.Add_Click({
    if (@($stan.Bezpieczenstwo).Count -eq 0) { Wypelnij-Bezpieczenstwo }
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $linie = New-Object System.Collections.ArrayList
    [void]$linie.Add('RAPORT SERWISOWY')
    [void]$linie.Add('Komputer: ' + $env:COMPUTERNAME)
    [void]$linie.Add('Data: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    if ($os) { [void]$linie.Add('System: ' + $os.Caption + ' (kompilacja ' + $os.BuildNumber + ')') }
    [void]$linie.Add('')
    [void]$linie.Add('ZABEZPIECZENIA')
    foreach ($w in $stan.Bezpieczenstwo) {
        $l = ('[{0}] {1}: {2}' -f $w.Ocena, $w.Nazwa, $w.Wynik)
        if ($w.Rada) { $l = $l + ' -> ' + $w.Rada }
        [void]$linie.Add($l)
    }
    [void]$linie.Add('')
    [void]$linie.Add('WYKONANE PRACE (dziennik)')
    [void]$linie.Add($logBox.Text)
    $pulpit = [Environment]::GetFolderPath('Desktop')
    $plik = Join-Path $pulpit ('Raport_serwisowy_{0}_{1:yyyyMMdd_HHmm}.txt' -f $env:COMPUTERNAME, (Get-Date))
    $linie | Out-File -FilePath $plik -Encoding UTF8
    Log "Raport zapisany: $plik"
    Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$plik`""
})

# =====================================================================
#  START
# =====================================================================
$zakladki.Add_SelectedIndexChanged({
    $t = $zakladki.SelectedTab
    if ($stan.Zaladowane.ContainsKey($t.Text)) { return }
    $stan.Zaladowane[$t.Text] = $true
    Zajety $true
    try {
        if ($t -eq $tabAutostart) { Wypelnij-Autostart }
        elseif ($t -eq $tabProgramy) { Wypelnij-Programy }
        elseif ($t -eq $tabCzyszczenie) { Wypelnij-Czyszczenie; Przelicz-Rozmiary }
        elseif ($t -eq $tabBezp) { Wypelnij-Bezpieczenstwo }
    } finally {
        Zajety $false
    }
})

$form.Add_Shown({
    $stan.Zaladowane[$tabUslugi.Text] = $true
    Log "Komputer: $env:COMPUTERNAME. Kopie i log: $folderKopii"
    Wypelnij-Uslugi
})

try {
    [void]$form.ShowDialog()
} catch {
    [void][System.Windows.Forms.MessageBox]::Show('Błąd: ' + $_.Exception.Message, 'Błąd', 'OK', 'Error')
}
