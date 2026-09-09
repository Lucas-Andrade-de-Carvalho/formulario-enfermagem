$ErrorActionPreference='Stop';$root='ci\work\ETS2-Truck-Visual-Identifier-v2'
$cfg=Get-Content (Join-Path $root 'src\core\current_truck_config.cpp') -Raw -Encoding UTF8
foreach($t in @('assigned_vehicles','player_vehicles','player.assigned_vehicles->player_vehicles.vehicle','accessory_cabin_data','CONFIGURATION_FINGERPRINT')){if(-not$cfg.Contains($t)){throw "Current-truck invariant missing: $t"}}
$paint=Get-Content (Join-Path $root 'src\core\definition_resolver.cpp') -Raw -Encoding UTF8
foreach($t in @('CONFIG_BASE_COLOR_RAW','DEF_BASE_COLOR_RAW','EFFECTIVE_BASE_COLOR_RAW','LINEAR_RGB','DISPLAY_SRGB','COLOR_SPACE','PAINT_FAILURE_REASON')){if(-not$paint.Contains($t)){throw "Paint invariant missing: $t"}}
$local=Get-Content (Join-Path $root 'src\gui\local_configuration.cpp') -Raw -Encoding UTF8
foreach($t in @('Localization module','CURRENT_TRUCK_SAVE_REF','ACTIVE_PROFILE','ACTIVE_SAVE','CONFIGURATION_UNIT')){if(-not$local.Contains($t)){throw "VFS/save/localization invariant missing: $t"}}
$win=Get-Content (Join-Path $root 'src\gui\windows_platform.cpp') -Raw -Encoding UTF8
$uninstallFailed='DESINSTALA'+[char]0x00C7+[char]0x00C3+'O FALHOU';$operationCancelled='OPERA'+[char]0x00C7+[char]0x00C3+'O CANCELADA'
foreach($t in @('install.manifest','PluginOwnership',$uninstallFailed,$operationCancelled,'RunInstallUninstallSelfTest')){if(-not$win.Contains($t)){throw "Uninstall invariant missing: $t"}}
if($win.Contains('static fs::path PluginDest()')){throw 'Removed dead PluginDest() unexpectedly present after audited patch.'}
