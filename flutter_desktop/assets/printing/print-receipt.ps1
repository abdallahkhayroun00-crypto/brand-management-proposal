param([Parameter(Mandatory=$true)][string]$JobPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$job = Get-Content -LiteralPath $JobPath -Raw -Encoding UTF8 | ConvertFrom-Json
$doc = New-Object System.Drawing.Printing.PrintDocument
$logo = $null
$font = New-Object System.Drawing.Font('Arial', 10)
try {
  $installed = @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters)
  $printerName = [string]$job.printer
  if ($installed -notcontains $printerName -and $printerName -eq 'XP-237B') {
    $matches = @($installed | Where-Object { $_ -match '(?i)XP[ -]?237B(?:$|[^A-Z0-9])' })
    if ($matches.Count -eq 1) { $printerName = [string]$matches[0] }
    elseif ($matches.Count -gt 1) { throw 'Multiple XP-237B printers found. Select the exact Windows name in Settings.' }
  }
  if ($installed -notcontains $printerName) { throw 'Configured printer is not installed' }
  if ($printerName -match 'Print to PDF|XPS Document') { throw 'Choose the physical receipt printer, not a file dialog printer' }
  $doc.PrinterSettings.PrinterName = $printerName
  if (-not $doc.PrinterSettings.IsValid) { throw 'Invalid printer' }
  $doc.DocumentName = 'Nohut Falafel - Receipt'
  $doc.PrintController = New-Object System.Drawing.Printing.StandardPrintController
  $doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(8,8,8,8)
  $logo = [System.Drawing.Image]::FromFile([string]$job.logo)
  $script:rows = @(([string]$job.text) -split "`n")
  # A roll driver can default to a very long page. Size this job to its content.
  # XP-237B: 58 mm media, 48 mm / 384-dot printable area. Units: 1/100 inch.
  $paperWidth = 228
  $contentWidth = 189
  $measureBitmap = New-Object System.Drawing.Bitmap(1,1)
  $measureBitmap.SetResolution(100,100)
  $measure = [System.Drawing.Graphics]::FromImage($measureBitmap)
  try {
    $paperHeight = 175
    foreach ($line in $script:rows) {
      $paperHeight += [Math]::Max(16, $measure.MeasureString([string]$line, $font, [int]$contentWidth).Height + 4)
    }
    $doc.DefaultPageSettings.PaperSize = New-Object System.Drawing.Printing.PaperSize('Nohut Receipt', [int]$paperWidth, [int][Math]::Min(32000,[Math]::Ceiling($paperHeight)))
  } finally { $measure.Dispose(); $measureBitmap.Dispose() }
  $script:row = 0
  $script:firstPage = $true
  $doc.add_PrintPage({
    param($sender,$e)
    $g = $e.Graphics
    $width = $contentWidth
    $availableWidth = [Math]::Min($contentWidth, $e.PageSettings.PrintableArea.Width - 4)
    $availableHeight = $e.PageSettings.PrintableArea.Height - 16
    if ($availableWidth -lt 100 -or $availableHeight -lt 100) { throw 'Receipt driver printable area is too small' }
    # Shrink oversized pages by default; never enlarge a receipt that already fits.
    $fit = [Math]::Min(1.0, [Math]::Min($availableWidth/$contentWidth, $availableHeight/$paperHeight))
    $g.TranslateTransform([single][Math]::Max(0,$e.PageSettings.HardMarginX), [single]8)
    $g.ScaleTransform([single]$fit, [single]$fit)
    $x = 0
    $y = 0
    if ($script:firstPage) {
      $g.DrawImage($logo, [single]($x+($width-135)/2), [single]$y, [single]135, [single]135)
      $y += 145
      $script:firstPage = $false
    }
    $limit = $availableHeight / $fit - 4
    while ($script:row -lt $script:rows.Count) {
      $line = [string]$script:rows[$script:row]
      $height = [Math]::Max(16, $g.MeasureString($line, $font, [int]$width).Height + 4)
      if ($y + $height -gt $limit) { $e.HasMorePages = $true; return }
      $rect = New-Object System.Drawing.RectangleF([single]$x,[single]$y,[single]$width,[single]$height)
      $g.DrawString($line, $font, [System.Drawing.Brushes]::Black, $rect)
      $y += $height
      $script:row++
    }
    $e.HasMorePages = $false
  })
  $doc.Print()
} finally {
  if ($logo) { $logo.Dispose() }
  $font.Dispose()
  $doc.Dispose()
}
