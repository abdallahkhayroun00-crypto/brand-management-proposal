param([Parameter(Mandatory=$true)][string]$JobPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$job = Get-Content -LiteralPath $JobPath -Raw -Encoding UTF8 | ConvertFrom-Json
$doc = New-Object System.Drawing.Printing.PrintDocument
$logo = $null
$font = New-Object System.Drawing.Font('Arial', 10)
try {
  $installed = @([System.Drawing.Printing.PrinterSettings]::InstalledPrinters)
  if ($installed -notcontains [string]$job.printer) { throw 'Configured printer is not installed' }
  if ([string]$job.printer -match 'Print to PDF|XPS Document') { throw 'Choose the physical receipt printer, not a file dialog printer' }
  $doc.PrinterSettings.PrinterName = [string]$job.printer
  if (-not $doc.PrinterSettings.IsValid) { throw 'Invalid printer' }
  $doc.DocumentName = 'Nohut Falafel - Receipt'
  $doc.PrintController = New-Object System.Drawing.Printing.StandardPrintController
  $doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(8,8,8,8)
  $logo = [System.Drawing.Image]::FromFile([string]$job.logo)
  $script:rows = @(([string]$job.text) -split "`n")
  $script:row = 0
  $script:firstPage = $true
  $doc.add_PrintPage({
    param($sender,$e)
    $g = $e.Graphics
    $width = [Math]::Min(280, $e.PageSettings.PrintableArea.Width - 16)
    if ($width -lt 100) { throw 'Receipt driver paper width is too narrow' }
    $x = [Math]::Max(8, $e.PageSettings.HardMarginX)
    $y = [Math]::Max(8, $e.PageSettings.HardMarginY)
    if ($script:firstPage) {
      $g.DrawImage($logo, [single]($x+($width-135)/2), [single]$y, [single]135, [single]135)
      $y += 145
      $script:firstPage = $false
    }
    $limit = $e.PageSettings.PrintableArea.Height - 15
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
