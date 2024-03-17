function Convert-DiacriticCharacters {
    param(
        [string]$inputString
    )
    [string]$formD = $inputString.Normalize(
            [System.text.NormalizationForm]::FormD
    )
    $stringBuilder = new-object System.Text.StringBuilder
    for ($i = 0; $i -lt $formD.Length; $i++){
        $unicodeCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($formD[$i])
        $nonSPacingMark = [System.Globalization.UnicodeCategory]::NonSpacingMark
        if($unicodeCategory -ne $nonSPacingMark){
            $stringBuilder.Append($formD[$i]) | out-null
        }
    }
    $stringBuilder.ToString().Normalize([System.text.NormalizationForm]::FormC)
}