$ErrorActionPreference='Stop'
$manifestPath='ci\visual-audit-src.manifest.txt'
if(-not(Test-Path $manifestPath)){throw 'Chunk manifest missing.'}
$lines=[IO.File]::ReadAllLines((Resolve-Path $manifestPath),[Text.Encoding]::ASCII)
$countLine=$lines|Where-Object{$_ -like 'PART_COUNT=*'}|Select-Object -First 1
$finalLine=$lines|Where-Object{$_ -like 'EXPECTED_FINAL_SHA256=*'}|Select-Object -First 1
if(-not$countLine-or-not$finalLine){throw 'Manifest header incomplete.'}
$expectedCount=[int]($countLine.Split('=',2)[1]);$expectedFinal=$finalLine.Split('=',2)[1].ToLowerInvariant()
if($expectedCount-ne9){throw "Unexpected PART_COUNT=$expectedCount"}
if($expectedFinal-ne'dde42fcf89b07c820fe9953a743cae8915d5c1f65a7853ee42d1db52d084625c'){throw "Unexpected manifest final SHA=$expectedFinal"}
$rows=@{}
foreach($line in $lines|Where-Object{$_ -like 'PART=*'}){
  $fields=@{};foreach($cell in $line.Split('|')){$kv=$cell.Split('=',2);if($kv.Count-ne2){throw "Malformed manifest row: $line"};$fields[$kv[0]]=$kv[1]}
  $idx=[int]$fields['PART'];if($rows.ContainsKey($idx)){throw "Duplicate manifest index: $idx"};$rows[$idx]=$fields
}
if($rows.Count-ne$expectedCount){throw "Manifest row count mismatch: $($rows.Count)"}
$remoteParts=@(Get-ChildItem 'ci\visual-audit-src.part*.b64' -File)
if($remoteParts.Count-ne$expectedCount){throw "PARTS FOUND=$($remoteParts.Count), EXPECTED=$expectedCount"}
$expectedNames=0..8|ForEach-Object{'visual-audit-src.part{0:D2}.b64'-f$_}
foreach($p in $remoteParts){if($expectedNames-notcontains$p.Name){throw "Unexpected audited source part: $($p.Name)"}}
$archive='ci\audited-source.tar.gz';if(Test-Path $archive){Remove-Item $archive -Force}
$out=[IO.File]::Open($archive,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
  for($i=0;$i-lt$expectedCount;$i++){
    $row=$rows[$i];$name=$row['NAME'];$path=Join-Path 'ci' $name
    if($name-ne('visual-audit-src.part{0:D2}.b64'-f$i)){throw "Manifest order/name mismatch at ${i}: $name"}
    if(-not(Test-Path $path)){throw "Missing part ${i}: $path"}
    [byte[]]$raw=[IO.File]::ReadAllBytes((Resolve-Path $path))
    if($raw.Length-ne[int]$row['SIZE']){throw "Part $i size mismatch expected=$($row['SIZE']) actual=$($raw.Length)"}
    $actualPart=(Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant();if($actualPart-ne$row['SHA256'].ToLowerInvariant()){throw "Part $i SHA mismatch expected=$($row['SHA256']) actual=$actualPart"}
    foreach($b in $raw){if($b-gt127){throw "Part $i contains non-ASCII byte: $b"};if($b-eq10-or$b-eq13-or$b-eq32-or$b-eq9){throw "Part $i contains whitespace byte: $b"}}
    $text=[Text.Encoding]::ASCII.GetString($raw);if(($text.Length%4)-ne0-or$text-notmatch'^[A-Za-z0-9+/]*={0,2}$'){throw "Part $i is not strict Base64"}
    try{[byte[]]$decoded=[Convert]::FromBase64String($text)}catch{throw "Part $i Base64 decode failed: $($_.Exception.Message)"}
    $out.Write($decoded,0,$decoded.Length);Write-Host "PART $i VERIFIED size=$($raw.Length) sha256=$actualPart decoded=$($decoded.Length)"
  }
}finally{$out.Dispose()}
$actualFinal=(Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "PARTS EXPECTED: $expectedCount";Write-Host "PARTS FOUND: $($remoteParts.Count)";Write-Host 'MISSING: 0';Write-Host 'UNEXPECTED: 0';Write-Host 'DUPLICATES: 0';Write-Host "EXPECTED_SOURCE_SHA256=$expectedFinal";Write-Host "ACTUAL_SOURCE_SHA256=$actualFinal"
if($actualFinal-ne$expectedFinal){throw "Reconstructed source SHA mismatch expected=$expectedFinal actual=$actualFinal"}
$entries=@(& tar -tzf $archive);if($LASTEXITCODE-ne0-or-not$entries){throw 'Archive listing failed or archive empty.'}
foreach($entry in $entries){$n=$entry.Replace('\','/');if($n.StartsWith('/')-or$n-match'^[A-Za-z]:'-or($n.Split('/')-contains'..')){throw "Unsafe archive path: $entry"}}
if($entries-notcontains'ETS2-Truck-Visual-Identifier-v2/CMakeLists.txt'){throw 'Expected source root missing from archive.'}
$work='ci\work';if(Test-Path $work){Remove-Item $work -Recurse -Force};New-Item -ItemType Directory -Force $work|Out-Null
& tar -xzf $archive -C $work;if($LASTEXITCODE-ne0){throw "Source extraction failed: $LASTEXITCODE"}
$root=Join-Path $work 'ETS2-Truck-Visual-Identifier-v2'
foreach($f in @('CMakeLists.txt','tools\build-windows.ps1','src\core\current_truck_config.cpp','src\core\definition_resolver.cpp','src\gui\local_configuration.cpp','src\gui\windows_platform.cpp','src\gui\windows_integration_tests.cpp','tests\core_tests.cpp')){if(-not(Test-Path(Join-Path $root $f))){throw "Extracted source missing: $f"}}
Add-Content $env:GITHUB_ENV "SOURCE_SHA256=$actualFinal";Add-Content $env:GITHUB_ENV "SOURCE_BRANCH=$env:GITHUB_REF_NAME";Add-Content $env:GITHUB_ENV "SOURCE_COMMIT=$env:GITHUB_SHA"
@("SOURCE_ARCHIVE_SHA256=$actualFinal","BRANCH=$env:GITHUB_REF_NAME","COMMIT=$env:GITHUB_SHA")|Set-Content -Encoding ASCII 'ci\SOURCE_PROVENANCE.txt'
