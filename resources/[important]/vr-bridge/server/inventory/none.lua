local I = { name = 'none' }
function I.items() return {} end
function I.count() return 0 end
function I.has() return false end
function I.add() return false end
function I.remove() return false end
function I.removeExact() return false end
function I.canCarry() return false end
function I.itemExists() return false end
function I.label() return nil end
function I.item() return nil end
function I.itemDefs() return {} end
function I.search() return {} end
function I.getSlot() return nil end
function I.setMetadata() return false end
function I.registerStash() return false end
function I.openStash() return false end
function I.stashItems() return {} end
function I.stashAdd() return false end
function I.stashRemove() return false end
function I.registerShop() return false end
function I.confiscate() return false end
function I.giveBack() return false end
function I.clear() return false end
function I.onCreateItem() return nil end
function I.image() return nil end
return I
