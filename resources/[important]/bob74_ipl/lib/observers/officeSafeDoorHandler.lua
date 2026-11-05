local _scanDelay = 500

CreateThread(function()
    while true do
        local office = 0

        if Global.FinanceOffices.isInsideOffice1 then
            office = FinanceOffice1
        elseif Global.FinanceOffices.isInsideOffice2 then
            office = FinanceOffice2
        elseif Global.FinanceOffices.isInsideOffice3 then
            office = FinanceOffice3
        elseif Global.FinanceOffices.isInsideOffice4 then
            office = FinanceOffice4
        end

        if office ~= 0 then

            doorHandle = office.Safe.GetDoorHandle(office.currentSafeDoors.hashL)

            if doorHandle ~= 0 then
                if office.Safe.isLeftDoorOpen then
                    office.Safe.SetDoorState("left", true)
                else
                    office.Safe.SetDoorState("left", false)
                end
            end

            doorHandle = office.Safe.GetDoorHandle(office.currentSafeDoors.hashR)

            if doorHandle ~= 0 then
                if office.Safe.isRightDoorOpen then
                    office.Safe.SetDoorState("right", true)
                else
                    office.Safe.SetDoorState("right", false)
                end
            end
        end

        Wait(_scanDelay)
    end
end)
