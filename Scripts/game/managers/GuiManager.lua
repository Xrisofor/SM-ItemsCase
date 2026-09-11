GuiManager = class()

local GUI_JSON = dofile( "$CONTENT_DATA/Gui/JsonGui/ItemsCase.gui" )
local ITEM_JSON = dofile( "$CONTENT_DATA/Gui/JsonGui/Item.gui" )
ReplaceSubLayouts( GUI_JSON )

GuiManager.Settings = {
    SlotWidth = 108,
    ViewportWidth = 600,
    VisibleSlotsCount = 8,
    CenterX = 600 / 2,
}

local Slots = {}
local isSlotsInit = false

local function addSlots( reelWidget )
    if isSlotsInit or not reelWidget then
        return
    end

    reelWidget.Childs = reelWidget.Childs or {}

    for i = 1, GuiManager.Settings.VisibleSlotsCount do
        local Item = DeepCopy( ITEM_JSON )
        Item.Name = "Item_" .. i

        local Slot = FindWidget( Item, "Slot" )
        local Icon = FindWidget( Item, "Icon" )
        local Quantity = FindWidget( Item, "Quantity" )

        if Slot and Icon then
            Slot.Name = "Slot_" .. i
            Icon.Name = "Icon_" .. i
            Quantity.Name = "Quantity_" .. i

            table.insert( reelWidget.Childs, Item )

            Slots[i] = {
                Item = Item,
                Slot = Slot,
                Icon = Icon,
                Quantity = Quantity,
            }
        end
    end

    isSlotsInit = true
end

function GuiManager.cl_render( self )
    if self.cl.jsonGui then
        self.cl.jsonGui:render( GUI_JSON )
    end
end

function GuiManager.cl_onInteract( self, character, state )
    if not self.cl.jsonGui then
        self.cl.jsonGui = sm.jsonGui.createGui( { isInteractive = true, needsCursor = true } )

        local reelWidget = FindWidget( GUI_JSON, "Reel" )
        if reelWidget and not isSlotsInit then
            addSlots( reelWidget )
        end
    end

    if not self.cl.spinning then
        GuiManager.cl_updateSlots( self, self.cl.currentScrollX or 0 )
    end

    GuiManager.cl_render( self )
end

function GuiManager.cl_onClose( self )
    if self.cl.jsonGui then
        self.cl.jsonGui:close()
        self.cl.jsonGui = nil
    end
end

function GuiManager.cl_onUnlockClick( self, _ )
    if self.cl.spinning then
        return
    end

    self.network:sendToServer( "server_onSpinRequest" )
end

function GuiManager.cl_updateSlots( self, scrollX )
    if not ( self.cl.reel and #self.cl.reel > 0 ) then
        return
    end

    local firstVisibleIndex = math.floor( scrollX / GuiManager.Settings.SlotWidth ) + 1

    for i = 1, GuiManager.Settings.VisibleSlotsCount do
        local slotData = Slots[i]

        if slotData and slotData.Item then
            local itemIndex = firstVisibleIndex + ( i - 1 )

            if itemIndex >= 1 and itemIndex <= #self.cl.reel then
                local posX = math.floor( ( ( itemIndex - 1 ) * GuiManager.Settings.SlotWidth ) - scrollX )
                slotData.Item.x = posX

                local entry = self.cl.reel[itemIndex]

                if slotData.LastEntry ~= entry then
                    slotData.LastEntry = entry

                    slotData.Slot.ImageTexture = "$CONTENT_c5b0dbb5-6e03-450b-acb1-03fe5909ecc0/Gui/Rarity/" .. entry.rarity .. ".png"
                    slotData.Quantity.Caption = entry.quantity and tostring( entry.quantity ) or ""

                    slotData.Slot.RenderDepth = 0

                    local resource, group, name = sm.gui.getItemIconFromUuid( sm.uuid.new( entry.uuid ) )
                    if resource then
                        slotData.Icon.ImageResource = resource
                        slotData.Icon.ImageGroup = group
                        slotData.Icon.ImageName = name
                    end
                end
            else
                slotData.Item.x = -999
                slotData.LastEntry = nil
            end
        end
    end
end