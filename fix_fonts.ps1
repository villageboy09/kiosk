$pattern = "fontFamily:\s*'Google Sans',?"
Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse | Where-Object { $_.Name -ne 'app_theme.dart' } | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match $pattern) {
        $content = $content -replace $pattern, ''
        Set-Content $_.FullName $content
    }
}
