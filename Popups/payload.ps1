Add-Type -AssemblyName System.Windows.Forms

while ($true) {
    [System.Windows.Forms.MessageBox]::Show(
        "Coucou Matheo !",
        "Message",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
