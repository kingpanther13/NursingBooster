; Prepended to the real host by tools/test_host_install.ps1. Exit before any
; CPRS startup code. Exercise the production reader, including legacy migration.
nbCases := []
nbCases.Push({name: "fresh install", data: {}, enabled: 0, channel: "stable", bam: 0})
nbCases.Push({name: "base BAM disabled", data: {83: 1}, enabled: 0, channel: "stable", bam: 1})
nbCases.Push({name: "legacy stable enabled", data: {83: 1, 84: "stable"}, enabled: 1, channel: "stable", bam: 0})
nbCases.Push({name: "legacy dev disabled", data: {83: 0, 84: "master"}, enabled: 0, channel: "master", bam: 0})
nbCases.Push({name: "both enabled and BAM disabled", data: {83: 1, 84: 1, 85: "master"}, enabled: 1, channel: "master", bam: 1})
nbCases.Push({name: "NB disabled preserves BAM", data: {83: 1, 84: 0, 85: "stable"}, enabled: 0, channel: "stable", bam: 1})
nbCases.Push({name: "malformed channel", data: {83: 1, 84: "unknown", 85: "unknown"}, enabled: 0, channel: "stable", bam: 1})
nbCases.Push({name: "not legacy when slot 85 exists", data: {83: 1, 84: "master", 85: "stable"}, enabled: 0, channel: "stable", bam: 1})
for _, nbCase in nbCases {
    nbActual := NB_ReadPreferences(nbCase.data)
    if (nbActual.enabled != nbCase.enabled || nbActual.channel != nbCase.channel || nbActual.disableBAM != nbCase.bam) {
        FileAppend, % "FAIL: " . nbCase.name . "`n", *
        ExitApp, 1
    }
    FileAppend, % "PASS: " . nbCase.name . "`n", *
}
ExitApp, 0
