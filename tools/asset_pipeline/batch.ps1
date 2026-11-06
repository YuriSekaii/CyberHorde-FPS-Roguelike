# Builds every manifest asset whose concept image exists in Reference\AssetGen\<name>.png and whose
# assets\models\<name>\<name>.glb doesn't exist yet. Tier 3 (rigged) assets only get the raw mesh + prep;
# rigging them is a separate step (see docs/ASSET_PIPELINE.md).
# Usage: powershell -ExecutionPolicy Bypass -File tools\asset_pipeline\batch.ps1 [-Force] [-Only name1,name2]
param([switch]$Force, [string[]]$Only = @())
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
foreach ($a in Import-Csv "$PSScriptRoot\assets_manifest.csv") {
    if ($Only.Count -and $a.name -notin $Only) { continue }
    $img = "$repo\Reference\AssetGen\$($a.name).png"
    $out = "$repo\assets\models\$($a.name)\$($a.name).glb"
    if (-not (Test-Path $img)) { continue }
    if ((Test-Path $out) -and -not $Force) { Write-Output "SKIP $($a.name) (already built)"; continue }
    $back = "$repo\Reference\AssetGen\$($a.name)_back.png"
    $p = @{ Name = $a.name; Height = [double]$a.height_m; Tris = [int]$a.max_tris; Tex = [int]$a.tex_px; Yaw = [double]$a.yaw_deg; Desat = [double]$a.desat }
    if (Test-Path $back) { $p.Back = $back }
    try { & "$PSScriptRoot\make_asset.ps1" @p } catch { Write-Output "FAIL $($a.name): $_" }
}
