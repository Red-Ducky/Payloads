Add-Type -AssemblyName System.Windows.Forms

while ($true) {
    [System.Windows.Forms.MessageBox]::Show(
        "Coucou Matheo !",
        "Ton PC s'est fait hacker",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
