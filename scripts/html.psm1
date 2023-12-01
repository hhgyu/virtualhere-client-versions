Function ConvertFrom-Html
{
    <#
        .SYNOPSIS
            Converts a HTML-String to plaintext.

        .DESCRIPTION
            Creates a HtmlObject Com object und uses innerText to get plaintext. 
            If that makes an error it replaces several HTML-SpecialChar-Placeholders and removes all <>-Tags via RegEx.

        .INPUTS
            String. HTML als String

        .OUTPUTS
            String. HTML-Text als Plaintext

        .EXAMPLE
        $html = "<p><strong>Nutzen:</strong></p><p>Der&nbsp;Nutzen ist &uuml;beraus gro&szlig;.<br />Test ob 3 &lt; als 5 &amp; &quot;4&quot; &gt; &apos;2&apos; it?"
        ConvertFrom-Html -Html $html
        $html | ConvertFrom-Html

        Result:
        "Nutzen:
        Der Nutzen ist überaus groß.
        Test ob 3 < als 5 ist & "4" > '2'?"


        .Notes
            Author: Ludwig Fichtinger FILU
            Inital Creation Date: 01.06.2021
            ChangeLog: v2 20.08.2021 try catch with replace for systems without Internet Explorer

    #>

    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = "HTML als String")]
        [AllowEmptyString()]
        [string]$Html
    )

    try
    {
        $HtmlObject = New-Object -Com "HTMLFile"
        $HtmlObject.IHTMLDocument2_write($Html)
        $PlainText = $HtmlObject.documentElement.innerText
    }
    catch
    {
        $nl = [System.Environment]::NewLine
        $PlainText = $Html -replace '<br>',$nl
        $PlainText = $PlainText -replace '<br/>',$nl
        $PlainText = $PlainText -replace '<br />',$nl
        $PlainText = $PlainText -replace '</p>',$nl
        $PlainText = $PlainText -replace '&nbsp;',' '
        $PlainText = $PlainText -replace '&Auml;','Ä'
        $PlainText = $PlainText -replace '&auml;','ä'
        $PlainText = $PlainText -replace '&Ouml;','Ö'
        $PlainText = $PlainText -replace '&ouml;','ö'
        $PlainText = $PlainText -replace '&Uuml;','Ü'
        $PlainText = $PlainText -replace '&uuml;','ü'
        $PlainText = $PlainText -replace '&szlig;','ß'
        $PlainText = $PlainText -replace '&amp;','&'
        $PlainText = $PlainText -replace '&quot;','"'
        $PlainText = $PlainText -replace '&apos;',"'"
        $PlainText = $PlainText -replace '<.*?>',''
        $PlainText = $PlainText -replace '&gt;','>'
        $PlainText = $PlainText -replace '&lt;','<'
    }

    return $PlainText
}