CreateThread(function()

    Michael.LoadDefault()

    Simeon.LoadDefault()

    FranklinAunt.LoadDefault()

    Franklin.LoadDefault()

    Floyd.LoadDefault()

    TrevorsTrailer.LoadDefault()

    BahamaMamas.Enable(true)

    PillboxHospital.Enable(true)

    ZancudoGates.LoadDefault()

    Ammunations.LoadDefault()
    LesterFactory.LoadDefault()
    StripClub.LoadDefault()
    CargoShip.LoadDefault()

    Graffitis.Enable(true)

    UFO.Hippie.Enable(false)
    UFO.Chiliad.Enable(false)
    UFO.Zancudo.Enable(false)

    RedCarpet.Enable(false)

    NorthYankton.Enable(false)

    GTAOApartmentHi1.LoadDefault()
    GTAOApartmentHi2.LoadDefault()
    GTAOHouseHi1.LoadDefault()
    GTAOHouseHi2.LoadDefault()
    GTAOHouseHi3.LoadDefault()
    GTAOHouseHi4.LoadDefault()
    GTAOHouseHi5.LoadDefault()
    GTAOHouseHi6.LoadDefault()
    GTAOHouseHi7.LoadDefault()
    GTAOHouseHi8.LoadDefault()
    GTAOHouseMid1.LoadDefault()
    GTAOHouseLow1.LoadDefault()

    HLApartment1.LoadDefault()
    HLApartment2.LoadDefault()
    HLApartment3.LoadDefault()
    HLApartment4.LoadDefault()
    HLApartment5.LoadDefault()
    HLApartment6.LoadDefault()

    HeistCarrier.Enable(true)
    HeistYacht.LoadDefault()

    ExecApartment1.LoadDefault()
    ExecApartment2.LoadDefault()
    ExecApartment3.LoadDefault()

    FinanceOffice1.LoadDefault()
    FinanceOffice2.LoadDefault()
    FinanceOffice3.LoadDefault()
    FinanceOffice4.LoadDefault()

    BikerCocaine.LoadDefault()
    BikerCounterfeit.LoadDefault()
    BikerDocumentForgery.LoadDefault()
    BikerMethLab.LoadDefault()
    BikerWeedFarm.LoadDefault()
    BikerClubhouse1.LoadDefault()
    BikerClubhouse2.LoadDefault()

    ImportCEOGarage1.LoadDefault()
    ImportCEOGarage2.LoadDefault()
    ImportCEOGarage3.LoadDefault()
    ImportCEOGarage4.LoadDefault()
    ImportVehicleWarehouse.LoadDefault()

    GunrunningBunker.LoadDefault()
    GunrunningYacht.LoadDefault()

    SmugglerHangar.LoadDefault()

    DoomsdayFacility.LoadDefault()

    AfterHoursNightclubs.LoadDefault()

    if GetGameBuildNumber() >= 2060 then
        DiamondCasino.LoadDefault()
        DiamondPenthouse.LoadDefault()
        DiamondArcade.LoadDefault()
        DiamondArcadeBasement.LoadDefault()
    end

    if GetGameBuildNumber() >= 2189 then
        CayoPericoNightclub.LoadDefault()
        CayoPericoSubmarine.LoadDefault()
    end

    if GetGameBuildNumber() >= 2372 then
        TunerGarage.LoadDefault()
        TunerMethLab.LoadDefault()
        TunerMeetup.LoadDefault()
    end

    if GetGameBuildNumber() >= 2545 then
        MpSecurityGarage.LoadDefault()
        MpSecurityMusicRoofTop.LoadDefault()
        MpSecurityStudio.LoadDefault()
        MpSecurityBillboards.LoadDefault()
        MpSecurityOffice1.LoadDefault()
        MpSecurityOffice2.LoadDefault()
        MpSecurityOffice3.LoadDefault()
        MpSecurityOffice4.LoadDefault()
    end

    if GetGameBuildNumber() >= 2699 then
        CriminalEnterpriseSmeonFix.LoadDefault()
        CriminalEnterpriseVehicleWarehouse.LoadDefault()
        CriminalEnterpriseWarehouse.LoadDefault()
    end

    if GetGameBuildNumber() >= 2802 then
        DrugWarsFreakshop.LoadDefault()
        DrugWarsGarage.LoadDefault()
        DrugWarsLab.LoadDefault()
    end

    if GetGameBuildNumber() >= 2944 then
        MercenariesClub.LoadDefault()
        MercenariesLab.LoadDefault()
        MercenariesFixes.LoadDefault()
    end

    if GetGameBuildNumber() >= 3095 then
        ChopShopCargoShip.LoadDefault()
        ChopShopCartelGarage.LoadDefault()
        ChopShopLifeguard.LoadDefault()
        ChopShopSalvage.LoadDefault()
    end

    if GetGameBuildNumber() >= 3258 then
        SummerCarrier.LoadDefault()
        SummerOffice.LoadDefault()
    end

    if GetGameBuildNumber() >= 3407 then
        AgentsFactory.LoadDefault()
        AgentsOffice.LoadDefault()
        AgentsAirstrip.LoadDefault()
        AgentsHangarDoor.LoadDefault()
    end

    if IsDlcPresent(`mp2025_01`) then
        MoneyCarwash.LoadDefault()
        MoneyOffice.LoadDefault()
    end

    if IsDlcPresent(`mp2025_02`) then
        Mansion1.LoadDefault()
        Mansion2.LoadDefault()
        Mansion3.LoadDefault()
        MansionBasement1.LoadDefault()
        MansionBasement2.LoadDefault()
        MansionBasement3.LoadDefault()
    end

    if IsDlcPresent(`mp2026_01`) then
        KortzMuseum.LoadDefault()
        KortzExhibition.LoadDefault()
        KortzBasement.LoadDefault()
        KortzLoadingBay.LoadDefault()
        KortzWorkshop.LoadDefault()
    end
end)
