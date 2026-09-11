SpinManager = class()

SpinManager.Settings = {
    SpinTicks = 220,
    WinIndex = 60,
    ReelLength = 75,
    PoolSize = 12,
    SpinDuration = 220 / 40,
    TickEffect = "Gui - Click",
    StartEffect = "Gui - ChestOpen",
    DestroyEffect = "PropaneTank - ExplosionSmall",
}

local function getCenterSlotIndex( scrollX )
    return math.floor( ( scrollX + GuiManager.Settings.CenterX ) / GuiManager.Settings.SlotWidth )
end

function SpinManager.sv_onCreate( self )
    self.sv = {
        activeSpin = nil,
    }
end

function SpinManager.sv_onRefresh( self )
    self.sv = self.sv or {}
end

function SpinManager.sv_onFixedUpdate( self )
    if not ( self.sv and self.sv.activeSpin ) then
        return
    end

    local spin = self.sv.activeSpin
    spin.ticksLeft = spin.ticksLeft - 1

    if spin.ticksLeft <= 0 then
        SpinManager.sv_giveReward( self, spin.player, sm.uuid.new( spin.winUuid ), spin.winQuantity )
        self.sv.activeSpin = nil
    end
end

local function buildReel( self )
    local allowedTiers = self.data and self.data.rarity
    local blockPool = RarityManager.getRandomBlocks( SpinManager.Settings.PoolSize, allowedTiers )

    local reelTape = {}
    for i = 1, SpinManager.Settings.ReelLength do
        local block = blockPool[math.random( 1, #blockPool )]
        table.insert( reelTape, {
            uuid = block,
            rarity = RarityManager.getRarity( block ),
            quantity = RarityManager.getItemQuantity( block )
        } )
    end

    return reelTape
end

function SpinManager.sv_onSpinRequest( self, params, player )
    if self.sv.activeSpin then
        return
    end

    local reelTape = buildReel( self )
    local winEntry = reelTape[SpinManager.Settings.WinIndex]

    self.sv.activeSpin = {
        player = player,
        ticksLeft = SpinManager.Settings.SpinTicks,
        winUuid = winEntry.uuid,
        winQuantity = winEntry.quantity or 1,
    }

    self.network:sendToClient( player, "client_onSpinStarted", {
        reel = reelTape,
        winIndex = SpinManager.Settings.WinIndex,
        duration = SpinManager.Settings.SpinDuration,
    } )
end

function SpinManager.sv_onPreviewRequest( self, params, player )
    local reelTape = buildReel( self )

    self.network:sendToClient( player, "client_onPreviewReel", {
        reel = reelTape,
    } )
end

function SpinManager.sv_giveReward( self, player, itemUuid, quantity )
    if not sm.exists( player ) then
        return
    end

    sm.container.beginTransaction()
    sm.container.collect( player:getInventory(), itemUuid, quantity )

    if not sm.container.endTransaction() then
        local char = player:getCharacter()
        local dropPos = char and char.worldPosition or self.shape.worldPosition

        SpawnLoot( player, { { uuid = itemUuid, quantity = quantity or 1, epic = false } }, dropPos, nil, 2 )
    end

    -- NotificationManager.Sv_SchematicUnlocked( itemUuid )

    sm.effect.playEffect( SpinManager.Settings.DestroyEffect, self.shape.worldPosition )
    self.shape:destroyShape( 0 )
end

function SpinManager.cl_onSpinStarted( self, data )
    self.cl.reel = data.reel
    self.cl.winIndex = data.winIndex
    self.cl.spinDuration = data.duration or SpinManager.Settings.SpinDuration
    self.cl.spinTimer = 0
    self.cl.spinning = true

    local winningCenter = ( ( self.cl.winIndex - 1 ) * GuiManager.Settings.SlotWidth ) + ( GuiManager.Settings.SlotWidth / 2 )
    local randomOffset = math.random( -35, 35 )
    self.cl.targetScrollX = winningCenter - GuiManager.Settings.CenterX + randomOffset

    self.cl.lastCenterIndex = getCenterSlotIndex( self.cl.currentScrollX or 0 )

    if ( self.poseWeightCount or 0 ) > 0 then
        self.interactable:setPoseWeight( 0, 1 )
    end

    sm.effect.playEffect( SpinManager.Settings.StartEffect, self.shape.worldPosition )
end

function SpinManager.cl_onUpdate( self, deltaTime )
    if not self.cl.spinning then
        return
    end

    self.cl.spinTimer = self.cl.spinTimer + deltaTime
    local progress = math.min( self.cl.spinTimer / self.cl.spinDuration, 1.0 )

    local easedProgress = 1 - math.pow( 1 - progress, 4 )
    self.cl.currentScrollX = easedProgress * self.cl.targetScrollX

    local centerIndex = getCenterSlotIndex( self.cl.currentScrollX )
    if self.cl.lastCenterIndex and centerIndex ~= self.cl.lastCenterIndex then
        self.cl.lastCenterIndex = centerIndex
        
        if self.shape and sm.exists( self.shape ) and self.cl.jsonGui then
            sm.effect.playEffect( SpinManager.Settings.TickEffect, self.shape.worldPosition )
        end
    end

    GuiManager.cl_updateSlots( self, self.cl.currentScrollX )
    GuiManager.cl_render( self )

    if progress >= 1.0 then
        self.cl.spinning = false
    end
end

function SpinManager.cl_onPreviewReel( self, data )
    self.cl.reel = data.reel

    if not self.cl.spinning then
        GuiManager.cl_updateSlots( self, self.cl.currentScrollX or 0 )
        GuiManager.cl_render( self )
    end
end