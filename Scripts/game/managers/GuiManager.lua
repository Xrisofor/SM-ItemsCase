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

local function updateButton( self )
    local button = FindWidget( GUI_JSON, "UnlockButton" )
    local text = FindWidget( GUI_JSON, "UnlockText" )

    button.Enabled = not self.cl.spinning
    text.Caption = self.cl.spinning and "#{UNLOCKED}" or "#{UNLOCK}"
end

function GuiManager.cl_render( self )
    if self.cl.jsonGui then
        updateButton( self )
        self.cl.jsonGui:render( GUI_JSON )
    end
end

function GuiManager.cl_onInteract( self, character, state )
    if not self.cl.jsonGui then
        self.cl.jsonGui = sm.jsonGui.createGui( { isInteractive = true, needsCursor = true } )
        
        if self.cl.reel and #self.cl.reel > 0 then
            GuiManager.cl_addSlots( self )
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
        Slots = {}
    end
end

function GuiManager.cl_onUnlockClick( self, _ )
    if self.cl.spinning then
        return
    end

    self.network:sendToServer( "server_onSpinRequest" )
end

local Slots = {}

function GuiManager.cl_addSlots( self )
    local reelWidget = FindWidget( GUI_JSON, "Reel" )
    reelWidget.Childs = {}
    Slots = {}

    for index, entry in ipairs( self.cl.reel ) do
        local Item = DeepCopy( ITEM_JSON )
        Item.Name = "Item_" .. index

        local Slot = FindWidget( Item, "Slot" )
        local Icon = FindWidget( Item, "Icon" )
        local Quantity = FindWidget( Item, "Quantity" )

        Slot.Name = "Slot_" .. index
        Icon.Name = "Icon_" .. index
        Quantity.Name = "Quantity_" .. index

        Slot.ImageTexture = "$CONTENT_c5b0dbb5-6e03-450b-acb1-03fe5909ecc0/Gui/Rarity/" .. entry.rarity .. ".png"
        Quantity.Caption = entry.quantity and tostring( entry.quantity ) or ""

        local resource, group, name = sm.gui.getItemIconFromUuid( sm.uuid.new( entry.uuid ) )
        if resource then
            Icon.ImageResource = resource
            Icon.ImageGroup = group
            Icon.ImageName = name
        end

        table.insert( reelWidget.Childs, Item )
        Slots[index] = Item
    end
end

function GuiManager.cl_updateSlots( self, scrollX )
    if not self.cl.reel then return end

    local slotW = GuiManager.Settings.SlotWidth
    local viewW = GuiManager.Settings.ViewportWidth

    for index, itemWidget in ipairs( Slots ) do
        local posX = math.floor( ( ( index - 1 ) * slotW ) - scrollX )

        if posX >= -slotW and posX <= viewW then
            itemWidget.Visible = true
            itemWidget.x = posX
        else
            itemWidget.Visible = false
        end
    end
end