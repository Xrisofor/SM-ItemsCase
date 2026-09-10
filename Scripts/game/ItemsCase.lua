dofile( "$SURVIVAL_DATA/Scripts/game/survival_loot.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

dofile( "$CONTENT_DATA/Scripts/game/Items.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/RarityManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/GuiManager.lua" )
dofile( "$CONTENT_DATA/Scripts/game/managers/SpinManager.lua" )

ItemsCase = class()

function ItemsCase.server_onCreate( self )
    SpinManager.sv_onCreate( self )
end

function ItemsCase.server_onRefresh( self )
    SpinManager.sv_onRefresh( self )
end

function ItemsCase.server_onFixedUpdate( self )
    SpinManager.sv_onFixedUpdate( self )
end

function ItemsCase.server_onSpinRequest( self, params, player )
    SpinManager.sv_onSpinRequest( self, params, player )
end

function ItemsCase.server_onPreviewRequest( self, params, player )
    SpinManager.sv_onPreviewRequest( self, params, player )
end

function ItemsCase.client_onCreate( self )
    self.cl = {
        jsonGui = nil,
        spinning = false,
        spinTimer = 0,
        winIndex = 1,
        targetScrollX = 0,
        currentScrollX = 0,
        reel = {},
    }

    self.network:sendToServer( "server_onPreviewRequest" )
end

function ItemsCase.server_canErase( self )
	return self.sv.activeSpin == nil
end

function ItemsCase.client_onDestroy( self )
    GuiManager.cl_onClose( self )
end

function ItemsCase.client_onUpdate( self, deltaTime )
    SpinManager.cl_onUpdate( self, deltaTime )
end

function ItemsCase.client_onInteract( self, character, state )
    if not state then
        return
    end

    GuiManager.cl_onInteract( self, character, state )
end

function ItemsCase.cl_onClose( self )
    GuiManager.cl_onClose( self )
end

function ItemsCase.cl_onUnlockClick( self, _ )
    GuiManager.cl_onUnlockClick( self, _ )
end

function ItemsCase.client_onSpinStarted( self, data )
    SpinManager.cl_onSpinStarted( self, data )
end

function ItemsCase.client_onSpinFinished( self, data )
    SpinManager.cl_onSpinFinished( self, data )
end

function ItemsCase.client_onPreviewReel( self, data )
    SpinManager.cl_onPreviewReel( self, data )
end