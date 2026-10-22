; Prepended to the real host by tools/test_host_install.ps1. Exit before any
; CPRS startup code. Exercise the production reader, including legacy migration.
nbCases := []
nbCases.Push({name: "fresh install", data: {}, enabled: 0, channel: "stable", bam: 0, migrated: false})
nbCases.Push({name: "base BAM disabled", data: {83: 1}, enabled: 0, channel: "stable", bam: 1, migrated: false})
nbCases.Push({name: "legacy stable enabled", data: {83: 1, 84: "stable"}, enabled: 1, channel: "stable", bam: 0, migrated: true})
nbCases.Push({name: "legacy dev disabled", data: {83: 0, 84: "master"}, enabled: 0, channel: "master", bam: 0, migrated: true})
nbCases.Push({name: "both enabled and BAM disabled", data: {83: 1, 84: 1, 85: "master"}, enabled: 1, channel: "master", bam: 1, migrated: false})
nbCases.Push({name: "NB disabled preserves BAM", data: {83: 1, 84: 0, 85: "stable"}, enabled: 0, channel: "stable", bam: 1, migrated: false})
nbCases.Push({name: "malformed channel", data: {83: 1, 84: "unknown", 85: "unknown"}, enabled: 0, channel: "stable", bam: 1, migrated: false})
nbCases.Push({name: "not legacy when slot 85 exists", data: {83: 1, 84: "master", 85: "stable"}, enabled: 0, channel: "stable", bam: 1, migrated: false})
for _, nbCase in nbCases {
    nbActual := NB_ReadPreferences(nbCase.data)
    if (nbActual.migrated != nbCase.migrated || nbActual.enabled != nbCase.enabled || nbActual.channel != nbCase.channel || nbActual.disableBAM != nbCase.bam) {
        FileAppend, % "FAIL: " . nbCase.name . "`n", *
        ExitApp, 1
    }
    ; Exercise the host's actual serializer. The BAM helper reads disk slot 83,
    ; so an in-memory-only migration is insufficient for existing installs.
    NB_Enabled := nbActual.enabled
    NB_Channel := nbActual.channel
    DisableBAM := nbActual.disableBAM
    Code := "synthetic-test-code"
    RN1 := "synthetic-nurse"
    fxn := []
    NoteFavsArray := []
    filename := A_ScriptDir . "\preferences-test.txt"
    gosub writingdetails
    FileReadLine, nbDiskBAM, %filename%, 83
    FileReadLine, nbDiskEnabled, %filename%, 84
    FileReadLine, nbDiskChannel, %filename%, 85
    FileReadLine, nbDiskNurse, %filename%, 3
    if (nbDiskBAM != nbCase.bam || nbDiskEnabled != nbCase.enabled || nbDiskChannel != nbCase.channel || nbDiskNurse != RN1) {
        FileAppend, % "FAIL: persisted " . nbCase.name . "`n", *
        ExitApp, 1
    }
    nbReloaded := NB_ReadPreferences({83: nbDiskBAM, 84: nbDiskEnabled, 85: nbDiskChannel})
    if (nbReloaded.migrated || nbReloaded.enabled != nbCase.enabled || nbReloaded.channel != nbCase.channel || nbReloaded.disableBAM != nbCase.bam) {
        FileAppend, % "FAIL: reloaded " . nbCase.name . "`n", *
        ExitApp, 1
    }
    FileAppend, % "PASS: " . nbCase.name . "`n", *
}
ExitApp, 0
