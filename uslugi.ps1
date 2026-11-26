<#
    Wyłączanie zbędnych usług Windows 10/11 – wersja z okienkiem.

    - Lista usług z opisem, co robią i co przestanie działać po wyłączeniu.
    - Zalecane (bezpieczne) są zaznaczone od razu, opcjonalne trzeba zaznaczyć samemu.
    - Przed zmianą: punkt przywracania systemu + kopia ustawień (CSV).
    - Przyciski: przywrócenie z kopii albo ustawień domyślnych Windows.
    - Nic nie pobiera z internetu i nie instaluje. Zmienia tylko typ uruchamiania usług.
    - Kopie i log: C:\ProgramData\UslugiKopia
#>

# Adres, spod którego skrypt jest uruchamiany komendą:  irm <adres> | iex
$AdresSkryptu = 'https://raw.githubusercontent.com/podkal95/narzedzia/main/uslugi.ps1'

# ---------- uruchomienie jako administrator ----------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    if ($PSCommandPath) {
        # uruchomiony z pliku
        $polecenie = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } else {
        # uruchomiony przez irm | iex
        $polecenie = "-NoProfile -ExecutionPolicy Bypass -Command `"[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; irm '$AdresSkryptu' | iex`""
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Minimized -ArgumentList $polecenie
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$folder = Join-Path $env:ProgramData 'UslugiKopia'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$logPlik = Join-Path $folder ('log_{0:yyyyMMdd}.txt' -f (Get-Date))

# ---------- lista usług ----------
# Domyslnie = typ uruchamiania w czystym Windows (do przycisku „Przywróć domyślne”)
function U($nazwa, $etykieta, $opis, $rodzaj, $domyslnie) {
    [pscustomobject]@{ Nazwa = $nazwa; Etykieta = $etykieta; Opis = $opis; Rodzaj = $rodzaj; Domyslnie = $domyslnie }
}
$uslugi = @(
    U 'DiagTrack'        'Telemetria Microsoft'            'Wysyła dane diagnostyczne i o użytkowaniu do Microsoft. Bez wpływu na działanie komputera.' 'Zalecane' 'auto'
    U 'dmwappushservice' 'WAP Push (telemetria)'           'Przekazuje komunikaty telemetrii i zarządzania. NIE wyłączaj na komputerach firmowych zarządzanych przez Intune.' 'Zalecane' 'demand'
    U 'diagnosticshub.standardcollector.service' 'Diagnostics Hub' 'Zbiera diagnostykę dla Visual Studio. Potrzebne tylko programistom.' 'Zalecane' 'demand'
    U 'WerSvc'           'Raportowanie błędów Windows'     'Wysyła raporty o awariach programów do Microsoft.' 'Zalecane' 'demand'
    U 'RetailDemo'       'Tryb demo sklepu'                'Tryb pokazowy dla komputerów wystawionych w sklepie.' 'Zalecane' 'demand'
    U 'MapsBroker'       'Mapy offline'                    'Pobiera i aktualizuje mapy dla aplikacji Mapy.' 'Zalecane' 'delayed-auto'
    U 'Fax'              'Faks'                            'Wysyłanie i odbieranie faksów.' 'Zalecane' 'demand'
    U 'RemoteRegistry'   'Zdalny rejestr'                  'Pozwala zmieniać rejestr przez sieć. Ryzyko bezpieczeństwa.' 'Zalecane' 'disabled'
    U 'WMPNetworkSvc'    'Udostępnianie Windows Media Player' 'Udostępnia bibliotekę multimediów innym urządzeniom w sieci.' 'Zalecane' 'demand'
    U 'AJRouter'         'AllJoyn Router'                  'Komunikacja z urządzeniami IoT (praktycznie nieużywana).' 'Zalecane' 'demand'
    U 'wisvc'            'Windows Insider'                 'Obsługa testowych wersji Windows.' 'Zalecane' 'demand'

    U 'XblAuthManager'   'Xbox – logowanie'                'Przestanie działać logowanie do Xbox / Game Pass i część gier ze Sklepu.' 'Opcjonalne' 'demand'
    U 'XblGameSave'      'Xbox – zapisy w chmurze'         'Zapisy gier Xbox nie będą synchronizowane.' 'Opcjonalne' 'demand'
    U 'XboxNetApiSvc'    'Xbox – sieć'                     'Gry sieciowe przez Xbox Live mogą nie działać.' 'Opcjonalne' 'demand'
    U 'XboxGipSvc'       'Xbox – akcesoria'                'Brak aktualizacji i konfiguracji padów Xbox.' 'Opcjonalne' 'demand'
    U 'Spooler'          'Bufor wydruku'                   'Przestaną działać WSZYSTKIE drukarki oraz „Microsoft Print to PDF”.' 'Opcjonalne' 'auto'
    U 'PrintNotify'      'Powiadomienia drukarek'          'Brak powiadomień i rozszerzeń sterowników drukarek.' 'Opcjonalne' 'demand'
    U 'WSearch'          'Indeksowanie wyszukiwania'       'Wyszukiwanie w menu Start, Eksploratorze i Outlooku będzie wolniejsze.' 'Opcjonalne' 'delayed-auto'
    U 'SysMain'          'SysMain (Superfetch)'            'Wstępne ładowanie programów. Na SSD zwykle zbędne, na HDD lepiej zostawić.' 'Opcjonalne' 'auto'
    U 'lfsvc'            'Lokalizacja'                     'Pogoda, mapy i „Znajdź moje urządzenie” nie ustalą położenia.' 'Opcjonalne' 'demand'
    U 'TrkWks'           'Śledzenie łączy rozproszonych'   'Naprawia skróty do plików przeniesionych w sieci firmowej. W domu zbędne.' 'Opcjonalne' 'auto'
    U 'WpcMonSvc'        'Kontrola rodzicielska'           'Nie wyłączaj, jeśli dzieci mają konta w Microsoft Family.' 'Opcjonalne' 'demand'
    U 'TermService'      'Pulpit zdalny (RDP)'             'Nikt nie połączy się z tym komputerem przez Pulpit zdalny.' 'Opcjonalne' 'demand'
    U 'bthserv'          'Bluetooth'                       'Przestaną działać słuchawki, myszki i inne urządzenia Bluetooth.' 'Opcjonalne' 'demand'
    U 'icssvc'           'Mobilny hotspot'                 'Nie da się udostępnić internetu z tego komputera.' 'Opcjonalne' 'demand'
)

# ---------- funkcje pomocnicze ----------
function Get-StartInfo([string]$Nazwa) {
    $klucz = "HKLM:\SYSTEM\CurrentControlSet\Services\$Nazwa"
    if (-not (Test-Path $klucz)) { return $null }
    $p = Get-ItemProperty -Path $klucz -ErrorAction SilentlyContinue
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
    switch ([string]$status) { 'Running' { 'Działa' } 'Stopped' { 'Zatrzymana' } default { [string]$status } }
}

function Typ-Z-Kopii($start, $delayed) {
    switch ([int]$start) {
        2       { if ([int]$delayed -eq 1) { 'delayed-auto' } else { 'auto' } }
        3       { 'demand' }
        4       { 'disabled' }
        default { $null }
    }
}

function Ustaw-Start([string]$nazwa, [string]$typ) {
    $wynik = & sc.exe config $nazwa start= $typ 2>&1
    [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Komunikat = ($wynik -join ' ') }
}

function Log([string]$tekst) {
    $linia = '{0:HH:mm:ss}  {1}' -f (Get-Date), $tekst
    $logBox.AppendText($linia + [Environment]::NewLine)
    Add-Content -LiteralPath $logPlik -Value $linia -Encoding UTF8
    [System.Windows.Forms.Application]::DoEvents()
}

function Wypelnij-Liste {
    $grid.Rows.Clear()
    foreach ($u in $uslugi) {
        $svc = Get-Service -Name $u.Nazwa -ErrorAction SilentlyContinue
        if (-not $svc) { continue }
        $si = Get-StartInfo $u.Nazwa
        if (-not $si) { continue }
        $wylaczona = ($si.Start -eq 4)
        $zaznacz = ($u.Rodzaj -eq 'Zalecane') -and (-not $wylaczona)
        $idx = $grid.Rows.Add($zaznacz, ($u.Etykieta + [Environment]::NewLine + $u.Nazwa), $u.Opis, $u.Rodzaj,
            (Stan-PL $svc.Status), (Opis-Startu $si.Start $si.Delayed))
        $row = $grid.Rows[$idx]
        $row.Tag = $u
        if ($u.Rodzaj -eq 'Zalecane') { $row.Cells[3].Style.ForeColor = [System.Drawing.Color]::ForestGreen }
        else { $row.Cells[3].Style.ForeColor = [System.Drawing.Color]::DarkOrange }
        if ($wylaczona) {
            $row.Cells[5].Style.ForeColor = [System.Drawing.Color]::Gray
            $row.Cells[4].Style.ForeColor = [System.Drawing.Color]::Gray
        }
    }
}

function Zaznaczone {
    $grid.EndEdit() | Out-Null
    @(foreach ($r in $grid.Rows) { if ($r.Cells[0].Value -eq $true) { $r.Tag } })
}

function Pytanie([string]$tekst) {
    [System.Windows.Forms.MessageBox]::Show($tekst, 'Potwierdź', 'YesNo', 'Question') -eq 'Yes'
}

function Zajety([bool]$tak) {
    $panelPrzyciskow.Enabled = -not $tak
    $grid.Enabled = -not $tak
    if ($tak) { $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor } else { $form.Cursor = [System.Windows.Forms.Cursors]::Default }
}

# ---------- okno ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Wyłączanie zbędnych usług Windows'
$form.Size = New-Object System.Drawing.Size(1120, 740)
$form.MinimumSize = New-Object System.Drawing.Size(900, 560)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.AutoSizeRowsMode = 'AllCells'
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.BorderStyle = 'None'
$grid.DefaultCellStyle.WrapMode = 'True'
$grid.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(4)
$grid.ColumnHeadersHeightSizeMode = 'AutoSize'

$kolumny = @(
    @{ Typ = 'Check'; Tytul = 'Wybierz';      Szer = 70 }
    @{ Typ = 'Text';  Tytul = 'Usługa';       Szer = 250 }
    @{ Typ = 'Text';  Tytul = 'Co robi / co przestanie działać'; Szer = 0 }
    @{ Typ = 'Text';  Tytul = 'Rodzaj';       Szer = 95 }
    @{ Typ = 'Text';  Tytul = 'Stan';         Szer = 90 }
    @{ Typ = 'Text';  Tytul = 'Uruchamianie'; Szer = 170 }
)
foreach ($k in $kolumny) {
    if ($k.Typ -eq 'Check') { $c = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn }
    else { $c = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $c.ReadOnly = $true }
    $c.HeaderText = $k.Tytul
    $c.SortMode = 'NotSortable'
    if ($k.Szer -gt 0) { $c.Width = $k.Szer } else { $c.AutoSizeMode = 'Fill' }
    [void]$grid.Columns.Add($c)
}
$grid.Add_CurrentCellDirtyStateChanged({
    if ($grid.IsCurrentCellDirty) { [void]$grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
})

$naglowek = New-Object System.Windows.Forms.Label
$naglowek.Dock = 'Top'
$naglowek.Height = 64
$naglowek.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 4)
$naglowek.Text = "Zaznacz usługi, wybierz Wyłączony albo Ręczny i kliknij „Zastosuj do zaznaczonych”. Zalecane (zielone) są bezpieczne i zaznaczone od razu. " +
    "Opcjonalne (pomarańczowe) zaznacz tylko, jeśli klient z nich nie korzysta. Przed zmianą tworzony jest punkt przywracania i kopia ustawień."

$panelDol = New-Object System.Windows.Forms.Panel
$panelDol.Dock = 'Bottom'
$panelDol.Height = 200

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Dock = 'Fill'
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.BackColor = [System.Drawing.Color]::FromArgb(248, 248, 248)
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)

$panelPrzyciskow = New-Object System.Windows.Forms.FlowLayoutPanel
$panelPrzyciskow.Dock = 'Top'
$panelPrzyciskow.Height = 50
$panelPrzyciskow.Padding = New-Object System.Windows.Forms.Padding(6, 8, 6, 4)

function Przycisk([string]$tekst, [bool]$glowny = $false) {
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
    [void]$panelPrzyciskow.Controls.Add($b)
    $b
}

$lblTryb = New-Object System.Windows.Forms.Label
$lblTryb.Text = 'Ustaw na:'
$lblTryb.AutoSize = $true
$lblTryb.Margin = New-Object System.Windows.Forms.Padding(4, 9, 2, 0)
[void]$panelPrzyciskow.Controls.Add($lblTryb)

$cmbTryb = New-Object System.Windows.Forms.ComboBox
$cmbTryb.DropDownStyle = 'DropDownList'
$cmbTryb.Width = 250
$cmbTryb.Margin = New-Object System.Windows.Forms.Padding(2, 5, 8, 0)
[void]$cmbTryb.Items.Add('Wyłączony (nie uruchomi się wcale)')
[void]$cmbTryb.Items.Add('Ręczny (tylko gdy coś jej potrzebuje)')
$cmbTryb.SelectedIndex = 0
[void]$panelPrzyciskow.Controls.Add($cmbTryb)

$btnWylacz    = Przycisk 'Zastosuj do zaznaczonych' $true
$btnZalecane  = Przycisk 'Zaznacz zalecane'
$btnOdznacz   = Przycisk 'Odznacz wszystko'
$btnOdswiez   = Przycisk 'Odśwież'
$btnDomyslne  = Przycisk 'Przywróć domyślne zaznaczonych'
$btnKopia     = Przycisk 'Przywróć z kopii…'
$btnFolder    = Przycisk 'Otwórz folder z kopiami'

# kolejność dokowania: najpierw Fill, potem Top/Bottom
$panelDol.Controls.Add($logBox)
$panelDol.Controls.Add($panelPrzyciskow)
$form.Controls.Add($grid)
$form.Controls.Add($naglowek)
$form.Controls.Add($panelDol)

# ---------- akcje ----------
$btnZalecane.Add_Click({
    foreach ($r in $grid.Rows) {
        $wyl = ((Get-StartInfo $r.Tag.Nazwa).Start -eq 4)
        $r.Cells[0].Value = (($r.Tag.Rodzaj -eq 'Zalecane') -and (-not $wyl))
    }
})

$btnOdznacz.Add_Click({ foreach ($r in $grid.Rows) { $r.Cells[0].Value = $false } })

$btnOdswiez.Add_Click({ Wypelnij-Liste; Log 'Lista odświeżona.' })

$btnFolder.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$folder`"" })

$btnWylacz.Add_Click({
    if ($cmbTryb.SelectedIndex -eq 1) { $typ = 'demand'; $kod = 3; $nazwaTrybu = 'Ręczny' }
    else { $typ = 'disabled'; $kod = 4; $nazwaTrybu = 'Wyłączony' }
    $wybrane = @(Zaznaczone | Where-Object { (Get-StartInfo $_.Nazwa).Start -ne $kod })
    if ($wybrane.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show("Nie zaznaczono żadnej usługi, która nie jest już ustawiona na: $nazwaTrybu.", 'Brak wyboru', 'OK', 'Information')
        return
    }
    $nazwy = ($wybrane | ForEach-Object { '• ' + $_.Etykieta }) -join [Environment]::NewLine
    if (-not (Pytanie ("Ustawić $($wybrane.Count) usług(i) na: $nazwaTrybu?" + [Environment]::NewLine + [Environment]::NewLine + $nazwy))) { return }

    Zajety $true
    try {
        Log 'Tworzę punkt przywracania (może potrwać do minuty)...'
        try {
            Checkpoint-Computer -Description 'Przed wylaczeniem uslug' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop -WarningAction SilentlyContinue
            Log 'Punkt przywracania gotowy (albo Windows użył tego sprzed < 24 h).'
        } catch {
            Log "UWAGA: nie udało się utworzyć punktu przywracania: $($_.Exception.Message)"
        }

        $dane = @(foreach ($u in $wybrane) {
            $si = Get-StartInfo $u.Nazwa
            $svc = Get-Service -Name $u.Nazwa -ErrorAction SilentlyContinue
            [pscustomobject]@{ Nazwa = $u.Nazwa; Start = $si.Start; Delayed = $si.Delayed; Stan = [string]$svc.Status }
        })
        $plikKopii = Join-Path $folder ('uslugi_{0:yyyyMMdd_HHmmss}.csv' -f (Get-Date))
        $dane | Export-Csv -Path $plikKopii -NoTypeInformation -Encoding UTF8
        Log "Kopia ustawień: $plikKopii"

        $ok = 0; $bledy = 0
        foreach ($d in $dane) {
            $w = Ustaw-Start $d.Nazwa $typ
            if ($w.Ok) {
                if ($typ -eq 'disabled' -and $d.Stan -eq 'Running') { Stop-Service -Name $d.Nazwa -Force -ErrorAction SilentlyContinue }
                Log "Ustawiono ($nazwaTrybu): $($d.Nazwa)"; $ok++
            } else {
                Log "BŁĄD: $($d.Nazwa): $($w.Komunikat)"; $bledy++
            }
        }
        Log "Gotowe. Zmieniono: $ok, błędy: $bledy. Zalecany restart komputera."
    } finally {
        Zajety $false
        Wypelnij-Liste
    }
})

$btnDomyslne.Add_Click({
    $wybrane = @(Zaznaczone)
    if ($wybrane.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show('Zaznacz usługi, którym przywrócić domyślne ustawienia Windows.', 'Brak wyboru', 'OK', 'Information')
        return
    }
    if (-not (Pytanie "Przywrócić domyślne ustawienia Windows dla $($wybrane.Count) usług(i)?")) { return }
    Zajety $true
    try {
        foreach ($u in $wybrane) {
            $w = Ustaw-Start $u.Nazwa $u.Domyslnie
            if ($w.Ok) {
                if ($u.Domyslnie -eq 'auto' -or $u.Domyslnie -eq 'delayed-auto') { Start-Service -Name $u.Nazwa -ErrorAction SilentlyContinue }
                Log "Przywrócono domyślne ($($u.Domyslnie)): $($u.Nazwa)"
            } else {
                Log "BŁĄD: $($u.Nazwa): $($w.Komunikat)"
            }
        }
        Log 'Gotowe.'
    } finally {
        Zajety $false
        Wypelnij-Liste
    }
})

$btnKopia.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = $folder
    $dlg.Filter = 'Kopie usług (uslugi_*.csv)|uslugi_*.csv|Wszystkie pliki (*.*)|*.*'
    $dlg.Title = 'Wybierz kopię ustawień do przywrócenia'
    if ($dlg.ShowDialog() -ne 'OK') { return }
    if (-not (Pytanie "Przywrócić ustawienia z pliku:$([Environment]::NewLine)$($dlg.FileName)?")) { return }
    Zajety $true
    try {
        foreach ($r in Import-Csv -Path $dlg.FileName) {
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
        Wypelnij-Liste
    }
})

$form.Add_Shown({
    Wypelnij-Liste
    Log "Komputer: $env:COMPUTERNAME. Kopie i log: $folder"
    Log 'Usługi, których ten Windows nie ma, nie są pokazywane.'
})

try {
    [void]$form.ShowDialog()
} catch {
    [void][System.Windows.Forms.MessageBox]::Show("Błąd: $($_.Exception.Message)", 'Błąd', 'OK', 'Error')
}
