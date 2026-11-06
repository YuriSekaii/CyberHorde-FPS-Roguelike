# One asset: concept image -> Hunyuan3D-2 (local GPU) -> Blender prep -> assets/models/<Name>/<Name>.glb -> Godot import
# Usage: powershell -ExecutionPolicy Bypass -File tools\asset_pipeline\make_asset.ps1 -Name cyber_swarmer -Height 1.1 -Tris 4000
#   -Image defaults to Reference\AssetGen\<Name>.png ; optional -Back <png> (back view), -Tex 1024, -Yaw 0, -Octree 380
param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [double]$Height,
    [Parameter(Mandatory)] [int]$Tris,
    [string]$Image = "",
    [string]$Back = "",
    [int]$Tex = 1024,
    [double]$Yaw = 0,
    [int]$Octree = 380,
    [string]$Hunyuan = "D:\AI\Hunyuan3D-2",
    [string]$Blender = "D:\Blender\Blender-5.2.4\blender.exe",
    [string]$Work = "D:\AI\gen"
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
if (-not $Image) { $Image = "$repo\Reference\AssetGen\$Name.png" }
if (-not (Test-Path $Image)) { throw "Concept image not found: $Image" }
$w = "$Work\$Name"; New-Item -ItemType Directory -Force $w | Out-Null
$raw = "$w\raw.glb"

if (-not (Test-Path $raw)) {  # delete raw.glb to regenerate; otherwise only the cheap prep step reruns
    $env:HY3DGEN_MODELS = "D:\AI\hy3dgen_models"; $env:HF_HOME = "D:\AI\hf_cache"; $env:OCTREE = "$Octree"
    $args_ = @("$Hunyuan\make_model.py", $Image, $raw); if ($Back) { $args_ += $Back }
    & "$Hunyuan\.venv\Scripts\python.exe" @args_ 2>&1 | Select-String "DONE|Traceback|Error" | ForEach-Object { $_.Line }
    if (-not (Test-Path $raw)) { throw "Hunyuan generation failed for $Name" }
}

$outDir = "$repo\assets\models\$Name"; New-Item -ItemType Directory -Force $outDir | Out-Null
& $Blender -b --factory-startup --python "$PSScriptRoot\prep_prop.py" -- $raw "$outDir\$Name.glb" $Height $Tris $Tex $Yaw "$w\preview.png" 2>&1 |
    Select-String "PREP|Error" | ForEach-Object { $_.Line }
& "$repo\Godot_v4.7.2-stable_win64_console.exe" --headless --path $repo --import 2>&1 | Out-Null
Write-Output "ASSET $Name -> assets\models\$Name\$Name.glb ; previews: $w\preview_front.png, $w\preview_q34.png"
